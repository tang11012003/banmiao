/// 家长认证申请（与 backend/model.AuthVerification 一致）。
class AuthVerification {
  final int id;
  final int userId;
  final String method; // student_card / class_group / payment / invite_code
  final String? materialImage;
  final String? inviteCode;
  final String status; // pending / approved / rejected
  final String? reviewNote;
  final String? reviewedAt;
  final String? createdAt;

  const AuthVerification({
    required this.id,
    required this.userId,
    required this.method,
    this.materialImage,
    this.inviteCode,
    this.status = 'pending',
    this.reviewNote,
    this.reviewedAt,
    this.createdAt,
  });

  factory AuthVerification.fromJson(Map<String, dynamic> j) => AuthVerification(
        id: j['id'] as int,
        userId: j['user_id'] as int,
        method: j['method'] as String,
        materialImage: j['material_image'] as String?,
        inviteCode: j['invite_code'] as String?,
        status: j['status'] as String? ?? 'pending',
        reviewNote: j['review_note'] as String?,
        reviewedAt: j['reviewed_at'] as String?,
        createdAt: j['created_at'] as String?,
      );

  /// 审核中。
  bool get isPending => status == 'pending';

  /// 是否已通过。
  bool get isApproved => status == 'approved';
}

/// 分析次数配额（GET /api/users/quota）。
class Quota {
  final int freeRemain;
  final int bonusRemain;
  final int totalRemain;

  const Quota({
    required this.freeRemain,
    required this.bonusRemain,
    required this.totalRemain,
  });

  factory Quota.fromJson(Map<String, dynamic> j) => Quota(
        freeRemain: j['free_remain'] as int? ?? 0,
        bonusRemain: j['bonus_remain'] as int? ?? 0,
        totalRemain: j['total_remain'] as int? ?? 0,
      );
}
