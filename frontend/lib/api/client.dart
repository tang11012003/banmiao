import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../config/constants.dart';
import '../models/analysis.dart';
import '../models/auth.dart';
import '../models/calendar.dart';
import '../models/community.dart';
import '../models/exam.dart';
import '../models/notification.dart';
import '../models/paper.dart';
import '../models/user.dart';

/// 统一异常：封装后端 {code, message} 信封中的错误信息。
class ApiException implements Exception {
  final int? code;
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.code, this.statusCode});

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

/// 轻量埋点（调用方无需关心实现，仅打印日志）。
typedef TrackerFn = void Function(String event, [Map<String, dynamic>? params]);

/// 基于 dio 的 REST 封装。
///
/// 职责：
/// 1. 自动在请求头携带 JWT（[setToken] 注入，[InterceptorsWrapper] 读取）。
/// 2. 统一解析后端 `{code, message, data}` 信封，非 0 时抛 [ApiException]。
/// 3. 封装各业务接口，返回强类型模型。
class ApiClient {
  late final Dio _dio;
  final TrackerFn _track;
  String? _token;

  ApiClient({String? baseUrl, TrackerFn? track})
      : _track = track ?? ((_, [__]) {}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null && _token!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
    ));
  }

  /// 注入/清除 JWT（由 AuthProvider 调用）。
  void setToken(String? token) => _token = token;

  /// 解析后端信封，返回 data 字段。非 0 抛异常。
  dynamic _unwrap(Response response) {
    final body = response.data;
    if (body is Map<String, dynamic> && body.containsKey('code')) {
      final code = body['code'] as int? ?? 0;
      if (code != 0) {
        throw ApiException(body['message'] as String? ?? '请求失败',
            code: code, statusCode: response.statusCode);
      }
      return body['data'];
    }
    // 健康检查等非信封接口直接返回原始数据。
    return body;
  }

  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) async {
    final res = await _dio.get(path, queryParameters: query);
    return _unwrap(res);
  }

  Future<dynamic> _post(String path,
      {dynamic body, Map<String, dynamic>? query}) async {
    final res = await _dio.post(path, data: body, queryParameters: query);
    return _unwrap(res);
  }

  // ---------------- 鉴权 / 用户 ----------------

  /// 发送登录短信验证码，开发态返回 [dev_code]。
  Future<String> sendSms(String phone) async {
    final data = await _post(ApiConstants.sendSms, body: {'phone': phone});
    _track('sms_send', {'phone': phone});
    return data['dev_code'] as String;
  }

  /// 短信验证码登录，返回 token 与用户。
  Future<LoginResult> login(String phone, String code) async {
    final data = await _post(ApiConstants.login,
        body: {'phone': phone, 'code': code});
    final token = data['token'] as String;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    _track('register', {'user_id': user.id});
    return LoginResult(token: token, user: user);
  }

  Future<User> getProfile() async {
    final data = await _get(ApiConstants.profile);
    return User.fromJson(data as Map<String, dynamic>);
  }

  /// 提交家长认证。
  Future<AuthVerification> submitVerification({
    required String method,
    String? materialImage,
    String? inviteCode,
  }) async {
    final data = await _post(ApiConstants.verification, body: {
      'method': method,
      if (materialImage != null) 'material_image': materialImage,
      if (inviteCode != null) 'invite_code': inviteCode,
    });
    _track('auth_submit', {'method': method});
    return AuthVerification.fromJson(data as Map<String, dynamic>);
  }

  /// 查询认证状态（可能为空）。
  Future<AuthVerification?> getVerificationStatus() async {
    final data = await _get(ApiConstants.verificationStatus);
    if (data == null) return null;
    return AuthVerification.fromJson(data as Map<String, dynamic>);
  }

  Future<Quota> getQuota() async {
    final data = await _get(ApiConstants.quota);
    return Quota.fromJson(data as Map<String, dynamic>);
  }

  // ---------------- 高考日历 ----------------

  Future<Map<String, dynamic>> getCountdown() async {
    return await _get(ApiConstants.countdown) as Map<String, dynamic>;
  }

  Future<List<CalendarTemplate>> getTemplates() async {
    final data = await _get(ApiConstants.templates) as List;
    return data
        .map((e) => CalendarTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CalendarEvent>> listEvents({int? studentId}) async {
    final query = <String, dynamic>{};
    if (studentId != null) query['student_id'] = studentId;
    final data = await _get(ApiConstants.events, query: query) as List;
    return data
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CalendarEvent> createEvent({
    int? studentId,
    required String title,
    String eventType = 'custom',
    required String eventDate, // 2006-01-02
    String? subject,
    int reminderBefore = 0,
  }) async {
    final data = await _post(ApiConstants.events, body: {
      'student_id': studentId,
      'title': title,
      'event_type': eventType,
      'event_date': eventDate,
      if (subject != null) 'subject': subject,
      'reminder_before': reminderBefore,
    });
    return CalendarEvent.fromJson(data as Map<String, dynamic>);
  }

  Future<Exam> recordExam({
    required int studentId,
    required String name,
    required String subject,
    required String examDate, // 2006-01-02
    double totalScore = 0,
    double scoredRate = 0,
  }) async {
    final data = await _post(ApiConstants.exams, body: {
      'student_id': studentId,
      'name': name,
      'subject': subject,
      'exam_date': examDate,
      'total_score': totalScore,
      'scored_rate': scoredRate,
    });
    _track('exam_record', {'subject': subject, 'name': name});
    return Exam.fromJson(data as Map<String, dynamic>);
  }

  // ---------------- 试卷分析 ----------------

  /// Phase 1: 上传试卷仅做 OCR 识别，返回扫描结果供用户确认。
  Future<OcrScanResult> scanPaper({
    required XFile file,
    required String subject,
    int? studentId,
    String? examName,
  }) async {
    final bytes = await file.readAsBytes();
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes,
          filename: file.name.isNotEmpty ? file.name : 'paper.jpg'),
      'subject': subject,
      if (studentId != null) 'student_id': studentId,
      if (examName != null) 'exam_name': examName,
    });
    final res = await _dio.post(ApiConstants.papersScan, data: form);
    final data = _unwrap(res);
    _track('paper_scan_success', {'subject': subject});
    return OcrScanResult.fromJson(data as Map<String, dynamic>);
  }

  /// Phase 2: 确认错题并生成分析报告。
  Future<Paper> confirmPaper({
    required int paperId,
    required String subject,
    String? examName,
    int? studentId,
    required List<Map<String, dynamic>> items,
  }) async {
    final data = await _post(ApiConstants.paperConfirm(paperId), body: {
      'subject': subject,
      if (examName != null) 'exam_name': examName,
      'student_id': studentId ?? 0,
      'items': items,
    });
    _track('paper_confirm_success', {'paper_id': paperId, 'subject': subject});
    return Paper.fromJson(data as Map<String, dynamic>);
  }

  /// 上传试卷（multipart）。后端同步完成 OCR 并返回已完成的 Paper。
  Future<Paper> uploadPaper({
    required XFile file,
    required String subject,
    int? studentId,
    String? examName,
  }) async {
    final bytes = await file.readAsBytes();
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes,
          filename: file.name.isNotEmpty ? file.name : 'paper.jpg'),
      'subject': subject,
      if (studentId != null) 'student_id': studentId,
      if (examName != null) 'exam_name': examName,
    });
    final res = await _dio.post(ApiConstants.papersUpload, data: form);
    final data = _unwrap(res);
    _track('paper_upload_success',
        {'subject': subject, 'student_id': studentId});
    return Paper.fromJson(data as Map<String, dynamic>);
  }

  Future<PaperReport> getReport(int paperId) async {
    final data = await _get(ApiConstants.paperReport(paperId));
    return PaperReport.fromJson(data as Map<String, dynamic>);
  }

  /// 学生（孩子）列表：含派生科目与学年。GET /api/students。
  Future<List<StudentView>> listStudents() async {
    final data = await _get(ApiConstants.students) as List;
    return data
        .map((e) => StudentView.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 能力雷达：
  /// - 不传 subject：学生维度（各科最新得分率）；
  /// - 传 subject：科目维度（该科最新考试各知识点掌握度）。
  Future<RadarResponse> analysisRadar({
    required int studentId,
    String? subject,
    String? academicYear,
  }) async {
    final query = <String, dynamic>{'student_id': studentId};
    if (subject != null && subject.isNotEmpty) query['subject'] = subject;
    if (academicYear != null && academicYear.isNotEmpty) {
      query['academic_year'] = academicYear;
    }
    final data = await _get(ApiConstants.analysisRadar, query: query)
        as Map<String, dynamic>;
    return RadarResponse.fromJson(data);
  }

  /// 得分率趋势（按学生/科目/学年过滤）。
  Future<List<Exam>> scoreTrend({
    int? studentId,
    String? subject,
    String? academicYear,
  }) async {
    final query = <String, dynamic>{};
    if (studentId != null) query['student_id'] = studentId;
    if (subject != null && subject.isNotEmpty) query['subject'] = subject;
    if (academicYear != null && academicYear.isNotEmpty) {
      query['academic_year'] = academicYear;
    }
    final data = await _get(ApiConstants.papersTrend, query: query) as List;
    return data.map((e) => Exam.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 单知识点错误率趋势。
  Future<List<ExamKpResult>> knowledgeTrend(int kpId) async {
    final data = await _get(ApiConstants.knowledgeTrend(kpId)) as List;
    return data
        .map((e) => ExamKpResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 三档分布（默认最新考试）。
  Future<Map<String, int>> tierDistribution({int examId = 0}) async {
    final data = await _get(ApiConstants.tierDistribution,
        query: examId > 0 ? {'exam_id': examId} : null);
    return {
      'urgent': data['urgent'] as int? ?? 0,
      'attention': data['attention'] as int? ?? 0,
      'keep': data['keep'] as int? ?? 0,
    };
  }

  /// 分享分析报告到外部渠道（渠道：wechat/moments/group/copy_link）。
  Future<void> sharePaper(int paperId, {String channel = 'wechat'}) async {
    await _post(ApiConstants.paperShare(paperId), query: {'channel': channel});
    _track('paper_share', {'paper_id': paperId, 'channel': channel});
  }

  /// 我的分析整体概览（统计 + 整体分析）。
  Future<AnalysisOverview> analysisOverview() async {
    final data = await _get(ApiConstants.papersOverview) as Map<String, dynamic>;
    return AnalysisOverview.fromJson(data);
  }

  /// 我的过往分析列表。
  Future<List<AnalysisSummary>> myAnalyses() async {
    final data = await _get(ApiConstants.papers) as List;
    return data
        .map((e) => AnalysisSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------- 消息 / 通知 ----------------

  /// 我的通知列表。
  Future<List<AppNotification>> listNotifications() async {
    final data = await _get(ApiConstants.notifications) as List;
    return data
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 标记通知已读（id<=0 标记全部）。
  Future<void> markNotificationRead(int id) async {
    await _post(ApiConstants.notificationsRead, body: {'id': id});
  }

  // ---------------- 陪读社区 ----------------

  Future<List<CommunityPost>> listPosts(
      {int? circleId, int limit = 20, int offset = 0}) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (circleId != null) query['circle_id'] = circleId;
    final data = await _get(ApiConstants.posts, query: query) as List;
    return data
        .map((e) => CommunityPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CommunityPost> getPost(int postId) async {
    final data = await _get(ApiConstants.postDetail(postId));
    return CommunityPost.fromJson(data as Map<String, dynamic>);
  }

  Future<List<CommunityComment>> listComments(int postId) async {
    final data = await _get(ApiConstants.postComments(postId)) as List;
    return data
        .map((e) => CommunityComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CommunityPost> createPost({
    required int circleId,
    required String content,
    String? title,
    List<String> images = const [],
  }) async {
    final data = await _post(ApiConstants.posts, body: {
      'circle_id': circleId,
      'content': content,
      if (title != null) 'title': title,
      'images': images,
    });
    _track('community_post', {'circle_id': circleId});
    return CommunityPost.fromJson(data as Map<String, dynamic>);
  }

  Future<CommunityComment> comment(int postId, String content,
      {int? parentId, String? image}) async {
    final data = await _post(ApiConstants.comments, body: {
      'post_id': postId,
      'content': content,
      if (parentId != null) 'parent_id': parentId,
      if (image != null) 'image': image,
    });
    _track('community_interact', {'post_id': postId, 'type': 'comment'});
    return CommunityComment.fromJson(data as Map<String, dynamic>);
  }

  /// 上传图片（开发态：保存到后端 uploads/，返回可访问 URL）。
  /// 使用 XFile.bytes，Web 端亦可用。
  Future<String> uploadImage(XFile file) async {
    final bytes = await file.readAsBytes();
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes,
          filename: file.name.isNotEmpty ? file.name : 'image.jpg'),
    });
    final res = await _dio.post(ApiConstants.upload, data: form);
    final data = _unwrap(res);
    return data['url'] as String;
  }

  /// 点赞/取消点赞，返回当前是否已赞。
  Future<bool> like(String targetType, int targetId) async {
    final data = await _post(ApiConstants.like,
        body: {'target_type': targetType, 'target_id': targetId});
    _track('community_interact',
        {'target_type': targetType, 'target_id': targetId, 'type': 'like'});
    return data['liked'] as bool;
  }

  /// 关注/取关，返回当前是否已关注。
  Future<bool> follow(int followingId) async {
    final data =
        await _post(ApiConstants.follow, body: {'following_id': followingId});
    _track('user_follow', {'following_id': followingId});
    return data['following'] as bool;
  }

  /// 将分析报告分享为社区帖子（工具结果可分享到社区）。
  Future<CommunityPost> shareReportToCommunity({
    required int paperId,
    required int circleId,
    String? comment,
  }) async {
    final data = await _post(ApiConstants.shareReport, body: {
      'paper_id': paperId,
      'circle_id': circleId,
      if (comment != null) 'comment': comment,
    });
    _track('share_to_community', {'paper_id': paperId, 'circle_id': circleId});
    return CommunityPost.fromJson(data as Map<String, dynamic>);
  }

  // ---------------- 邀请码 ----------------

  Future<InviteCode> generateInvite() async {
    final data = await _post(ApiConstants.invitesGenerate);
    _track('invite_generate');
    return InviteCode.fromJson(data as Map<String, dynamic>);
  }

  Future<List<InviteCode>> listInvites() async {
    final data = await _get(ApiConstants.invites) as List;
    return data
        .map((e) => InviteCode.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AuthVerification> useInvite(String code) async {
    final data = await _post(ApiConstants.invitesUse, body: {'code': code});
    _track('invite_used', {'code': code});
    return AuthVerification.fromJson(data as Map<String, dynamic>);
  }
}

/// 登录结果聚合。
class LoginResult {
  final String token;
  final User user;
  const LoginResult({required this.token, required this.user});
}
