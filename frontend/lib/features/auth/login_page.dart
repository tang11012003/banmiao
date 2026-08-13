import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../providers/auth_provider.dart';

/// 登录页：手机号 + 短信验证码（开发态直接用后端返回的 dev_code）。
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _sending = false;
  bool _logging = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _getCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 11) {
      _toast('请输入 11 位手机号');
      return;
    }
    setState(() => _sending = true);
    try {
      final code = await context.read<AuthProvider>().sendSms(phone);
      _toast('开发态验证码：$code（已自动填入）');
      _codeCtrl.text = code;
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (phone.length != 11 || code.isEmpty) {
      _toast('请填写手机号与验证码');
      return;
    }
    setState(() => _logging = true);
    try {
      await context.read<AuthProvider>().login(phone, code);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('登录 / 注册')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school, size: 72, color: Colors.indigo),
            const SizedBox(height: 16),
            const Text('陪读社区',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '手机号',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _sending ? null : _getCode,
                  child: Text(_sending ? '发送中' : '获取验证码'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _logging ? null : _login,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: Text(_logging ? '登录中…' : '登录'),
            ),
            const SizedBox(height: 12),
            if (auth.error != null)
              Text(auth.error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
