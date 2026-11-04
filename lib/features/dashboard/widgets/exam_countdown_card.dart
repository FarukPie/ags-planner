import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/ags_curriculum_data.dart';
import '../../../core/app_constants.dart';
import '../../../core/widgets/decor.dart';
import '../../../providers/app_provider.dart';

/// Live countdown to the exam on the brand gradient. Owns its own 1-second
/// ticker so only this card rebuilds every second. Tap to change the date.
class ExamCountdownCard extends StatefulWidget {
  const ExamCountdownCard({super.key});

  @override
  State<ExamCountdownCard> createState() => _ExamCountdownCardState();
}

class _ExamCountdownCardState extends State<ExamCountdownCard> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Future<void> _pickExamDate(DateTime current) async {
    final provider = context.read<AppProvider>();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current.isBefore(now) ? now : current,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      helpText: 'Sınav tarihini seçin',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: 'Sınav saatini seçin',
    );
    if (time == null) return;
    await provider.setExamDate(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  List<Widget> _officialInfo(BuildContext context) {
    final now = DateTime.now();
    final hasOabt = context.select<AppProvider, bool>((p) => p.branch.category == BranchCategory.oabt);
    final next = AppConstants.officialMilestones
        .where((m) => m.date.isAfter(now) && m.label != 'AGS' && (hasOabt || m.label != 'ÖABT'))
        .firstOrNull;
    final fmt = DateFormat('d MMMM EEEE', 'tr_TR');
    String days(DateTime d) {
      final n = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
      return n == 0 ? 'bugün' : '$n gün';
    }

    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 13)),
              ),
            ],
          ),
        );

    return [
      const SizedBox(height: 6),
      if (hasOabt)
        line(Icons.assignment_rounded,
            'ÖABT: ${fmt.format(AppConstants.officialOabtDate)} • ${days(AppConstants.officialOabtDate)}'),
      if (next != null && next.label != 'ÖABT')
        line(Icons.flag_rounded, '${next.label}: ${fmt.format(next.date)} • ${days(next.date)}'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final examDate = context.select<AppProvider, DateTime>((p) => p.examDate);
    final remaining = examDate.difference(DateTime.now());
    const white = Colors.white;

    return GradientCard(
      onTap: () => _pickExamDate(examDate),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'AGS geri sayım',
                  style: TextStyle(color: white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              const Spacer(),
              Icon(Icons.edit_calendar_rounded, color: white.withValues(alpha: 0.85), size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            DateFormat('d MMMM y EEEE, HH:mm', 'tr_TR').format(examDate),
            style: TextStyle(color: white.withValues(alpha: 0.9), fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (remaining.isNegative)
            const Text(
              'Sınav tarihi geçti — yeni tarih için dokunun',
              style: TextStyle(color: white, fontSize: 16, fontWeight: FontWeight.w600),
            )
          else
            Row(
              children: [
                _Unit(remaining.inDays, 'Gün', wide: true),
                _Unit(remaining.inHours % 24, 'Saat'),
                _Unit(remaining.inMinutes % 60, 'Dakika'),
                _Unit(remaining.inSeconds % 60, 'Saniye'),
              ],
            ),
          // Official calendar extras, only while the official date is in use.
          if (examDate == AppConstants.defaultExamDate) ..._officialInfo(context),
        ],
      ),
    );
  }
}

/// A countdown unit whose number rolls up when it changes.
class _Unit extends StatelessWidget {
  const _Unit(this.value, this.label, {this.wide = false});

  final int value;
  final String label;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final text = value.toString().padLeft(2, '0');
    return Expanded(
      flex: wide ? 5 : 4,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, anim) {
                  final incoming = child.key == ValueKey(text);
                  return SlideTransition(
                    position: Tween(
                      begin: Offset(0, incoming ? 0.8 : -0.8),
                      end: Offset.zero,
                    ).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  );
                },
                child: Text(
                  text,
                  key: ValueKey(text),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
