import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../models/auth.dart';
import '../../providers/auth_provider.dart';
import 'paper_confirm_page.dart';

/// 上传试卷（FR-PAP-001）。需家长认证；拍照/选图后上传，成功后跳转报告页。
class PaperUploadPage extends StatefulWidget {
  const PaperUploadPage({Key? key}) : super(key: key);

  @override
  State<PaperUploadPage> createState() => _PaperUploadPageState();
}

class _PaperUploadPageState extends State<PaperUploadPage> {
  XFile? _image;
  Uint8List? _imageBytes;
  final _examNameCtrl = TextEditingController();
  bool _uploading = false;

  Future<void> _pick(ImageSource src) async {
    final picked = await ImagePicker().pickImage(source: src);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _image = picked;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _upload() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isVerified) {
      _toast('请先完成家长认证');
      _goVerify();
      return;
    }
    if (_image == null) {
      _toast('请先拍照或选择试卷图片');
      return;
    }
    // 次数校验（免费+奖励共用 total_remain）。
    Quota? quota;
    try {
      quota = await context.read<ApiClient>().getQuota();
    } on ApiException catch (e) {
      _toast(e.message);
    }
    if (quota != null && quota.totalRemain <= 0) {
      _toast('本月分析次数已用尽，分享报告可获取次数');
      return;
    }

    setState(() => _uploading = true);
    try {
      final scanResult = await context.read<ApiClient>().scanPaper(
            file: _image!,
            examName: _examNameCtrl.text.isEmpty ? null : _examNameCtrl.text,
          );
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PaperConfirmPage(
            scanResult: scanResult,
            imageBytes: _imageBytes,
            examName: _examNameCtrl.text.isEmpty ? null : _examNameCtrl.text,
          ),
        ));
      }
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _goVerify() =>
      Navigator.of(context).pushNamed('/verify');

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('上传试卷')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: InkWell(
              onTap: () => _pick(ImageSource.camera),
              child: Container(
                height: 220,
                alignment: Alignment.center,
                child: _imageBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.camera_alt, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('点击拍照 / 选择试卷（支持印刷体）',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    : Image.memory(_imageBytes!, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('拍照'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('相册'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _examNameCtrl,
            decoration: const InputDecoration(
              labelText: '考试名称(可选)',
              hintText: '如：一模、二模、校月考',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _uploading ? null : _upload,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: Text(_uploading ? '正在识别题号与批改标记…' : '上传并识别'),
          ),
          const SizedBox(height: 8),
          const Text('提示：上传后进入确认页面，核对错题后再生成分析报告。',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
