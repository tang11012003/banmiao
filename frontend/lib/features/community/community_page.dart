import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../config/constants.dart';
import '../../models/community.dart';
import '../../widgets/hupu_post_card.dart';
import '../community/post_compose_page.dart';
import '../community/post_detail_page.dart';

/// 陪读社区信息流（FR-COM-001/002）：帖子列表、圈子筛选、进入详情/发帖。
class CommunityPage extends StatefulWidget {
  const CommunityPage({Key? key}) : super(key: key);

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  List<CommunityPost> _posts = [];
  bool _loading = true;
  int? _circleId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    setState(() => _loading = true);
    try {
      _posts = await api.listPosts(circleId: _circleId);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('陪读社区'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '发帖',
            onPressed: () async {
              final ok = await Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PostComposePage()));
              if (ok == true) _load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _chip(null, '全部'),
                  ...DefaultCircles.list
                      .map((c) => _chip(c['id'] as int, c['name'] as String)),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _posts.isEmpty
                        ? const Center(
                            child: Text('这里还没有帖子，去发一条吧～',
                                style: TextStyle(color: Color(0xFF9E9E9E))))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _posts.length,
                            itemBuilder: (_, i) {
                              final p = _posts[i];
                              return HupuPostCard(
                                post: p,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          PostDetailPage(postId: p.id)),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(int? id, String label) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: _circleId == id,
          selectedColor: const Color(0xFFE6431A),
          backgroundColor: const Color(0xFFF0F0F0),
          labelStyle: TextStyle(
            fontSize: 13,
            color: _circleId == id ? Colors.white : const Color(0xFF616161),
            fontWeight: FontWeight.w600,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onSelected: (_) => setState(() {
            _circleId = id;
            _load();
          }),
        ),
      );
}
