import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../models/exam.dart';
import '../../widgets/charts.dart';
import '../../widgets/common_widgets.dart';

/// 数据看板（FR-PAP-007）：总分/单科得分率趋势折线图 + 单知识点趋势。
class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _subject = '';
  List<Exam> _exams = [];
  List<FlSpot> _spots = [];
  List<String> _labels = [];
  bool _loading = true;

  // 单知识点趋势
  final _kpIdCtrl = TextEditingController();
  List<FlSpot> _kpSpots = [];
  List<String> _kpLabels = [];
  String _kpName = '';

  static const _subjects = [
    '', '语文', '数学', '英语', '物理', '化学', '生物', '政治', '历史', '地理'
  ];

  @override
  void initState() {
    super.initState();
    _loadTrend();
  }

  Future<void> _loadTrend() async {
    final api = context.read<ApiClient>();
    setState(() => _loading = true);
    try {
      _exams = await api.scoreTrend(subject: _subject.isEmpty ? null : _subject);
      _buildSpots();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _buildSpots() {
    _spots = [];
    _labels = [];
    for (var i = 0; i < _exams.length; i++) {
      _spots.add(FlSpot(i.toDouble(), _exams[i].scoredRate));
      _labels.add(_exams[i].name);
    }
  }

  Future<void> _loadKpTrend() async {
    final id = int.tryParse(_kpIdCtrl.text.trim());
    if (id == null) {
      _toast('请输入知识点 ID');
      return;
    }
    final api = context.read<ApiClient>();
    try {
      final results = await api.knowledgeTrend(id);
      setState(() {
        _kpSpots = [];
        _kpLabels = [];
        _kpName = results.isNotEmpty ? results.first.knowledgeName : '';
        for (var i = 0; i < results.length; i++) {
          _kpSpots.add(FlSpot(i.toDouble(), results[i].errorRate * 100));
          _kpLabels.add(formatDate(results[i].createdAt != null
              ? DateTime.parse(results[i].createdAt!)
              : DateTime.now()));
        }
      });
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据看板')),
      body: RefreshIndicator(
        onRefresh: _loadTrend,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('得分率趋势',
                style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _subject,
              items: _subjects
                  .map((s) => DropdownMenuItem(
                      value: s, child: Text(s.isEmpty ? '全部科目' : s)))
                  .toList(),
              onChanged: (v) => setState(() {
                _subject = v!;
                _loadTrend();
              }),
            ),
            const SizedBox(height: 8),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : TrendChart(spots: _spots, labels: _labels),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            const Text('单知识点趋势',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _kpIdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '知识点 ID',
                      hintText: '如报告中的 knowledge_point_id',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                    onPressed: _loadKpTrend, child: const Text('查询')),
              ],
            ),
            const SizedBox(height: 8),
            if (_kpName.isNotEmpty)
              Text('知识点：$_kpName（错误率 %）',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            TrendChart(spots: _kpSpots, labels: _kpLabels, yHint: '错误率(%)'),
          ],
        ),
      ),
    );
  }
}
