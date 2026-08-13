/// 社区帖子（与 backend/model.CommunityPost 一致）。
class CommunityPost {
  final int id;
  final int userId;
  final int circleId;
  final String? title;
  final String content;
  final String contentType; // text / qa / share_report
  final List<String> images;
  final String status; // pending_review / published / rejected
  final String? reviewNote;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isPinned;
  final int reportRefId;
  final String? createdAt;
  final String? updatedAt;

  const CommunityPost({
    required this.id,
    required this.userId,
    required this.circleId,
    this.title,
    required this.content,
    this.contentType = 'text',
    this.images = const [],
    this.status = 'published',
    this.reviewNote,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isPinned = false,
    this.reportRefId = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> j) => CommunityPost(
        id: j['id'] as int,
        userId: j['user_id'] as int,
        circleId: j['circle_id'] as int,
        title: j['title'] as String?,
        content: j['content'] as String? ?? '',
        contentType: j['content_type'] as String? ?? 'text',
        images: (j['images'] as List? ?? [])
            .map((e) => e as String)
            .toList(),
        status: j['status'] as String? ?? 'published',
        reviewNote: j['review_note'] as String?,
        likeCount: j['like_count'] as int? ?? 0,
        commentCount: j['comment_count'] as int? ?? 0,
        shareCount: j['share_count'] as int? ?? 0,
        isPinned: j['is_pinned'] as bool? ?? false,
        reportRefId: j['report_ref_id'] as int? ?? 0,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );

  bool get isShareReport => contentType == 'share_report';
}

/// 社区评论（与 backend/model.CommunityComment 一致）。
class CommunityComment {
  final int id;
  final int postId;
  final int userId;
  final int? parentId;
  final String content;
  final String? image;
  final int likeCount;
  final String? createdAt;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.userId,
    this.parentId,
    required this.content,
    this.image,
    this.likeCount = 0,
    this.createdAt,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> j) => CommunityComment(
        id: j['id'] as int,
        postId: j['post_id'] as int,
        userId: j['user_id'] as int,
        parentId: j['parent_id'] as int?,
        content: j['content'] as String? ?? '',
        image: j['image'] as String?,
        likeCount: j['like_count'] as int? ?? 0,
        createdAt: j['created_at'] as String?,
      );
}

/// 邀请码（与 backend/model.InviteCode 一致）。
class InviteCode {
  final int id;
  final String code;
  final int inviterId;
  final int maxUses;
  final int usedCount;
  final String expiresAt;
  final String? createdAt;

  const InviteCode({
    required this.id,
    required this.code,
    required this.inviterId,
    this.maxUses = 3,
    this.usedCount = 0,
    required this.expiresAt,
    this.createdAt,
  });

  factory InviteCode.fromJson(Map<String, dynamic> j) => InviteCode(
        id: j['id'] as int,
        code: j['code'] as String,
        inviterId: j['inviter_id'] as int,
        maxUses: j['max_uses'] as int? ?? 3,
        usedCount: j['used_count'] as int? ?? 0,
        expiresAt: j['expires_at'] as String,
        createdAt: j['created_at'] as String?,
      );

  bool get exhausted => usedCount >= maxUses;
}
