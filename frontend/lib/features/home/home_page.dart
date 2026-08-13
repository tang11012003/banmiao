import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../models/calendar.dart';
import '../../models/community.dart';
import '../../widgets/common_widgets.dart';
import '../calendar/calendar_page.dart';
import '../community/community_page.dart';
import '../community/post_detail_page.dart';
import '../paper/paper_upload_page.dart';

/// 首页（PRD 7.1）：高考倒计时 + 上传入口 + 近期考试 + 热门话题。
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? _days;
  String _gaokao = '';
  List<CalendarEvent> _events = [];
  List<CommunityPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    setState(() => _loading = true);
    try {
      final cd = await api.getCountdown();
      _days = cd['days'] as int;
      _gaokao = cd['gaokao_date'] as String;
      _events = await api.listEvents();
      _posts = await api.listPosts(limit: 5);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_days != null)
            CountdownCard(days: _days!, gaokaoDate: _gaokao),
          const SizedBox(height: 16),
          Card(
            color: Colors.indigo,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PaperUploadPage())),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.camera_alt, color: Colors.white, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📷 上传试卷分析',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('拍照知薄弱，折线看进步',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('📅 近期考试',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CalendarPage())),
                  child: const Text('更多')),
            ],
          ),
          ..._events.take(3).map((e) => ExamCard(
                title: e.title,
                date: formatDate(e.eventDate),
                subtitle: e.subject != null ? e.subject : null,
              )),
          if (_events.isEmpty)
            const Text('暂无日程', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🔥 热门话题',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CommunityPage())),
                  child: const Text('社区')),
            ],
          ),
          ..._posts.map((p) => ListTile(
                leading: const Icon(Icons.article),
                title: Text(p.title ?? p.content,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(p.content,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PostDetailPage(postId: p.id))),
              )),
        ],
      ),
    );
  }
}
