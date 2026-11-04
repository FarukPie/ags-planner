import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/notification_service.dart';
import '../../providers/app_provider.dart';

import '../dashboard/dashboard_screen.dart';
import '../exams/exams_screen.dart';
import '../pomodoro/pomodoro_screen.dart';
import '../agenda/agenda_screen.dart';
import '../notes/notes_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  int _index = 0;

  /// Drives a short fade/slide whenever the tab changes.
  late final AnimationController _switch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  static const _screens = [
    DashboardScreen(),
    PomodoroScreen(),
    ExamsScreen(),
    NotesScreen(),
    AgendaScreen(),
  ];

  static const _pomodoroTab = 1;
  NotificationService? _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = context.read<AppProvider>().notifications;
    // Opening a pomodoro notification lands on the timer.
    if (_notifications?.takeLaunchedFromPomodoro() ?? false) _index = _pomodoroTab;
    _notifications?.pomodoroTaps.addListener(_openPomodoro);
  }

  void _openPomodoro() => _select(_pomodoroTab);

  @override
  void dispose() {
    _notifications?.pomodoroTaps.removeListener(_openPomodoro);
    _switch.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _switch.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _switch, curve: Curves.easeOutCubic);
    return Scaffold(
      // IndexedStack keeps each tab's state (e.g. a running timer) alive.
      body: FadeTransition(
        opacity: t,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(t),
          child: IndexedStack(index: _index, children: _screens),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        animationDuration: const Duration(milliseconds: 500),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Panel'),
          NavigationDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer_rounded), label: 'Pomodoro'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Denemeler'),
          NavigationDestination(icon: Icon(Icons.sticky_note_2_outlined), selectedIcon: Icon(Icons.sticky_note_2_rounded), label: 'Notlar'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note_rounded), label: 'Ajanda'),
        ],
      ),
    );
  }
}
