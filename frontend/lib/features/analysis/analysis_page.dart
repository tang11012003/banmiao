import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../models/analysis.dart';
import '../paper/paper_upload_page.dart';
import 'analysis_detail_page.dart';

/// 分析页（一级 Tab）：顶部整体统计 + 整体分析，下方过往分析列表。
class AnalysisPage extends StatefulWidget {
  const AnalysisPage({Key? key}) : super(key: key);

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  AnalysisOverview? _overview;
  List<AnalysisSummary> _list = [];
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
      _overview = await api.analysisOverview();
      _list = await api.myAnalyses();
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
        title: const Text('学习分析'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PaperUploadPage())),
            icon: const Icon(Icons.add_a_photo),
            label: const Text('上传'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_overview != null) _OverviewCard(ov: _overview!),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('过往分析',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('共 ${_list.length} 次',
                          style: const TextStyle(color: Color(0xFF9E9E9E))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._list.map((a) => _AnalysisTile(a: a)).toList(),
                  if (_list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('还没有分析记录，去上传一份试卷吧～',
                          style: TextStyle(color: Color(0xFF9E9E9E))),
                    ),
                ],
              ),
            ),
    );
  }
}

/// 顶部整体统计 + 整体分析卡片。
class _OverviewCard extends StatelessWidget {
  final AnalysisOverview ov;
  const _OverviewCard({required this.ov});

  @override
  Widget build(BuildContext context) {
    final urgent = ov.tier['urgent'] ?? 0;
    final attn = ov.tier['attention'] ?? 0;
    final keep = ov.tier['keep'] ?? 0;
    final totalTier = (urgent + attn + keep).toDouble();
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: Color(0xFFE6431A)),
                const SizedBox(width: 8),
                const Text('整体分析',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('共 ${ov.totalAnalyses} 次分析',
                    style:
                        const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            // 核心数字
            Row(
              children: [
                _Stat(value: ov.avgScoreRate.toStringAsFixed(0),
                    unit: '%', label: '平均得分率'),
                _Stat(
                    value: (ov.progress >= 0 ? '+' : '') +
                        ov.progress.toStringAsFixed(0),
                    unit: 'pt',
                    label: '较首次',
                    highlight: ov.progress >= 0),
                _Stat(value: '${ov.totalKp}', unit: '', label: '覆盖知识点'),
              ],
            ),
            const SizedBox(height: 12),
            Text(ov.summaryText,
                style: const TextStyle(
                    fontSize: 13, height: 1.6, color: Color(0xFF616161))),
            const SizedBox(height: 14),
            const Text('三档分布',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            if (totalTier > 0) ...[
              _TierBar(
                  label: '待改进', value: urgent, total: totalTier,
                  color: const Color(0xFFE53935)),
              _TierBar(
                  label: '需关注', value: attn, total: totalTier,
                  color: const Color(0xFFFBC02D)),
              _TierBar(
                  label: '继续保持', value: keep, total: totalTier,
                  color: const Color(0xFF43A047)),
            ] else
              const Text('暂无知识点数据',
                  style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final bool highlight;
  const _Stat(
      {required this.value,
      required this.unit,
      required this.label,
      this.highlight = false});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: highlight ? const Color(0xFF43A047) : const Color(0xFF1A1A1A),
                    ),
                  ),
                  TextSpan(
                    text: unit,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
          ],
        ),
      );
}

class _TierBar extends StatelessWidget {
  final String label;
  final int value;
  final double total;
  final Color color;
  const _TierBar(
      {required this.label,
      required this.value,
      required this.total,
      required this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
                width: 64,
                child: Text(label, style: const TextStyle(fontSize: 12))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total > 0 ? value / total : 0,
                  minHeight: 8,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
                width: 24,
                child: Text('$value',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.right)),
          ],
        ),
      );
}

/// 过往分析列表项。
class _AnalysisTile extends StatelessWidget {
  final AnalysisSummary a;
  const _AnalysisTile({required this.a});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE6431A).withOpacity(0.1),
          child: const Icon(Icons.analytics, color: Color(0xFFE6431A)),
        ),
        title: Text(a.examName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                if (a.subject.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(a.subject,
                        style: const TextStyle(fontSize: 11, color: Colors.indigo)),
                  ),
                Text(a.examDate,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
              ],
            ),
            const SizedBox(height: 6),
            _TierDots(urgent: a.urgent, attention: a.attention, keep: a.keep),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${a.scoreRate.toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
            const Text('得分率', style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
          ],
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AnalysisDetailPage(paperId: a.paperId))),
      ),
    );
  }
}

class _TierDots extends StatelessWidget {
  final int urgent;
  final int attention;
  final int keep;
  const _TierDots(
      {required this.urgent, required this.attention, required this.keep});
  @override
  Widget build(BuildContext context) {
    final items = [
      if (urgent > 0) _Dot(color: const Color(0xFFE53935), n: urgent, t: '待改进'),
      if (attention > 0)
        _Dot(color: const Color(0xFFFBC02D), n: attention, t: '需关注'),
      if (keep > 0) _Dot(color: const Color(0xFF43A047), n: keep, t: '保持'),
    ];
    if (items.isEmpty) {
      return const Text('暂无知识点',
          style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)));
    }
    return Wrap(spacing: 10, children: items);
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final int n;
  final String t;
  const _Dot({required this.color, required this.n, required this.t});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Text('$t $n', style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
        ],
      );
}
