import 'package:flutter/material.dart';

import '../../models/notification.dart';

/// 私信聊天页（开发态：假数据与本地发送，不接 IM 服务）。
class ChatPage extends StatefulWidget {
  final ChatConversation conversation;
  const ChatPage({Key? key, required this.conversation}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _msgs = [
    ChatMessage(isMe: false, text: '在吗？想请教下志愿填报的事', time: '10:20'),
    ChatMessage(
        isMe: true, text: '在的，孩子今年也高三吧？', time: '10:21'),
    ChatMessage(isMe: false, text: '对，最近正纠结选学校', time: '10:22'),
  ];
  final _ctrl = TextEditingController();

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _msgs.add(ChatMessage(
          isMe: true, text: t, time: TimeOfDay.now().format(context)));
      _ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.conversation.name)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _msgs.length,
              itemBuilder: (_, i) {
                final m = _msgs[i];
                return Align(
                  alignment:
                      m.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    constraints:
                        BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: m.isMe
                          ? const Color(0xFFE6431A)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(
                          color: m.isMe ? Colors.white : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: '输入消息…',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFFE6431A)),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
