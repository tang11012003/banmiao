/// 用户模型（与 backend/model.User JSON 字段一致）。
class User {
  final int id;
  final String phone;
  final String? nickname;
  final String? avatar;
  final String role; // unverified / parent / admin / banned
  final String? status;
  final String? verifiedAt;
  final String? createdAt;
  final String? updatedAt;

  const User({
    required this.id,
    required this.phone,
    this.nickname,
    this.avatar,
    this.role = 'unverified',
    this.status,
    this.verifiedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as int,
        phone: j['phone'] as String,
        nickname: j['nickname'] as String?,
        avatar: j['avatar'] as String?,
        role: j['role'] as String? ?? 'unverified',
        status: j['status'] as String?,
        verifiedAt: j['verified_at'] as String?,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );

  /// 是否为已认证家长。
  bool get isVerified => role == 'parent' || role == 'admin';

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'nickname': nickname,
        'avatar': avatar,
        'role': role,
        'status': status,
        'verified_at': verifiedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}
