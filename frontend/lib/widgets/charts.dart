import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/analysis.dart';
import '../models/exam.dart';

/// 三档分布环形图（🔴待改进 / 🟡需关注 / 🟢继续保持）。
class TierChart extends StatelessWidget {
  final Map<String, int> dist; // {urgent, attention, keep}

  const TierChart({Key? key, required this.dist}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[
      _section('urgent', dist['urgent'] ?? 0),
      _section('attention', dist['attention'] ?? 0),
      _section('keep', dist['keep'] ?? 0),
    ];
    final total =
        (dist['urgent'] ?? 0) + (dist['attention'] ?? 0) + (dist['keep'] ?? 0);
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 48,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend('待改进', dist['urgent'] ?? 0, TierLevel.urgent),
            _legend('需关注', dist['attention'] ?? 0, TierLevel.attention),
            _legend('继续保持', dist['keep'] ?? 0, TierLevel.keep),
          ],
        ),
        if (total == 0)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('本次暂无知识点数据',
                style: TextStyle(color: Colors.grey)),
          ),
      ],
    );
  }

  PieChartSectionData _section(String level, int value) {
    final color = Color(TierLevel.colorValue(level));
    return PieChartSectionData(
      value: value.toDouble(),
      title: value > 0 ? '$value' : '',
      color: color,
      radius: 56,
      titleStyle: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
    );
  }

  Widget _legend(String label, int value, String level) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: Color(TierLevel.colorValue(level)), radius: 5),
            const SizedBox(width: 4),
            Text('$label $value', style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}

/// 得分率趋势折线图。每个点对应一次考试。
class TrendChart extends StatelessWidget {
  final List<FlSpot> spots;
  final List<String> labels; // x 轴标签（与 spots 顺序一致）
  final String yHint;

  const TrendChart({
    Key? key,
    required this.spots,
    required this.labels,
    this.yHint = '得分率(%)',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('暂无趋势数据', style: TextStyle(color: Colors.grey))),
      );
    }
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: (maxY > 100 ? maxY : 100) + 5,
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  final label =
                      idx >= 0 && idx < labels.length ? labels[idx] : '';
                  return Text(label,
                      style: const TextStyle(fontSize: 10, color: Colors.grey));
                },
              ),
            ),
            topTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.indigo,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// 能力雷达图。
///
/// 维度 ≥ 3 时渲染 [RadarChart]（学生维度=各科得分率 / 科目维度=知识点掌握度）；
/// 维度 < 3 时退化为横向条形图，避免 fl_chart 雷达图 require ≥ 3 个维度的断言失败。
class AbilityRadarChart extends StatelessWidget {
  final List<RadarPoint> points;
  final double maxValue;
  final Color color;

  const AbilityRadarChart({
    Key? key,
    required this.points,
    this.maxValue = 100,
    this.color = const Color(0xFFE6431A),
  }) : super(key: key);

  Widget _empty() => const SizedBox(
        height: 200,
        child: Center(child: Text('暂无能力数据', style: TextStyle(color: Colors.grey))),
      );

  /// 维度 < 3 的条形图退化方案。
  Widget _barFallback() => SizedBox(
        height: 200,
        child: ListView.separated(
          itemCount: points.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          itemBuilder: (_, i) {
            final p = points[i];
            final ratio = maxValue > 0 ? (p.value / maxValue).clamp(0.0, 1.0) : 0.0;
            final c = p.level.isNotEmpty
                ? Color(TierLevel.colorValue(p.level))
                : color;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(p.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${p.value.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF616161))),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 10,
                    backgroundColor: c.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation(c),
                  ),
                ),
              ],
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return _empty();
    if (points.length < 3) return _barFallback();
    return SizedBox(
      height: 280,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              dataEntries: points.map((p) => RadarEntry(value: p.value)).toList(),
              fillColor: color.withOpacity(0.18),
              borderColor: color,
              borderWidth: 2,
              entryRadius: 4,
            ),
          ],
          titlePositionPercentageOffset: 0.1,
          getTitle: (index, angle) => RadarChartTitle(
            text: points[index].label,
            angle: angle,
          ),
          tickCount: 4,
          ticksTextStyle: const TextStyle(color: Colors.grey, fontSize: 10),
          titleTextStyle: const TextStyle(
            color: Color(0xFF424242),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          radarBorderData: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
    );
  }
}

/// 多科目得分率趋势：每个科目一条折线，按真实考试日期对齐到同一时间轴。
class MultiSubjectTrendChart extends StatelessWidget {
  final List<Exam> exams; // 该学生全部考试（可跨学年）
  final double height;

  const MultiSubjectTrendChart({
    Key? key,
    required this.exams,
    this.height = 260,
  }) : super(key: key);

  static const _palette = [
    Color(0xFFE6431A),
    Colors.indigo,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  static const TextStyle _tick = TextStyle(fontSize: 10, color: Colors.grey);

  String _md(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (exams.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('暂无趋势数据', style: TextStyle(color: Colors.grey))),
      );
    }
    // 按科目分组并各自按时间升序
    final bySubject = <String, List<Exam>>{};
    for (final e in exams) {
      bySubject.putIfAbsent(e.subject, () => []).add(e);
    }
    final subjects = bySubject.keys.toList()..sort();
    // 全局时间轴（去重、升序）
    final dates = exams.map((e) => e.examDate).toSet().toList()
      ..sort((a, b) => a.compareTo(b));
    final xOf = <DateTime, double>{};
    for (var i = 0; i < dates.length; i++) xOf[dates[i]] = i.toDouble();

    final bars = <LineChartBarData>[];
    var ci = 0;
    for (final subj in subjects) {
      final list = bySubject[subj]!
        ..sort((a, b) => a.examDate.compareTo(b.examDate));
      final spots = list
          .map((e) => FlSpot(xOf[e.examDate]!, e.scoredRate))
          .toList();
      bars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: _palette[ci % _palette.length],
        barWidth: 2.5,
        dotData: FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
      ));
      ci++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 105,
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: _tick),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      return idx >= 0 && idx < dates.length
                          ? Text(_md(dates[idx]), style: _tick)
                          : const Text('');
                    },
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: bars,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (var i = 0; i < subjects.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _palette[i % _palette.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(subjects[i], style: const TextStyle(fontSize: 12)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
