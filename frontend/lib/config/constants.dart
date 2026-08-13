// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// 全局配置：后端基址与接口路径。
///
/// Web 体验态：直接取当前页面源（同源），由 8081 反向代理把 /api 转发到后端 8080，
/// 避免把地址写死成 localhost 导致远程访问时 API 不可达。
/// 真机/移动端构建请改回具体可访问地址（如 http://<内网IP>:8080）。
class ApiConstants {
  /// 后端基址。Web 体验态下与页面同源，由反代统一转发 /api。
  // ignore: avoid_web_libraries_in_flutter
  static String get baseUrl => _webOrigin();

  /// 接口前缀。
  static const String prefix = '/api';

  // ---- 鉴权 / 用户 ----
  static const String sendSms = '$prefix/auth/send-sms';
  static const String login = '$prefix/auth/login';
  static const String profile = '$prefix/users/profile';
  static const String verification = '$prefix/users/verification';
  static const String verificationStatus = '$prefix/users/verification/status';
  static const String quota = '$prefix/users/quota';

  // ---- 高考日历 ----
  static const String countdown = '$prefix/calendar/countdown';
  static const String templates = '$prefix/calendar/templates';
  static const String events = '$prefix/calendar/events';
  static const String exams = '$prefix/calendar/exams';

  // ---- 试卷分析 ----
  static const String papersUpload = '$prefix/papers/upload';
  static const String papersScan = '$prefix/papers/scan';
  static String paperConfirm(int id) => '$prefix/papers/$id/confirm';
  static String paperReport(int id) => '$prefix/papers/$id/report';
  static String papersTrend = '$prefix/papers/trend';
  static String knowledgeTrend(int kpId) => '$prefix/papers/knowledge/$kpId/trend';
  static const String tierDistribution = '$prefix/papers/tier-distribution';
  static String paperShare(int id) => '$prefix/papers/$id/share';
  static const String papers = '$prefix/papers';
  static const String papersOverview = '$prefix/papers/overview';

  // ---- 学生 / 能力雷达 ----
  static const String students = '$prefix/students';
  static const String analysisRadar = '$prefix/analysis/radar';

  // ---- 图片上传 ----
  static const String upload = '$prefix/upload';

  // ---- 消息 / 通知 ----
  static const String notifications = '$prefix/notifications';
  static const String notificationsRead = '$prefix/notifications/read';

  // ---- 陪读社区 ----
  static const String posts = '$prefix/community/posts';
  static String postDetail(int id) => '$prefix/community/posts/$id';
  static String postComments(int id) => '$prefix/community/posts/$id/comments';
  static const String comments = '$prefix/community/comments';
  static const String like = '$prefix/community/like';
  static const String follow = '$prefix/community/follow';
  static const String shareReport = '$prefix/community/share-report';

  // ---- 邀请码 ----
  static const String invitesGenerate = '$prefix/invites/generate';
  static const String invites = '$prefix/invites';
  static const String invitesUse = '$prefix/invites/use';
}

/// Web 体验态：使用当前页面所在源，使 /api 请求走同源反代。
String _webOrigin() => html.window.location.origin;

/// 认证方式枚举（与后端 method 取值一致）。
class VerifyMethod {
  static const String studentCard = 'student_card';
  static const String classGroup = 'class_group';
  static const String payment = 'payment';
  static const String inviteCode = 'invite_code';

  static const List<Map<String, String>> options = [
    {'value': studentCard, 'label': '学生证 / 校园卡'},
    {'value': classGroup, 'label': '班级群截图'},
    {'value': payment, 'label': '缴费凭证'},
    {'value': inviteCode, 'label': '邀请码'},
  ];
}

/// 三档判定（与后端 ExamKPResult.level 一致）。
class TierLevel {
  static const String urgent = 'urgent';
  static const String attention = 'attention';
  static const String keep = 'keep';

  static String label(String level) {
    switch (level) {
      case urgent:
        return '待改进';
      case attention:
        return '需关注';
      case keep:
        return '继续保持';
      default:
        return level;
    }
  }

  /// 对应主题色（用于卡片/图表）。
  static int colorValue(String level) {
    switch (level) {
      case urgent:
        return 0xFFE53935; // 红
      case attention:
        return 0xFFFBC02D; // 黄
      case keep:
        return 0xFF43A047; // 绿
      default:
        return 0xFF9E9E9E;
    }
  }
}

/// 本地默认圈子目录（PRD FR-COM-001）。
///
/// 后端当前未提供圈子列表接口，发布帖/分享报告需传 circle_id，
/// 这里先用 PRD 默认圈子占位；接入 /api/community/circles 后替换。
class DefaultCircles {
  static const List<Map<String, dynamic>> list = [
    {'id': 1, 'name': '高三陪读圈', 'category': 'grade'},
    {'id': 2, 'name': '高一高二预备圈', 'category': 'grade'},
    {'id': 3, 'name': '广东陪读圈', 'category': 'region'},
    {'id': 4, 'name': '数学交流圈', 'category': 'subject'},
    {'id': 5, 'name': '英语交流圈', 'category': 'subject'},
    {'id': 6, 'name': '营养食谱', 'category': 'topic'},
    {'id': 7, 'name': '心理调适', 'category': 'topic'},
    {'id': 8, 'name': '志愿填报', 'category': 'topic'},
  ];
}
