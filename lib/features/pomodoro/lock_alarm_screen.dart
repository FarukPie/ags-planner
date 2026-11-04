import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/confetti.dart';

/// Wraps the whole app (above the Navigator). While the pomodoro end alarm is
/// shown over the lock screen it covers everything, dialogs included, with a
/// minimal screen, so nothing personal is visible without unlocking.
class LockAlarmGate extends StatelessWidget {
  const LockAlarmGate({super.key, required this.notifications, required this.child});

  final NotificationService? notifications;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final n = notifications;
    if (n == null) return child;
    return ValueListenableBuilder<bool?>(
      valueListenable: n.lockAlarm,
      builder: (context, workEnded, _) => Stack(
        fit: StackFit.expand,
        children: [
          // Kept mounted (timer state, open dialog) but hidden and inert.
          Offstage(offstage: workEnded != null, child: child),
          if (workEnded != null) _LockAlarmScreen(workEnded: workEnded, onConfirm: n.dismissLockAlarm),
        ],
      ),
    );
  }
}

class _LockAlarmScreen extends StatelessWidget {
  const _LockAlarmScreen({required this.workEnded, required this.onConfirm});

  final bool workEnded;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final gradient = workEnded ? AppTheme.brandGradient : AppTheme.warmGradient;
    return Material(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (workEnded) const ConfettiBurst(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Spacer(),
                    Icon(workEnded ? Icons.emoji_events_rounded : Icons.alarm_rounded, color: Colors.white, size: 96),
                    const SizedBox(height: 24),
                    Text(
                      workEnded ? 'Pomodoro tamamlandı 🎉' : 'Mola bitti ⏰',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      workEnded ? 'Süre doldu. Harika iş çıkardın!' : 'Süre doldu. Yeni pomodoroya hazırsın.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 17),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: gradient.colors.first,
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        onPressed: onConfirm,
                        child: const Text('Tamam'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
