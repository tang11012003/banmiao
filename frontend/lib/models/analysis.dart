/// 单次分析的简要聚合（GET /api/papers）。
class AnalysisSummary {
  final int paperId;
  final String examName;
  final String subject;
  final double scoreRate;
  final String examDate;
  final String createdAt;
  final int urgent;
  final int attention;
  final int keep;
  final bool hasReport;

  const AnalysisSummary({
    required this.paperId,
    required this.examName,
    required this.subject,
    required this.scoreRate,
    required this.examDate,
    required this.createdAt,
    this.urgent = 0,
    this.attention = 0,
    this.keep = 0,
    this.hasReport = false,
  });

  factory AnalysisSummary.fromJson(Map<String, dynamic> j) => AnalysisSummary(
        paperId: j['paper_id'] as int,
        examName: j['exam_name'] as String? ?? '',
        subject: j['subject'] as String? ?? '',
        scoreRate: (j['score_rate'] as num? ?? 0).toDouble(),
        examDate: j['exam_date'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
        urgent: j['urgent'] as int? ?? 0,
        attention: j['attention'] as int? ?? 0,
        keep: j['keep'] as int? ?? 0,
        hasReport: j['has_report'] as bool? ?? false,
      );
}

/// 分析页顶部整体统计（GET /api/papers/overview）。
class AnalysisOverview {
  final int totalAnalyses;
  final double avgScoreRate;
  final LatestExam? latestExam;
  final double firstRate;
  final double progress;
  final Map<String, int> tier;
  final int totalKp;

  const AnalysisOverview({
    required this.totalAnalyses,
    required this.avgScoreRate,
    this.latestExam,
    required this.firstRate,
    required this.progress,
    required this.tier,
    required this.totalKp,
  });

  factory AnalysisOverview.fromJson(Map<String, dynamic> j) => AnalysisOverview(
        totalAnalyses: j['total_analyses'] as int? ?? 0,
        avgScoreRate: (j['avg_score_rate'] as num? ?? 0).toDouble(),
        latestExam: j['latest_exam'] != null
            ? LatestExam.fromJson(j['latest_exam'] as Map<String, dynamic>)
            : null,
        firstRate: (j['first_rate'] as num? ?? 0).toDouble(),
        progress: (j['progress'] as num? ?? 0).toDouble(),
        tier: {
          'urgent': j['tier']?['urgent'] as int? ?? 0,
          'attention': j['tier']?['attention'] as int? ?? 0,
          'keep': j['tier']?['keep'] as int? ?? 0,
        },
        totalKp: j['total_kp'] as int? ?? 0,
      );

  /// 整体诊断文案（根据进步幅度与待改进数生成）。
  String get summaryText {
    final latest = latestExam?.scoreRate ?? avgScoreRate;
    final up = progress >= 0;
    final trend = up
        ? '较首次提升 ${progress.abs().toStringAsFixed(0)} 个百分点'
        : '较首次下降 ${progress.abs().toStringAsFixed(0)} 个百分点';
    final weak = tier['urgent'] ?? 0;
    final weakTip = weak > 0
        ? '，有 $weak 个知识点待改进，建议优先攻克'
        : '，知识点掌握较稳';
    return '最近一次${latestExam?.subject ?? ''}得分率 ${latest.toStringAsFixed(0)}%，整体$trend$weakTip。';
  }
}

/// 最近一次考试简要信息。
class LatestExam {
  final String name;
  final double scoreRate;
  final String examDate;
  final String subject;

  const LatestExam({
    required this.name,
    required this.scoreRate,
    required this.examDate,
    required this.subject,
  });

  factory LatestExam.fromJson(Map<String, dynamic> j) => LatestExam(
        name: j['name'] as String? ?? '',
        scoreRate: (j['score_rate'] as num? ?? 0).toDouble(),
        examDate: j['exam_date'] as String? ?? '',
        subject: j['subject'] as String? ?? '',
      );
}

/// 学生（孩子）视图：含派生科目与学年。GET /api/students。
class StudentView {
  final int id;
  final String name;
  final String grade;
  final String examType;
  final List<String> subjects;
  final List<String> academicYears;

  const StudentView({
    required this.id,
    required this.name,
    required this.grade,
    required this.examType,
    this.subjects = const [],
    this.academicYears = const [],
  });

  factory StudentView.fromJson(Map<String, dynamic> j) => StudentView(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        grade: j['grade'] as String? ?? '',
        examType: j['exam_type'] as String? ?? '',
        subjects: (j['subjects'] as List? ?? [])
            .map((e) => e as String)
            .toList(),
        academicYears: (j['academic_years'] as List? ?? [])
            .map((e) => e as String)
            .toList(),
      );
}

/// 能力雷达一个维度。GET /api/analysis/radar 的 points 元素。
class RadarPoint {
  final String label;
  final double value;
  final String level; // 仅科目维度返回（urgent/attention/keep）

  const RadarPoint({
    required this.label,
    required this.value,
    this.level = '',
  });

  factory RadarPoint.fromJson(Map<String, dynamic> j) => RadarPoint(
        label: j['label'] as String? ?? '',
        value: (j['value'] as num? ?? 0).toDouble(),
        level: j['level'] as String? ?? '',
      );
}

/// 能力雷达数据：学生维度（各科最新得分率）或科目维度（该科知识点掌握度）。
class RadarResponse {
  final String scope; // 'student' | 'subject'
  final int studentId;
  final String subject;
  final String academicYear;
  final List<RadarPoint> points;

  const RadarResponse({
    required this.scope,
    required this.studentId,
    this.subject = '',
    this.academicYear = '',
    this.points = const [],
  });

  factory RadarResponse.fromJson(Map<String, dynamic> j) => RadarResponse(
        scope: j['scope'] as String? ?? 'student',
        studentId: (j['student_id'] as num? ?? 0).toInt(),
        subject: j['subject'] as String? ?? '',
        academicYear: j['academic_year'] as String? ?? '',
        points: (j['points'] as List? ?? [])
            .map((e) => RadarPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
