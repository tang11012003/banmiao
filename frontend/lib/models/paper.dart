/// 试卷（与 backend/model.Paper 一致）。
import 'exam.dart';

class Paper {
  final int id;
  final int examId;
  final int userId;
  final int pages;
  final String? imageUrl;
  final String ocrStatus; // pending / processing / scanned / completed / failed
  final String? ocrError;
  final String? ocrStartedAt;
  final String? ocrCompletedAt;
  final String? createdAt;

  const Paper({
    required this.id,
    required this.examId,
    required this.userId,
    this.pages = 1,
    this.imageUrl,
    this.ocrStatus = 'pending',
    this.ocrError,
    this.ocrStartedAt,
    this.ocrCompletedAt,
    this.createdAt,
  });

  factory Paper.fromJson(Map<String, dynamic> j) => Paper(
        id: j['id'] as int,
        examId: j['exam_id'] as int? ?? 0,
        userId: j['user_id'] as int,
        pages: j['pages'] as int? ?? 1,
        imageUrl: j['image_url'] as String?,
        ocrStatus: j['ocr_status'] as String? ?? 'pending',
        ocrError: j['ocr_error'] as String?,
        ocrStartedAt: j['ocr_started_at'] as String?,
        ocrCompletedAt: j['ocr_completed_at'] as String?,
        createdAt: j['created_at'] as String?,
      );

  bool get isCompleted => ocrStatus == 'completed';
}

/// OCR 扫描结果（Phase 1: POST /api/papers/scan）
class OcrScanResult {
  final int paperId;
  final String imageUrl;
  final int totalQuestions;
  final List<ScannedQuestion> questions;

  const OcrScanResult({
    required this.paperId,
    required this.imageUrl,
    required this.totalQuestions,
    required this.questions,
  });

  factory OcrScanResult.fromJson(Map<String, dynamic> j) => OcrScanResult(
        paperId: j['paper_id'] as int,
        imageUrl: j['image_url'] as String? ?? '',
        totalQuestions: j['total_questions'] as int? ?? 0,
        questions: (j['questions'] as List? ?? [])
            .map((e) => ScannedQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  int get wrongCount => questions.where((q) => q.status == 'wrong' || q.status == 'half').length;
}

/// OCR 识别的单题信息
class ScannedQuestion {
  final int questionNum;
  final String text;
  final String status;
  final double maxScore;
  final double actualScore;
  final double confidence;

  const ScannedQuestion({
    required this.questionNum,
    this.text = '',
    this.status = 'unanswered',
    this.maxScore = 0,
    this.actualScore = 0,
    this.confidence = 0,
  });

  factory ScannedQuestion.fromJson(Map<String, dynamic> j) => ScannedQuestion(
        questionNum: j['question_num'] as int,
        text: j['text'] as String? ?? '',
        status: j['status'] as String? ?? 'unanswered',
        maxScore: (j['max_score'] as num? ?? 0).toDouble(),
        actualScore: (j['actual_score'] as num? ?? 0).toDouble(),
        confidence: (j['confidence'] as num? ?? 0).toDouble(),
      );
}

/// 试卷中的单题（与 backend/model.PaperItem 一致）。
class PaperItem {
  final int id;
  final int paperId;
  final int questionNum;
  final String text;
  final String status; // correct / wrong / half / unanswered
  final double maxScore;
  final double actualScore;
  final String? imageUrl;
  final String? createdAt;

  const PaperItem({
    required this.id,
    required this.paperId,
    required this.questionNum,
    this.text = '',
    this.status = 'unanswered',
    this.maxScore = 0,
    this.actualScore = 0,
    this.imageUrl,
    this.createdAt,
  });

  factory PaperItem.fromJson(Map<String, dynamic> j) => PaperItem(
        id: j['id'] as int,
        paperId: j['paper_id'] as int,
        questionNum: j['question_num'] as int,
        text: j['text'] as String? ?? '',
        status: j['status'] as String? ?? 'unanswered',
        maxScore: (j['max_score'] as num? ?? 0).toDouble(),
        actualScore: (j['actual_score'] as num? ?? 0).toDouble(),
        imageUrl: j['image_url'] as String?,
        createdAt: j['created_at'] as String?,
      );
}

/// 考试-知识点分析结果（与 backend/model.ExamKPResult 一致）。
class ExamKpResult {
  final int id;
  final int examId;
  final int knowledgePointId;
  final String knowledgeName;
  final int totalQuestions;
  final int wrongQuestions;
  final double errorRate; // 0-1
  final String level; // urgent / attention / keep
  final String? createdAt;

  const ExamKpResult({
    required this.id,
    required this.examId,
    required this.knowledgePointId,
    required this.knowledgeName,
    this.totalQuestions = 0,
    this.wrongQuestions = 0,
    this.errorRate = 0,
    this.level = 'keep',
    this.createdAt,
  });

  factory ExamKpResult.fromJson(Map<String, dynamic> j) => ExamKpResult(
        id: j['id'] as int,
        examId: j['exam_id'] as int,
        knowledgePointId: j['knowledge_point_id'] as int? ?? 0,
        knowledgeName: j['knowledge_name'] as String? ?? '',
        totalQuestions: j['total_questions'] as int? ?? 0,
        wrongQuestions: j['wrong_questions'] as int? ?? 0,
        errorRate: (j['error_rate'] as num? ?? 0).toDouble(),
        level: j['level'] as String? ?? 'keep',
        createdAt: j['created_at'] as String?,
      );
}

/// 试卷分析报告聚合（GET /api/papers/:id/report）。
class PaperReport {
  final Paper paper;
  final Exam exam;
  final List<PaperItem> items;
  final List<ExamKpResult> kpResults;

  const PaperReport({
    required this.paper,
    required this.exam,
    required this.items,
    required this.kpResults,
  });

  factory PaperReport.fromJson(Map<String, dynamic> j) => PaperReport(
        paper: Paper.fromJson(j['paper'] as Map<String, dynamic>),
        exam: Exam.fromJson(j['exam'] as Map<String, dynamic>),
        items: (j['items'] as List? ?? [])
            .map((e) => PaperItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        kpResults: (j['kp_results'] as List? ?? [])
            .map((e) => ExamKpResult.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// 总得分率（取 exam.scored_rate）。
  double get scoreRate => exam.scoredRate;

  /// 按档位分组知识点。
  Map<String, List<ExamKpResult>> get groupedByLevel {
    final map = <String, List<ExamKpResult>>{
      'urgent': [],
      'attention': [],
      'keep': [],
    };
    for (final r in kpResults) {
      map[r.level]?.add(r);
    }
    return map;
  }
}
