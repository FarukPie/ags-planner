import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/study_session_model.dart';

enum TimerPhase { work, rest }

/// Pomodoro / stopwatch timer state.
///
/// Elapsed time is derived from wall-clock timestamps (not from counting
/// ticks), so it stays correct if the app is backgrounded or frames drop.
class StudyTimerController extends ChangeNotifier {
  StudyTimerController({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  StudyMode _mode = StudyMode.pomodoro;
  TimerPhase _phase = TimerPhase.work;
  int _workMinutes = 25;
  int _restMinutes = 5;

  Duration _accumulated = Duration.zero;
  DateTime? _runningSince;
  Timer? _ticker;

  /// Called when a pomodoro phase runs out. The controller has already
  /// moved on to the next phase (stopped) when this fires.
  void Function(TimerPhase finished)? onPhaseFinished;

  StudyMode get mode => _mode;
  TimerPhase get phase => _phase;
  int get workMinutes => _workMinutes;
  int get restMinutes => _restMinutes;
  bool get isRunning => _runningSince != null;

  bool _finishing = false;

  /// True while listeners are notified of a phase that ran out on its own
  /// (as opposed to the user pausing/resetting/skipping).
  bool get isFinishingNaturally => _finishing;

  /// True while a session is in progress (running or paused with time on it).
  bool get hasProgress => isRunning || _accumulated > Duration.zero;

  Duration get elapsed => _accumulated +
      (_runningSince == null ? Duration.zero : _clock().difference(_runningSince!));

  Duration get target => Duration(
        minutes: _phase == TimerPhase.work ? _workMinutes : _restMinutes,
      );

  Duration get remaining {
    final r = target - elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  /// 0..1 progress of the current pomodoro phase.
  double get progress => (elapsed.inMilliseconds / target.inMilliseconds).clamp(0.0, 1.0);

  void setMode(StudyMode mode) {
    if (hasProgress || mode == _mode) return;
    _mode = mode;
    _phase = TimerPhase.work;
    notifyListeners();
  }

  void setWorkMinutes(int minutes) {
    if (hasProgress) return;
    _workMinutes = minutes;
    notifyListeners();
  }

  void setRestMinutes(int minutes) {
    if (hasProgress) return;
    _restMinutes = minutes;
    notifyListeners();
  }

  void start() {
    if (isRunning) return;
    _runningSince = _clock();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => tick());
    notifyListeners();
  }

  void pause() {
    if (!isRunning) return;
    _accumulated = elapsed;
    _stopTicker();
    notifyListeners();
  }

  /// Clears the current phase's time without changing phase.
  void reset() {
    _accumulated = Duration.zero;
    _stopTicker();
    notifyListeners();
  }

  /// Ends the rest phase early (or switches phase manually) and stops.
  void skipPhase() {
    _accumulated = Duration.zero;
    _stopTicker();
    _phase = _phase == TimerPhase.work ? TimerPhase.rest : TimerPhase.work;
    notifyListeners();
  }

  /// Advances the clock-driven state. Public so tests can drive it.
  @visibleForTesting
  void tick() {
    if (_mode == StudyMode.pomodoro && isRunning && remaining == Duration.zero) {
      final finished = _phase;
      _finishing = true;
      skipPhase();
      _finishing = false;
      onPhaseFinished?.call(finished);
      return;
    }
    notifyListeners();
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _runningSince = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
