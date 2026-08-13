import 'package:flutter/material.dart';

/// 消息/通知（与 backend/model.Notification 一致）。
class AppNotification {
  final int id;
  final int userId;
  final String type; // comment / like / follow / system
  final String title;
  final String content;
  final bool isRead;
  final int relatedId;
  final String? createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.content,
    required this.isRead,
    this.relatedId = 0,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as int,
        userId: j['user_id'] as int,
        type: j['type'] as String? ?? 'system',
        title: j['title'] as String? ?? '',
        content: j['content'] as String? ?? '',
        isRead: j['is_read'] as bool? ?? false,
        relatedId: j['related_id'] as int? ?? 0,
        createdAt: j['created_at'] as String?,
      );

  /// 类型对应的图标。
  IconData get icon {
    switch (type) {
      case 'comment':
        return Icons.comment;
      case 'like':
        return Icons.favorite;
      case 'follow':
        return Icons.person_add;
      default:
        return Icons.campaign;
    }
  }

  /// 类型对应的主题色。
  Color get color {
    switch (type) {
      case 'comment':
        return const Color(0xFF2196F3);
      case 'like':
        return const Color(0xFFE6431A);
      case 'follow':
        return const Color(0xFF43A047);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

/// 私信会话（开发态假数据）。
class ChatConversation {
  final int id;
  final String name;
  final String avatarText;
  final String lastMessage;
  final String time;
  final int unread;

  const ChatConversation({
    required this.id,
    required this.name,
    required this.avatarText,
    required this.lastMessage,
    required this.time,
    this.unread = 0,
  });
}

/// 私信消息（开发态假数据）。
class ChatMessage {
  final bool isMe;
  final String text;
  final String time;

  const ChatMessage({
    required this.isMe,
    required this.text,
    required this.time,
  });
}
