import 'package:flutter/material.dart';

import 'calendar/calendar_page.dart';
import 'community/community_page.dart';
import 'analysis/analysis_center_page.dart';
import 'messages/messages_page.dart';
import 'profile/profile_page.dart';

/// 底部导航容器（5 Tab）：[日历(首页)] [分析] [社区] [消息] [我的]。
/// 首页由「高考日历」承担（含倒计时 + 月视图），分析独立为一级入口。
class HomeShell extends StatefulWidget {
  const HomeShell({Key? key}) : super(key: key);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final List<Widget> _pages = const [
    CalendarPage(),
    AnalysisCenterPage(),
    CommunityPage(),
    MessagesPage(),
    ProfilePage(),
  ];
  final List<_Tab> _tabs = const [
    _Tab(icon: Icons.calendar_today, label: '日历'),
    _Tab(icon: Icons.insights, label: '分析'),
    _Tab(icon: Icons.forum, label: '社区'),
    _Tab(icon: Icons.notifications, label: '消息'),
    _Tab(icon: Icons.person, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _index = i),
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                icon: Icon(t.icon), label: t.label))
            .toList(),
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final String label;
  const _Tab({required this.icon, required this.label});
}
