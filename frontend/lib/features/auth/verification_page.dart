import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';

/// 家长认证页（FR-AUTH-003/004/005）。
/// 4 种方式：学生证 / 班级群截图 / 缴费凭证 / 邀请码。
class VerificationPage extends StatefulWidget {
  const VerificationPage({Key? key}) : super(key: key);

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  String _method = VerifyMethod.studentCard;
  final _inviteCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _inviteCtrl.dispose();
    super.dispose();
  }

  bool get _isInvite => _method == VerifyMethod.inviteCode;

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (_isInvite) {
      final code = _inviteCtrl.text.trim();
      if (code.isEmpty) {
        _toast('请输入邀请码');
        return;
      }
      setState(() => _submitting = true);
      try {
        await auth.useInvite(code);
        _toast('邀请码认证成功，已解锁全部功能');
        if (mounted) Navigator.of(context).pop(true);
      } on ApiException catch (e) {
        _toast(e.message);
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }

    // 其余三种方式：提交材料（开发态伪造 material_image 占位）。
    setState(() => _submitting = true);
    try {
      await auth.submitVerification(
        method: _method,
        materialImage: 'dev://upload/${VerifyMethod.options.firstWhere(
              (e) => e['value'] == _method,
            )['value']}.jpg',
      );
      _toast('已提交，审核中（预计 ≤30 分钟）');
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final v = context.watch<AuthProvider>().verification;
    return Scaffold(
      appBar: AppBar(title: const Text('家长认证')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('请选择一种方式完成家长身份确认',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...VerifyMethod.options.map((opt) => RadioListTile<String>(
                title: Text(opt['label']!),
                value: opt['value']!,
                groupValue: _method,
                onChanged: (val) => setState(() => _method = val!),
              )),
          const SizedBox(height: 8),
          if (_isInvite)
            TextField(
              controller: _inviteCtrl,
              decoration: const InputDecoration(
                labelText: '邀请码',
                border: OutlineInputBorder(),
              ),
            )
          else
            const Card(
              child: ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('上传材料截图'),
                subtitle: Text('开发态：提交后上传占位，联调时接入 image_picker'),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? '提交中…' : '提交认证'),
          ),
          const SizedBox(height: 16),
          if (v != null) _statusBanner(v),
        ],
      ),
    );
  }

  Widget _statusBanner(v) {
    final color = v.isApproved
        ? Colors.green
        : v.isPending
            ? Colors.orange
            : Colors.red;
    final text = v.isApproved
        ? '已通过认证'
        : v.isPending
            ? '审核中，请耐心等待'
            : '认证被驳回：${v.reviewNote ?? ""}';
    return Card(
      color: color.withOpacity(0.12),
      child: ListTile(
        leading: Icon(Icons.info, color: color),
        title: Text(text),
      ),
    );
  }
}
