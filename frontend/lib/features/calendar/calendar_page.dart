import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../models/calendar.dart';
import '../../widgets/common_widgets.dart';

/// 事件类型对应的标记颜色
const Map<String, Color> _typeColors = {
  'gaokao': Colors.red,
  'mock_exam': Colors.orange,
  'registration': Colors.blue,
  'physical_exam': Colors.green,
  'oral_exam': Colors.purple,
  'volunteer': Colors.teal,
  'custom': Colors.grey,
};

/// 高考日历（FR-CAL）：倒计时、月视图日历、官方节点模板、事件列表与新增、模拟考成绩记录。
class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  int? _countdownDays;
  String _gaokaoDate = '';
  List<CalendarTemplate> _templates = [];
  List<CalendarEvent> _events = [];
  Map<String, List<CalendarEvent>> _eventsByDate = {};
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();
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
      final cd = await api.getCountdown();
      _countdownDays = cd['days'] as int;
      _gaokaoDate = cd['gaokao_date'] as String;
      _templates = await api.getTemplates();
      _events = await api.listEvents();
      _eventsByDate = {};
      for (final e in _events) {
        final key = formatDate(e.eventDate);
        _eventsByDate.putIfAbsent(key, () => []).add(e);
      }
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  List<CalendarEvent> get _selectedEvents {
    final key = formatDate(_selected);
    return _eventsByDate[key] ?? [];
  }

  Future<void> _addEvent(CalendarTemplate? tpl) async {
    final titleCtrl = TextEditingController(text: tpl?.name ?? '');
    final subjectCtrl = TextEditingController();
    final dateCtrl = TextEditingController(
        text: DateTime.now().add(Duration(days: tpl?.monthOff ?? 0))
                .toString().substring(0, 10));
    final type = tpl?.eventType ?? 'custom';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tpl == null ? '新增日程' : '添加：${tpl.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '标题')),
            TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(
                    labelText: '日期 (yyyy-MM-dd)')),
            TextField(
                controller: subjectCtrl,
                decoration: const InputDecoration(labelText: '科目(可选)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<ApiClient>().createEvent(
                      title: titleCtrl.text,
                      eventDate: dateCtrl.text,
                      eventType: type,
                      subject: subjectCtrl.text.isEmpty
                          ? null
                          : subjectCtrl.text,
                    );
                _toast('已保存');
                _load();
              } on ApiException catch (e) {
                _toast(e.message);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_countdownDays != null)
            CountdownCard(days: _countdownDays!, gaokaoDate: _gaokaoDate),
          const SizedBox(height: 16),
          _MonthCalendar(
            focusedMonth: _focusedMonth,
            selected: _selected,
            eventsByDate: _eventsByDate,
            onSelect: (d) => setState(() => _selected = d),
            onMonthChange: (m) => setState(() => _focusedMonth = m),
          ),
          const SizedBox(height: 12),
          _DayEvents(
            selected: _selected,
            events: _selectedEvents,
          ),
          const SizedBox(height: 16),
          const Text('官方节点模板（一键添加）',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: _templates
                .map((t) => ActionChip(
                      label: Text(t.name),
                      onPressed: () => _addEvent(t),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('我的全部日程',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => _addEvent(null),
                icon: const Icon(Icons.add),
                label: const Text('新增'),
              ),
            ],
          ),
          ..._events.map((e) => ExamCard(
                title: e.title,
                date: formatDate(e.eventDate),
                subtitle:
                    '${_typeLabel(e.eventType)}${e.subject != null ? ' · ${e.subject}' : ''}',
              )),
          if (_events.isEmpty)
            const Text('暂无日程，点击右上角新增或选择模板。',
                style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  String _typeLabel(String t) {
    const map = {
      'mock_exam': '模拟考',
      'gaokao': '高考',
      'physical_exam': '体测',
      'oral_exam': '口试',
      'registration': '报名',
      'volunteer': '志愿',
      'custom': '自定义',
    };
    return map[t] ?? t;
  }
}

/// 月视图日历网格
class _MonthCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selected;
  final Map<String, List<CalendarEvent>> eventsByDate;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onMonthChange;

  const _MonthCalendar({
    required this.focusedMonth,
    required this.selected,
    required this.eventsByDate,
    required this.onSelect,
    required this.onMonthChange,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final leading = (first.weekday - 1) % 7; // 周一为每周起始
    final cells = <Widget>[];
    // 星期表头
    const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
    for (final w in weekLabels) {
      cells.add(Center(
          child: Text(w,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))));
    }
    // 前置空格
    for (int i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    // 日期格
    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(focusedMonth.year, focusedMonth.month, d);
      final key = formatDate(day);
      final dayEvents = eventsByDate[key] ?? [];
      final isSelected = day.year == selected.year &&
          day.month == selected.month &&
          day.day == selected.day;
      final isToday = day.year == DateTime.now().year &&
          day.month == DateTime.now().month &&
          day.day == DateTime.now().day;
      cells.add(_DayCell(
        day: day,
        events: dayEvents,
        isSelected: isSelected,
        isToday: isToday,
        onTap: () => onSelect(day),
      ));
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => onMonthChange(
                      DateTime(focusedMonth.year, focusedMonth.month - 1)),
                ),
                Text(DateFormat('yyyy 年 M 月').format(focusedMonth),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => onMonthChange(
                      DateTime(focusedMonth.year, focusedMonth.month + 1)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.1,
              children: cells,
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个日期格
class _DayCell extends StatelessWidget {
  final DateTime day;
  final List<CalendarEvent> events;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.events,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dots = events
        .take(3)
        .map((e) => _typeColors[e.eventType] ?? Colors.grey)
        .toList();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday && !isSelected
              ? Border.all(color: Theme.of(context).primaryColor, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.white : null,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                )),
            if (dots.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: dots
                    .map((c) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : c,
                            shape: BoxShape.circle,
                          ),
                        ))
                    .toList(),
              ),
              if (events.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text('${events.length}件',
                      style: TextStyle(
                          fontSize: 9,
                          height: 1,
                          color: isSelected ? Colors.white70 : Colors.grey)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 选中日期的当日日程
class _DayEvents extends StatelessWidget {
  final DateTime selected;
  final List<CalendarEvent> events;

  const _DayEvents({required this.selected, required this.events});

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('M 月 d 日').format(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label 日程 · 共 ${events.length} 件',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Text('当天暂无日程', style: TextStyle(color: Colors.grey))
        else
          ...events.map((e) => ExamCard(
                title: e.title,
                date: formatDate(e.eventDate),
                subtitle:
                    '${_typeLabel(e.eventType)}${e.subject != null ? ' · ${e.subject}' : ''}',
              )),
      ],
    );
  }

  String _typeLabel(String t) {
    const map = {
      'mock_exam': '模拟考',
      'gaokao': '高考',
      'physical_exam': '体测',
      'oral_exam': '口试',
      'registration': '报名',
      'volunteer': '志愿',
      'custom': '自定义',
    };
    return map[t] ?? t;
  }
}
