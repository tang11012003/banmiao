/// 模拟考成绩记录（与 backend/model.Exam 一致）。
class Exam {
  final int id;
  final int userId;
  final int studentId;
  final String name;
  final String subject;
  final DateTime examDate;
  final double totalScore;
  final double scoredRate; // 得分率 0-100
  final String? createdAt;

  const Exam({
    required this.id,
    required this.userId,
    required this.studentId,
    required this.name,
    required this.subject,
    required this.examDate,
    this.totalScore = 0,
    this.scoredRate = 0,
    this.createdAt,
  });

  factory Exam.fromJson(Map<String, dynamic> j) => Exam(
        id: j['id'] as int,
        userId: j['user_id'] as int,
        studentId: j['student_id'] as int,
        name: j['name'] as String,
        subject: j['subject'] as String,
        examDate: DateTime.parse(j['exam_date'] as String),
        totalScore: (j['total_score'] as num? ?? 0).toDouble(),
        scoredRate: (j['scored_rate'] as num? ?? 0).toDouble(),
        createdAt: j['created_at'] as String?,
      );
}
