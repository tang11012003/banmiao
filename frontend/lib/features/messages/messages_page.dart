import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../models/notification.dart';
import 'chat_page.dart';

/// 消息中心（Tab）：通知（来自接口）+ 私信（开发态假数据）。
class MessagesPage extends StatefulWidget {
  const MessagesPage({Key? key}) : super(key: key);

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<AppNotification> _notifs = [];
  bool _loading = true;
  int _unread = 0;

  // 私信会话（开发态假数据）
  final List<ChatConversation> _chats = const [
    ChatConversation(
        id: 1,
        name: '王老师（班主任）',
        avatarText: '王',
        lastMessage: '孩子最近状态不错，保持住',
        time: '10:24',
        unread: 2),
    ChatConversation(
        id: 2,
        name: '海淀虎妈',
        avatarText: '虎',
        lastMessage: '那个数学刷题资料能发我一份吗',
        time: '昨天',
        unread: 0),
    ChatConversation(
        id: 3,
        name: '陪读学姐',
        avatarText: '学',
        lastMessage: '志愿填报的清单我整理好啦',
        time: '周一',
        unread: 0),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    setState(() => _loading = true);
    try {
      _notifs = await api.listNotifications();
      _unread = _notifs.where((n) => !n.isRead).length;
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(int id) async {
    try {
      await context.read<ApiClient>().markNotificationRead(id);
      _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: '通知${_unread > 0 ? ' ($_unread)' : ''}'),
            const Tab(text: '私信'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildNotifs(),
          _buildChats(),
        ],
      ),
    );
  }

  Widget _buildNotifs() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_notifs.isEmpty) {
      return const Center(
          child: Text('暂无通知', style: TextStyle(color: Color(0xFF9E9E9E))));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _notifs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final n = _notifs[i];
          return ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: n.color.withOpacity(0.12),
                  child: Icon(n.icon, color: n.color),
                ),
                if (!n.isRead)
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: CircleAvatar(
                      radius: 5,
                      backgroundColor: Color(0xFFE6431A),
                    ),
                  ),
              ],
            ),
            title: Text(n.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(n.content,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: n.createdAt != null
                ? Text(n.createdAt!.substring(5, 16),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)))
                : null,
            onTap: () {
              if (!n.isRead) _markRead(n.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildChats() => ListView.separated(
        itemCount: _chats.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final c = _chats[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE6431A).withOpacity(0.12),
              child: Text(c.avatarText,
                  style: const TextStyle(
                      color: Color(0xFFE6431A), fontWeight: FontWeight.bold)),
            ),
            title: Row(
              children: [
                Expanded(child: Text(c.name,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                if (c.unread > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6431A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${c.unread}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11)),
                  ),
              ],
            ),
            subtitle: Text(c.lastMessage,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(c.time,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatPage(conversation: c))),
          );
        },
      );
}
