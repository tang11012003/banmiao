/// 轻量埋点：当前仅打印日志，便于联调与后续接入分析平台。
///
/// 关键埋点事件（对应 PRD 第十章）：register / auth_submit / paper_upload_success /
/// paper_share / share_to_community / community_post / invite_generate / invite_used 等。
class Tracker {
  void track(String event, [Map<String, dynamic>? params]) {
    final ts = DateTime.now().toIso8601String();
    // ignore: avoid_print
    print('[TRACK] $ts | $event | ${params ?? <String, dynamic>{}}');
  }
}
