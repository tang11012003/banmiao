import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../models/paper.dart';
import '../../widgets/common_widgets.dart';

/// 单次分析详情（FR-PAP）：试卷报告的知识点三档诊断。
class AnalysisDetailPage extends StatefulWidget {
  final int paperId;
  const AnalysisDetailPage({Key? key, required this.paperId}) : super(key: key);

  @override
  State<AnalysisDetailPage> createState() => _AnalysisDetailPageState();
}

class _AnalysisDetailPageState extends State<AnalysisDetailPage> {
  PaperReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _report = await context.read<ApiClient>().getReport(widget.paperId);
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
      return Scaffold(
        appBar: AppBar(title: const Text('分析详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final r = _report;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('分析详情')),
        body: const Center(child: Text('报告不存在')),
      );
    }
    final grouped = r.groupedByLevel;
    return Scaffold(
      appBar: AppBar(title: Text(r.exam.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.analytics, color: Color(0xFFE6431A)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.exam.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                            '${r.exam.subject} · 得分率 ${r.exam.scoredRate.toStringAsFixed(0)}%',
                            style: const TextStyle(color: Color(0xFF616161))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (r.kpResults.isEmpty)
            const Text('本次分析暂无知识点结果',
                style: TextStyle(color: Color(0xFF9E9E9E)))
          else ...[
            _Section(title: '待改进', color: const Color(0xFFE53935),
                items: grouped['urgent'] ?? []),
            _Section(title: '需关注', color: const Color(0xFFFBC02D),
                items: grouped['attention'] ?? []),
            _Section(title: '继续保持', color: const Color(0xFF43A047),
                items: grouped['keep'] ?? []),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Color color;
  final List<ExamKpResult> items;
  const _Section(
      {required this.title, required this.color, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 6),
              Text('${items.length}',
                  style: const TextStyle(color: Color(0xFF9E9E9E))),
            ],
          ),
        ),
        ...items.map((k) => KpLevelCard(kp: k)).toList(),
      ],
    );
  }
}
