/// 日历事件（与 backend/model.CalendarEvent 一致）。
class CalendarEvent {
  final int id;
  final int userId;
  final int? studentId;
  final String title;
  final String eventType; // mock_exam / gaokao / physical_exam / oral_exam / registration / volunteer / custom
  final DateTime eventDate;
  final String? subject;
  final int reminderBefore;
  final bool isReminded;
  final String? createdAt;

  const CalendarEvent({
    required this.id,
    required this.userId,
    this.studentId,
    required this.title,
    required this.eventType,
    required this.eventDate,
    this.subject,
    this.reminderBefore = 0,
    this.isReminded = false,
    this.createdAt,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
        id: j['id'] as int,
        userId: j['user_id'] as int,
        studentId: j['student_id'] as int?,
        title: j['title'] as String,
        eventType: j['event_type'] as String? ?? 'custom',
        eventDate: DateTime.parse(j['event_date'] as String),
        subject: j['subject'] as String?,
        reminderBefore: j['reminder_before'] as int? ?? 0,
        isReminded: j['is_reminded'] as bool? ?? false,
        createdAt: j['created_at'] as String?,
      );
}

/// 官方节点模板（GET /api/calendar/templates）。
class CalendarTemplate {
  final String name;
  final String eventType;
  final int monthOff; // 相对高考日的月份偏移（负数为之前）
  final String desc;

  const CalendarTemplate({
    required this.name,
    required this.eventType,
    required this.monthOff,
    required this.desc,
  });

  factory CalendarTemplate.fromJson(Map<String, dynamic> j) => CalendarTemplate(
        name: j['name'] as String,
        eventType: j['event_type'] as String,
        monthOff: j['month_off'] as int? ?? 0,
        desc: j['desc'] as String? ?? '',
      );
}
