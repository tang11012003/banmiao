import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';

/// 选中的图片（保留 XFile 用于上传，bytes 用于本地预览）。
class _Picked {
  final XFile file;
  final Uint8List bytes;
  _Picked(this.file, this.bytes);
}

/// 发帖页（FR-COM-002/004）。支持图片（九宫格预览）、圈子选择、标题/正文分区。
class PostComposePage extends StatefulWidget {
  const PostComposePage({Key? key}) : super(key: key);

  @override
  State<PostComposePage> createState() => _PostComposePageState();
}

class _PostComposePageState extends State<PostComposePage> {
  int _circleId = DefaultCircles.list.first['id'] as int;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final List<_Picked> _images = [];
  bool _posting = false;
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    if (_images.length >= 9) {
      _toast('最多 9 张图片');
      return;
    }
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _images.add(_Picked(x, bytes)));
  }

  void _removeAt(int i) => setState(() => _images.removeAt(i));

  Future<void> _publish() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isVerified) {
      _toast('请先完成家长认证');
      Navigator.of(context).pushNamed('/verify');
      return;
    }
    if (_contentCtrl.text.trim().isEmpty && _images.isEmpty) {
      _toast('请输入正文或至少一张图片');
      return;
    }
    setState(() => _posting = true);
    try {
      final api = context.read<ApiClient>();
      // 上传图片（开发态）
      final urls = <String>[];
      for (final p in _images) {
        urls.add(await api.uploadImage(p.file));
      }
      await api.createPost(
        circleId: _circleId,
        title: _titleCtrl.text.isEmpty ? null : _titleCtrl.text,
        content: _contentCtrl.text.trim(),
        images: urls,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发布帖子'),
        actions: [
          TextButton(
            onPressed: _posting ? null : _publish,
            child: _posting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: const CircularProgressIndicator(strokeWidth: 2))
                : const Text('发布'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 圈子选择
          DropdownButtonFormField<int>(
            value: _circleId,
            items: DefaultCircles.list
                .map((c) => DropdownMenuItem(
                    value: c['id'] as int, child: Text(c['name'] as String)))
                .toList(),
            onChanged: (v) => setState(() => _circleId = v!),
            decoration: const InputDecoration(
              labelText: '选择圈子',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '选择圈子',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentCtrl,
            maxLines: 8,
            minLines: 4,
            decoration: const InputDecoration(
              labelText: '分享你的陪读经验…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          // 图片九宫格
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._images.asMap().entries.map((e) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(e.value.bytes,
                            width: 96, height: 96, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeAt(e.key),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )),
              if (_images.length < 9)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_camera, color: Colors.grey),
                        SizedBox(height: 4),
                        Text('添加图片',
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('最多 9 张，支持 jpg/png（开发态：本地选图后展示）',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }
}
