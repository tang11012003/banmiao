import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../config/constants.dart';
import '../../models/community.dart';

/// 帖子详情（FR-COM-003/004）：内容、图片画廊、点赞切换、评论列表（支持图片）。
class PostDetailPage extends StatefulWidget {
  final int postId;
  const PostDetailPage({Key? key, required this.postId}) : super(key: key);

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  CommunityPost? _post;
  List<CommunityComment> _comments = [];
  bool _loading = true;
  bool _liked = false;
  final _commentCtrl = TextEditingController();
  XFile? _commentImage;
  Uint8List? _commentImageBytes;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    setState(() => _loading = true);
    try {
      _post = await api.getPost(widget.postId);
      _comments = await api.listComments(widget.postId);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;
    final api = context.read<ApiClient>();
    try {
      final liked = await api.like('post', _post!.id);
      setState(() {
        _liked = liked;
        _post = CommunityPost(
          id: _post!.id,
          userId: _post!.userId,
          circleId: _post!.circleId,
          title: _post!.title,
          content: _post!.content,
          contentType: _post!.contentType,
          images: _post!.images,
          status: _post!.status,
          likeCount: _post!.likeCount + (liked ? 1 : -1),
          commentCount: _post!.commentCount,
          shareCount: _post!.shareCount,
          isPinned: _post!.isPinned,
          reportRefId: _post!.reportRefId,
          createdAt: _post!.createdAt,
          updatedAt: _post!.updatedAt,
        );
      });
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _pickCommentImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _commentImage = x;
      _commentImageBytes = bytes;
    });
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty && _commentImage == null) return;
    try {
      final api = context.read<ApiClient>();
      String? imageUrl;
      if (_commentImage != null) {
        imageUrl = await api.uploadImage(_commentImage!);
      }
      await api.comment(widget.postId, text,
          image: imageUrl);
      _commentCtrl.clear();
      setState(() {
        _commentImage = null;
        _commentImageBytes = null;
      });
      _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_loading || _post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('帖子详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _post!;
    return Scaffold(
      appBar: AppBar(title: Text(p.title ?? '帖子详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (p.contentType == 'share_report')
            const Chip(
                label: Text('工具分享 · 试卷分析报告'),
                avatar: Icon(Icons.insights, size: 16)),
          Text(p.content),
          const SizedBox(height: 12),
          if (p.images.isNotEmpty) _imageGrid(p.images),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                icon: Icon(_liked ? Icons.favorite : Icons.favorite_border,
                    color: _liked ? Colors.red : null),
                onPressed: _toggleLike,
              ),
              Text('${p.likeCount}'),
              const SizedBox(width: 16),
              const Icon(Icons.comment),
              Text(' ${p.commentCount}'),
            ],
          ),
          const Divider(),
          const Text('评论', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._comments.map((c) => _commentTile(c)),
          if (_comments.isEmpty)
            const Text('还没有评论，来抢沙发～',
                style: TextStyle(color: Colors.grey)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image),
                onPressed: _pickCommentImage,
                color: _commentImage != null ? const Color(0xFFE6431A) : null,
              ),
              if (_commentImageBytes != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(_commentImageBytes!,
                        width: 36, height: 36, fit: BoxFit.cover),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  decoration: const InputDecoration(
                    hintText: '写评论…',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendComment,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageGrid(List<String> images) => GridView.count(
        crossAxisCount: images.length == 1 ? 1 : 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: images
            .map((u) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    '${ApiConstants.baseUrl}$u',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ))
            .toList(),
      );

  Widget _commentTile(CommunityComment c) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.content),
            if (c.image != null && c.image!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    '${ApiConstants.baseUrl}${c.image}',
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
          ],
        ),
        subtitle: c.createdAt != null ? Text(c.createdAt!) : null,
      );
}
