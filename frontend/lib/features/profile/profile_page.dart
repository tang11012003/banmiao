import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../config/constants.dart';
import '../../models/auth.dart';
import '../../models/community.dart';
import '../../providers/auth_provider.dart';

/// 个人中心（FR-PER-001/002/003）：孩子信息、分析次数、邀请码管理、认证入口。
class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Quota? _quota;
  List<InviteCode> _invites = [];
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
      _quota = await api.getQuota();
      _invites = await api.listInvites();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateInvite() async {
    try {
      await context.read<ApiClient>().generateInvite();
      _toast('已生成邀请码');
      _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final v = auth.verification;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: RefreshIndicator(
        onRefresh: () async {
          await auth.refreshVerification();
          _load();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user?.nickname ?? user?.phone ?? '未登录'),
                subtitle: Text(auth.isVerified ? '已认证家长' : '未认证'),
                trailing: user == null
                    ? TextButton(
                        onPressed: () => Navigator.of(context).pushNamed('/login'),
                        child: const Text('登录'))
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: const Text('家长认证'),
              subtitle: Text(_verifyText(v)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed('/verify'),
            ),
            ListTile(
              leading: const Icon(Icons.insights),
              title: const Text('学习分析'),
              subtitle: const Text('能力雷达、各科目趋势、知识点掌握度'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed('/analysis'),
            ),
            ListTile(
              leading: const Icon(Icons.confirmation_number),
              title: const Text('本月剩余分析次数'),
              subtitle: _loading || _quota == null
                  ? const Text('加载中…')
                  : Text(
                      '免费 ${_quota!.freeRemain} · 奖励 ${_quota!.bonusRemain} · 共 ${_quota!.totalRemain}'),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('我的邀请码',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _generateInvite,
                  icon: const Icon(Icons.add),
                  label: const Text('生成'),
                ),
              ],
            ),
            ..._invites.map((ic) => ListTile(
                  title: Text(ic.code,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 1)),
                  subtitle: Text(
                      '可用 ${ic.maxUses - ic.usedCount}/${ic.maxUses} · 有效期至 ${ic.expiresAt.substring(0, 10)}'),
                )),
            if (_invites.isEmpty)
              const Text('还没有邀请码，点击右上角生成分享给好友。',
                  style: TextStyle(color: Colors.grey)),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('退出登录'),
              onTap: () async {
                await auth.logout();
                if (mounted) Navigator.of(context).pushReplacementNamed('/');
              },
            ),
          ],
        ),
      ),
    );
  }

  String _verifyText(AuthVerification? v) {
    if (v == null) return '未完成家长身份认证';
    if (v.isApproved) return '认证已通过';
    if (v.isPending) return '审核中：${_methodLabel(v.method)}';
    return '已驳回：${v.reviewNote ?? ""}';
  }

  String _methodLabel(String m) =>
      VerifyMethod.options.firstWhere((e) => e['value'] == m,
          orElse: () => {'label': m})['label']!;
}
