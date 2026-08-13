import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../config/constants.dart';
import '../../models/paper.dart';
import '../../widgets/charts.dart';
import '../../widgets/common_widgets.dart';
import 'paper_confirm_page.dart';

/// 分析报告页（FR-PAP-004/005）：三档分布环形图 + 知识点明细 + 分享到社区。
class PaperReportPage extends StatefulWidget {
  final int paperId;
  const PaperReportPage({Key? key, required this.paperId}) : super(key: key);

  @override
  State<PaperReportPage> createState() => _PaperReportPageState();
}

class _PaperReportPageState extends State<PaperReportPage> {
  PaperReport? _report;
  bool _loading = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  /// 轮询直到报告完成（后端当前同步完成，最多重试 5 次）。
  Future<void> _load(int attempt) async {
    final api = context.read<ApiClient>();
    try {
      final report = await api.getReport(widget.paperId);
      if (report.paper.isCompleted) {
        if (mounted) setState(() {
          _report = report;
          _loading = false;
        });
        return;
      }
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
    if (attempt < 5 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      _load(attempt + 1);
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _goEditWrong() {
    if (_report == null) return;
    final r = _report!;
    final questions = r.items.map((item) => ScannedQuestion(
      questionNum: item.questionNum,
      text: item.text,
      status: item.status,
      maxScore: item.maxScore,
      actualScore: item.actualScore,
    )).toList();
    final scanResult = OcrScanResult(
      paperId: r.paper.id,
      imageUrl: r.paper.imageUrl ?? '',
      totalQuestions: r.items.length,
      questions: questions,
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaperConfirmPage(
        scanResult: scanResult,
        subject: r.exam.subject,
        examName: r.exam.name,
        studentId: null,
      ),
    ));
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      await context.read<ApiClient>().sharePaper(widget.paperId);
      _toast('已分享，获得 1 次额外分析次数');
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _shareToCommunity() async {
    // 工具结果分享到社区（PRD 核心设计）。
    final circleId = await _pickCircle();
    if (circleId == null) return;
    try {
      await context.read<ApiClient>().shareReportToCommunity(
            paperId: widget.paperId,
            circleId: circleId,
          );
      _toast('已分享到社区');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<int?> _pickCircle() async {
    int? selected = DefaultCircles.list.first['id'] as int;
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('分享到圈子'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: DefaultCircles.list
                .map((c) => RadioListTile<int>(
                      title: Text(c['name'] as String),
                      value: c['id'] as int,
                      groupValue: selected,
                      onChanged: (v) => Navigator.pop(ctx, v),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('分析报告')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final r = _report;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('分析报告')),
        body: const Center(child: Text('报告生成失败')),
      );
    }
    final grouped = r.groupedByLevel;
    return Scaffold(
      appBar: AppBar(
        title: const Text('分析报告'),
        actions: [
          TextButton(
            onPressed: _goEditWrong,
            child: const Text('修改错题',
                style: TextStyle(color: Colors.white)),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '分享报告',
            onPressed: _sharing ? null : _share,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r.exam.name} · ${r.exam.subject}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('得分率：${r.scoreRate.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('三档分布', style: TextStyle(fontWeight: FontWeight.bold)),
          TierChart(dist: _tierMap(r.kpResults)),
          const SizedBox(height: 16),
          _levelSection('🔴 待改进（需重点突破）', grouped['urgent']!),
          _levelSection('🟡 需关注（加强巩固）', grouped['attention']!),
          _levelSection('🟢 继续保持（已掌握）', grouped['keep']!),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareToCommunity,
              icon: const Icon(Icons.forum),
              label: const Text('把分析报告分享到社区'),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _tierMap(List<ExamKpResult> kps) {
    int urgent = 0, attention = 0, keep = 0;
    for (final k in kps) {
      if (k.level == 'urgent') urgent++;
      else if (k.level == 'attention') attention++;
      else keep++;
    }
    return {'urgent': urgent, 'attention': attention, 'keep': keep};
  }

  Widget _levelSection(String title, List<ExamKpResult> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ...list.map((k) => KpLevelCard(kp: k)),
      ],
    );
  }
}
