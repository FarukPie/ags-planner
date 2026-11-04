import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_constants.dart';
import '../../core/app_theme.dart';
import '../../core/format.dart';
import '../../core/lesson_style.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/confetti.dart';
import '../../core/widgets/decor.dart';
import '../../models/study_session_model.dart';
import '../../models/topic_model.dart';
import '../../providers/app_provider.dart';
import 'study_timer_controller.dart';
import 'widgets/save_session_dialog.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  final _timer = StudyTimerController();

  String? _lessonName;
  TopicModel? _topic;

  /// Last (running, hasProgress) pair the notifications were synced for.
  (bool, bool) _notified = (false, false);

  NotificationService? _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = context.read<AppProvider>().notifications;
    _timer.onPhaseFinished = _onPhaseFinished;
    _timer.addListener(_syncNotification);
  }

  /// Mirrors the timer to the system: a live countdown in the status bar and
  /// a scheduled end alarm, so the user is alerted even with the screen off.
  void _syncNotification() {
    final state = (_timer.isRunning, _timer.hasProgress);
    if (state == _notified) return;
    _notified = state;
    final n = _notifications;
    if (n == null) return;
    final isPomodoro = _timer.mode == StudyMode.pomodoro;
    final isRest = isPomodoro && _timer.phase == TimerPhase.rest;
    final title = !isPomodoro ? 'Kronometre ⏱️' : (isRest ? 'Mola ☕' : 'Odaklan 🎯');
    final subject = isRest ? 'Mola zamanı' : (_lessonName == null ? '' : _subject);

    if (_timer.isRunning) {
      final now = DateTime.now();
      if (isPomodoro) {
        n.schedulePomodoroEnd(_timer.remaining, isRest: isRest);
        n.showRunningTimer(title: title, subject: subject, countDownTo: now.add(_timer.remaining));
      } else {
        n.showRunningTimer(title: title, subject: subject, countUpFrom: now.subtract(_timer.elapsed));
      }
      return;
    }
    // A natural finish keeps the (possibly already shown) end alarm.
    if (!_timer.isFinishingNaturally) n.cancelPomodoro();
    if (_timer.hasProgress) {
      final left = isPomodoro ? '${_clock(_timer.remaining)} kaldı' : _clock(_timer.elapsed);
      n.showPausedTimer(title: '$title • Duraklatıldı', subject: subject.isEmpty ? left : '$subject • $left');
    } else {
      n.cancelTimer();
    }
  }

  @override
  void dispose() {
    _notifications?.cancelTimer();
    _timer.dispose();
    super.dispose();
  }

  String get _subject =>
      _topic == null ? _lessonName! : '$_lessonName • ${_topic!.topicName}';

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _onPhaseFinished(TimerPhase finished) async {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    if (finished == TimerPhase.work) {
      // The full pomodoro was worked; the timer already moved to rest.
      await _save(_timer.workMinutes, allowCancel: false, celebrate: true);
    } else {
      _snack('Mola bitti. Yeni pomodoroya hazırsın!');
    }
  }

  /// Manual "finish" for the stopwatch or a pomodoro ended early.
  Future<void> _finishEarly() async {
    _timer.pause();
    final minutes = _timer.elapsed.inMinutes;
    if (minutes < 1) {
      _timer.reset();
      _snack('1 dakikadan kısa oturumlar kaydedilmez.');
      return;
    }
    final saved = await _save(minutes, allowCancel: true);
    if (saved != null) _timer.reset(); // null = cancelled, keep paused
  }

  /// Returns null if cancelled, otherwise whether the session was stored.
  Future<bool?> _save(int minutes, {required bool allowCancel, bool celebrate = false}) async {
    final lesson = _lessonName;
    if (lesson == null) return false;
    final dialog = showSaveSessionDialog(
      context,
      minutes: minutes,
      subject: _subject,
      allowCancel: allowCancel,
      celebrate: celebrate,
    );
    // Inserted after the dialog route so the confetti falls over it.
    if (celebrate) showConfetti(context);
    final result = await dialog;
    if (result == null) return null;
    if (!result.save || !mounted) return false;
    await context.read<AppProvider>().addSession(
          lessonName: lesson,
          topicId: _topic?.id,
          topicName: _topic?.topicName,
          durationMinutes: minutes,
          mode: _timer.mode,
          activity: result.activity,
          solvedQuestions: result.solvedQuestions,
        );
    _snack('Oturum kaydedildi: ${formatMinutes(minutes)}');
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final byLesson = p.topicsByLesson;
    final tester = AppConstants.testerUids.contains(context.watch<AuthService?>()?.user?.uid);

    // Drop a selection that no longer exists (e.g. after a branch change),
    // but never while a session is in progress.
    if (!_timer.hasProgress && _lessonName != null && !byLesson.containsKey(_lessonName)) {
      _lessonName = null;
      _topic = null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Odak Zamanı')),
      body: ListenableBuilder(
        listenable: _timer,
        builder: (context, _) {
          final locked = _timer.hasProgress;
          final theme = Theme.of(context);
          final sections = <Widget>[
            Center(
              child: SegmentedButton<StudyMode>(
                segments: const [
                  ButtonSegment(value: StudyMode.pomodoro, label: Text('Pomodoro'), icon: Icon(Icons.timer_rounded)),
                  ButtonSegment(value: StudyMode.stopwatch, label: Text('Kronometre'), icon: Icon(Icons.av_timer_rounded)),
                ],
                selected: {_timer.mode},
                onSelectionChanged: locked ? null : (s) => _timer.setMode(s.first),
              ),
            ),
            const SizedBox(height: 24),
            _TimerDial(timer: _timer, subject: _lessonName == null ? null : _subject),
            const SizedBox(height: 24),
            _Controls(timer: _timer, canStart: _lessonName != null, onFinish: _finishEarly),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: _lessonName == null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Başlamak için aşağıdan bir ders seçin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 24),
            SoftShadow(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const IconBadge(icon: Icons.tune_rounded, color: Color(0xFF7B5CFA), size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Oturum Ayarları',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (locked) Icon(Icons.lock_rounded, size: 18, color: theme.colorScheme.outline),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _Picker<String>(
                        label: 'Ders',
                        value: _lessonName,
                        enabled: !locked,
                        items: {for (final l in byLesson.keys) l: l},
                        onChanged: (v) => setState(() {
                          _lessonName = v;
                          _topic = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      _Picker<TopicModel?>(
                        label: 'Konu (isteğe bağlı)',
                        value: _topic == null
                            ? null
                            : byLesson[_lessonName]?.where((t) => t.id == _topic!.id).firstOrNull,
                        enabled: !locked && _lessonName != null,
                        items: {
                          null: 'Genel çalışma',
                          for (final t in byLesson[_lessonName] ?? const <TopicModel>[]) t: t.topicName,
                        },
                        onChanged: (v) => setState(() => _topic = v),
                      ),
                      if (_timer.mode == StudyMode.pomodoro) ...[
                        const SizedBox(height: 12),
                        _DurationChips(
                          label: 'Çalışma',
                          options: [if (tester) 1, 25, 30, 45, 50],
                          selected: _timer.workMinutes,
                          onSelected: locked ? null : _timer.setWorkMinutes,
                        ),
                        _DurationChips(
                          label: 'Mola',
                          options: [if (tester) 1, 5, 10, 15],
                          selected: _timer.restMinutes,
                          onSelected: locked ? null : _timer.setRestMinutes,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _TodaySessions(sessions: p.sessionsOn(DateTime.now()), goalMinutes: p.profile?.dailyGoalMinutes ?? 120),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (var i = 0; i < sections.length; i++) FadeSlideIn(index: i ~/ 2, child: sections[i]),
            ],
          );
        },
      ),
    );
  }
}

String _clock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final ms = '${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  return h > 0 ? '${two(h)}:$ms' : ms;
}

class _Picker<T> extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.value,
    required this.items,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final Map<T, String> items;
  final bool enabled;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.containsKey(value) ? value : null,
          hint: const Text('Seçin'),
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          items: [
            for (final e in items.entries)
              DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }
}

class _DurationChips extends StatelessWidget {
  const _DurationChips({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<int> options;
  final int selected;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label)),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                for (final m in options)
                  ChoiceChip(
                    label: Text('$m dk'),
                    selected: m == selected,
                    onSelected: onSelected == null ? null : (_) => onSelected!(m),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerDial extends StatelessWidget {
  const _TimerDial({required this.timer, required this.subject});

  final StudyTimerController timer;
  final String? subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPomodoro = timer.mode == StudyMode.pomodoro;
    final isRest = isPomodoro && timer.phase == TimerPhase.rest;
    final gradient = isRest ? AppTheme.warmGradient : AppTheme.brandGradient;
    final accent = gradient.colors.first;
    final label = isPomodoro ? (isRest ? 'Mola ☕' : 'Odaklan 🎯') : 'Kronometre ⏱️';

    return Center(
      child: Pulse(
        active: timer.isRunning,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: 264,
          height: 264,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.cardTheme.color,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: timer.isRunning ? 0.45 : 0.18),
                blurRadius: timer.isRunning ? 40 : 24,
                spreadRadius: timer.isRunning ? 2 : 0,
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: ProgressRing(
            animate: false,
            progress: isPomodoro ? timer.progress : (timer.elapsed.inMilliseconds % 60000) / 60000,
            colors: gradient.colors,
            size: 240,
            stroke: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    label,
                    key: ValueKey(label),
                    style: theme.textTheme.titleMedium?.copyWith(color: accent, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  _clock(isPomodoro ? timer.remaining : timer.elapsed),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (subject != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Text(
                      subject!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.timer, required this.canStart, required this.onFinish});

  final StudyTimerController timer;
  final bool canStart;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final isRest = timer.mode == StudyMode.pomodoro && timer.phase == TimerPhase.rest;
    final enabled = canStart || isRest;
    final gradient = isRest ? AppTheme.warmGradient : AppTheme.brandGradient;
    final label = timer.isRunning
        ? 'Duraklat'
        : (timer.hasProgress ? 'Devam' : (isRest ? 'Molayı Başlat' : 'Başlat'));

    return Column(
      children: [
        // Big gradient play/pause button.
        AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: enabled ? 1 : 0.45,
          child: GradientCard(
            gradient: gradient,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
            onTap: !enabled ? null : (timer.isRunning ? timer.pause : timer.start),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Icon(
                    timer.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    key: ValueKey(timer.isRunning),
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: isRest
              ? [
                  TextButton.icon(
                    onPressed: timer.skipPhase,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Molayı Geç'),
                  ),
                ]
              : [
                  TextButton.icon(
                    onPressed: timer.hasProgress ? onFinish : null,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Bitir ve Kaydet'),
                  ),
                  TextButton.icon(
                    onPressed: timer.hasProgress && !timer.isRunning ? timer.reset : null,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Sıfırla'),
                  ),
                ],
        ),
      ],
    );
  }
}

class _TodaySessions extends StatelessWidget {
  const _TodaySessions({required this.sessions, required this.goalMinutes});

  final List<StudySessionModel> sessions;
  final int goalMinutes;

  Future<void> _confirmDelete(BuildContext context, StudySessionModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Oturum silinsin mi?'),
        content: Text('${s.lessonName} • ${formatMinutes(s.durationMinutes)} kaydı kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppProvider>().deleteSession(s.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = sessions.fold(0, (sum, s) => sum + s.durationMinutes);
    final questions = sessions.fold(0, (sum, s) => sum + s.solvedQuestions);

    return SoftShadow(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconBadge(icon: Icons.today_rounded, color: Color(0xFF3FC380), size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bugünkü Oturumlar',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          Text('${formatMinutes(total)} / ${formatMinutes(goalMinutes)} hedef • $questions soru',
                              style: TextStyle(color: theme.colorScheme.outline)),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 8, 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: goalMinutes == 0 ? 0 : (total / goalMinutes).clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 8,
                        color: v >= 1 ? const Color(0xFF3FC380) : null,
                      ),
                    ),
                  ),
                ),
                if (sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('Bugün henüz oturum kaydedilmedi. Hadi başlayalım! 🚀',
                        style: TextStyle(color: theme.colorScheme.outline)),
                  ),
                for (final s in sessions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconBadge(
                      icon: LessonStyle.of(s.lessonName).icon,
                      color: LessonStyle.of(s.lessonName).color,
                      size: 40,
                    ),
                    title: Text(
                      s.topicName == null ? s.lessonName : '${s.lessonName} • ${s.topicName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${DateFormat('HH:mm').format(s.createdAt)} • ${formatMinutes(s.durationMinutes)} • '
                      '${s.activity == StudyActivity.questions ? '${s.solvedQuestions} soru' : 'Konu çalışması'} • ${s.mode == StudyMode.pomodoro ? 'Pomodoro' : 'Kronometre'}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Sil',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _confirmDelete(context, s),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
