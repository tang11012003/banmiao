import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../models/analysis.dart';
import '../../models/exam.dart';
import '../../widgets/charts.dart';
import '../paper/paper_upload_page.dart';
import 'analysis_detail_page.dart';

/// 分析中心（合并「分析」与「数据看板」）：
/// - 学生 / 学年切换（9 月开学制学年标签）；
/// - 整体分析（全局统计 + 三档分布）；
/// - 学生能力雷达（各科最新得分率，按学年快照）；
/// - 各科目得分率趋势（全部学年，多折线）；
/// - 科目能力雷达（所选科目最新考试的知识点掌握度）；
/// - 过往分析列表（点击查看报告）。
class AnalysisCenterPage extends StatefulWidget {
  const AnalysisCenterPage({Key? key}) : super(key: key);

  @override
  State<AnalysisCenterPage> createState() => _AnalysisCenterPageState();
}

class _AnalysisCenterPageState extends State<AnalysisCenterPage> {
  List<StudentView> _students = [];
  int? _studentId;
  String _academicYear = ''; // '' = 全部学年
  String _subject = '';

  AnalysisOverview? _overview;
  RadarResponse? _radarStudent;
  RadarResponse? _radarSubject;
  List<Exam> _trend = [];
  List<AnalysisSummary> _list = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  ApiClient get _api => context.read<ApiClient>();

  Future<void> _loadStudents() async {
    setState(() => _loading = true);
    try {
      var students = await _api.listStudents();
      // 新用户尚未触发样例：先取整体分析以灌入样例数据，再取学生列表。
      if (students.isEmpty) {
        await _api.analysisOverview().catchError((_) {});
        students = await _api.listStudents();
      }
      if (!mounted) return;
      setState(() {
        _students = students;
        _studentId = students.isNotEmpty ? students.first.id : null;
        _academicYear = students.isNotEmpty
            ? (students.first.academicYears.isNotEmpty
                ? students.first.academicYears.last
                : '')
            : '';
        _subject = students.isNotEmpty && students.first.subjects.isNotEmpty
            ? students.first.subjects.first
            : '';
      });
      await _loadStudentScoped();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 加载当前学生相关的所有数据（整体分析、学生雷达、趋势、科目雷达、列表）。
  Future<void> _loadStudentScoped() async {
    if (_studentId == null) return;
    setState(() => _loading = true);
    try {
      _overview = await _api.analysisOverview();
      // 雷达按所选学年快照
      _radarStudent = await _api.analysisRadar(
        studentId: _studentId!,
        academicYear: _academicYear,
      );
      // 趋势用全部学年，保证每个科目有足够多的点形成折线
      _trend = await _api.scoreTrend(studentId: _studentId);
      if (_subject.isNotEmpty) {
        _radarSubject = await _api.analysisRadar(
          studentId: _studentId!,
          subject: _subject,
          academicYear: _academicYear,
        );
      }
      _list = await _api.myAnalyses();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onStudentChanged(int id) {
    final stu = _students.firstWhere((s) => s.id == id);
    setState(() {
      _studentId = id;
      _academicYear = stu.academicYears.isNotEmpty ? stu.academicYears.last : '';
      _subject = stu.subjects.isNotEmpty ? stu.subjects.first : '';
    });
    _loadStudentScoped();
  }

  void _onYearChanged(String year) {
    setState(() => _academicYear = year);
    _loadStudentScoped();
  }

  void _onSubjectChanged(String subj) {
    setState(() => _subject = subj);
    if (_studentId != null) {
      _loadStudentScoped();
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  StudentView? get _currentStudent =>
      _students.where((s) => s.id == _studentId).isEmpty
          ? null
          : _students.firstWhere((s) => s.id == _studentId);

  @override
  Widget build(BuildContext context) {
    final stu = _currentStudent;
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习分析'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaperUploadPage())),
            icon: const Icon(Icons.add_a_photo),
            label: const Text('上传'),
          ),
        ],
      ),
      body: _loading && _students.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadStudents();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 学生 / 学年切换
                  if (stu != null) _Selector(stu: stu),
                  const SizedBox(height: 16),
                  // 整体分析
                  if (_overview != null) _OverviewCard(ov: _overview!),
                  const SizedBox(height: 20),
                  // 学生能力雷达
                  _SectionTitle(title: '学生能力', subtitle: stu != null ? '${stu.name}·${stu.grade} 各科最新得分率' : null),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: AbilityRadarChart(
                        points: _radarStudent?.points ?? [],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 各科目趋势
                  const _SectionTitle(title: '各科目得分率趋势', subtitle: '全部学年'),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: MultiSubjectTrendChart(exams: _trend),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 科目能力（知识点）
                  if (stu != null && stu.subjects.isNotEmpty) ...[
                    const _SectionTitle(title: '科目能力（知识点掌握度）'),
                    const SizedBox(height: 8),
                    _SubjectChips(
                      subjects: stu.subjects,
                      selected: _subject,
                      onChanged: _onSubjectChanged,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: AbilityRadarChart(
                          points: _radarSubject?.points ?? [],
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // 过往分析
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

/// 学生 + 学年切换器。
class _Selector extends StatelessWidget {
  final StudentView stu;
  const _Selector({required this.stu});

  @override
  Widget build(BuildContext context) {
    final center = context.findAncestorStateOfType<_AnalysisCenterPageState>();
    final state = center;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('学生', style: TextStyle(fontSize: 13, color: Color(0xFF757575))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: state != null
                  ? state._students
                      .map((s) => ChoiceChip(
                            label: Text('${s.name}（${s.grade}）'),
                            selected: s.id == state._studentId,
                            onSelected: (_) => state._onStudentChanged(s.id),
                          ))
                      .toList()
                  : [],
            ),
            const SizedBox(height: 12),
            const Text('学年', style: TextStyle(fontSize: 13, color: Color(0xFF757575))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('全部学年'),
                  selected: state?._academicYear == '',
                  onSelected: (_) => state?._onYearChanged(''),
                ),
                ...stu.academicYears.reversed.map((y) => ChoiceChip(
                      label: Text(y),
                      selected: state?._academicYear == y,
                      onSelected: (_) => state?._onYearChanged(y),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 科目切换 chips。
class _SubjectChips extends StatelessWidget {
  final List<String> subjects;
  final String selected;
  final ValueChanged<String> onChanged;
  const _SubjectChips({
    required this.subjects,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        children: subjects
            .map((s) => ChoiceChip(
                  label: Text(s),
                  selected: s == selected,
                  onSelected: (_) => onChanged(s),
                ))
            .toList(),
      );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionTitle({required this.title, this.subtitle});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(Icons.insights, color: const Color(0xFFE6431A), size: 18),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(subtitle!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ],
      );
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('共 ${ov.totalAnalyses} 次分析',
                    style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
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
              _TierBar(label: '待改进', value: urgent, total: totalTier,
                  color: const Color(0xFFE53935)),
              _TierBar(label: '需关注', value: attn, total: totalTier,
                  color: const Color(0xFFFBC02D)),
              _TierBar(label: '继续保持', value: keep, total: totalTier,
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
  const _Stat({
    required this.value,
    required this.unit,
    required this.label,
    this.highlight = false,
  });
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
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
          ],
        ),
      );
}

class _TierBar extends StatelessWidget {
  final String label;
  final int value;
  final double total;
  final Color color;
  const _TierBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 64, child: Text(label, style: const TextStyle(fontSize: 12))),
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
                    style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE6431A).withOpacity(0.1),
          child: const Icon(Icons.analytics, color: Color(0xFFE6431A)),
        ),
        title: Text(a.examName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                if (a.subject.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(a.subject,
                        style: const TextStyle(fontSize: 11, color: Colors.indigo)),
                  ),
                Text(a.examDate, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
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
                    fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
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
  const _TierDots({required this.urgent, required this.attention, required this.keep});
  @override
  Widget build(BuildContext context) {
    final items = [
      if (urgent > 0) _Dot(color: const Color(0xFFE53935), n: urgent, t: '待改进'),
      if (attention > 0) _Dot(color: const Color(0xFFFBC02D), n: attention, t: '需关注'),
      if (keep > 0) _Dot(color: const Color(0xFF43A047), n: keep, t: '保持'),
    ];
    if (items.isEmpty) {
      return const Text('暂无知识点', style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)));
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
