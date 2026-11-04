import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications: the live timer in the status bar, the pomodoro end
/// alarm and the daily review reminder.
///
/// Every method is a no-op when the platform is unsupported (web) or
/// initialization failed, so callers never need to guard.
/// Times are scheduled in UTC, which avoids needing the device's IANA zone.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _pomodoroId = 1;
  static const _reviewId = 2;
  static const _timerId = 3;
  static const _pomodoroPayload = 'pomodoro';
  static const _workEndPayload = 'pomodoro:work';
  static const _restEndPayload = 'pomodoro:rest';
  static const _lockChannel = MethodChannel('ags/lock_alarm');

  /// Set while the end alarm is shown over the lock screen (Android):
  /// true = a work phase ended, false = a rest ended, null = not shown.
  final lockAlarm = ValueNotifier<bool?>(null);

  /// Confirms the lock-screen alarm and puts the lock screen back on top.
  Future<void> dismissLockAlarm() async {
    lockAlarm.value = null;
    try {
      await _lockChannel.invokeMethod<void>('dismiss');
    } catch (e) {
      debugPrint('Lock alarm dismiss failed: $e');
    }
  }

  /// Whether the end alarm may wake the screen. Android 14+ can deny
  /// full-screen intents; the alarm then only rings and vibrates.
  Future<bool> canWakeScreen() async {
    if (!_ready || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _lockChannel.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
    } catch (e) {
      debugPrint('Full-screen intent check failed: $e');
      return true;
    }
  }

  /// Opens the system page where the user allows full-screen alarms.
  Future<void> requestWakeScreen() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestFullScreenIntentPermission();
    } catch (e) {
      debugPrint('Full-screen intent request failed: $e');
    }
  }

  Future<void> _initLockAlarm() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    void apply(Object? payload) {
      if (payload is String) lockAlarm.value = payload != _restEndPayload;
    }

    _lockChannel.setMethodCallHandler((call) async {
      if (call.method == 'show') {
        apply(call.arguments);
        await _lockChannel.invokeMethod<void>('takePending');
      } else if (call.method == 'hide') {
        lockAlarm.value = null;
      }
    });
    try {
      apply(await _lockChannel.invokeMethod<String>('takePending'));
    } catch (e) {
      debugPrint('Lock alarm unavailable: $e');
    }
  }

  /// Incremented whenever the user opens a pomodoro/timer notification while
  /// the app is running, so the UI can jump to the timer.
  final pomodoroTaps = ValueNotifier<int>(0);
  bool _launchedFromPomodoro = false;

  /// True once if the app was cold-started from a pomodoro notification.
  bool takeLaunchedFromPomodoro() {
    final v = _launchedFromPomodoro;
    _launchedFromPomodoro = false;
    return v;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'ags_reminders',
      'Çalışma Hatırlatmaları',
      channelDescription: 'Pomodoro bitişi ve günlük tekrar hatırlatmaları',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Phase end: wakes the screen (full-screen intent), vibrates and rings on
  /// the alarm stream so it is noticed even when the phone is locked.
  static final _alarmDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'pomodoro_alarm',
      'Pomodoro Bitişi',
      channelDescription: 'Pomodoro ve mola süresi dolduğunda titreşimli uyarı',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 700, 300, 700, 300, 700, 300, 1200]),
      visibility: NotificationVisibility.public,
    ),
    iOS: const DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
  );

  static const _timerChannel = 'pomodoro_timer';
  static const _timerChannelName = 'Çalışan Sayaç';
  static const _timerChannelDesc = 'Pomodoro ve kronometre süresini bildirim çubuğunda gösterir';

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          windows: WindowsInitializationSettings(
            appName: 'AGS Çalışma Asistanı',
            appUserModelId: 'com.agsplanner.ags_planner',
            guid: '6f1d3c2a-8b4e-4f7a-9c0d-2e5b7a9f1c34',
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload?.startsWith(_pomodoroPayload) ?? false) pomodoroTaps.value++;
        },
      );
      _ready = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      _launchedFromPomodoro = launch != null &&
          launch.didNotificationLaunchApp &&
          (launch.notificationResponse?.payload?.startsWith(_pomodoroPayload) ?? false);
      await _initLockAlarm();
      // A fresh start has no running timer, so a leftover status-bar timer is stale.
      await _plugin.cancel(id: _timerId);
      // Not awaited: the system dialog must not block the first frame.
      _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission()
          .catchError((Object e) {
        debugPrint('Notification permission request failed: $e');
        return null;
      });
    } catch (e) {
      debugPrint('NotificationService disabled: $e');
    }
  }

  Future<void> schedulePomodoroEnd(Duration after, {required bool isRest}) async {
    if (!_ready) return;
    // Clear the previous "time's up" alert, so this phase's end is posted as a
    // new notification (an update of an old one wouldn't wake the screen).
    await _cancel(_pomodoroId);
    // Exact timing matters for a timer; fall back to inexact if not allowed.
    var exact = true;
    try {
      exact = await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.canScheduleExactNotifications() ??
          true;
    } catch (_) {
      exact = false;
    }
    await _schedule(
      _pomodoroId,
      DateTime.now().add(after),
      isRest ? 'Mola bitti ⏰' : 'Süre doldu! Pomodoro tamamlandı 🎉',
      isRest ? 'Yeni bir pomodoroya hazırsın.' : 'Harika iş! Oturumunu kaydetmek için dokun.',
      details: _alarmDetails,
      payload: isRest ? _restEndPayload : _workEndPayload,
      // Alarm-clock alarms fire on the second, even in Doze, in step with the in-app timer.
      mode: exact ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelPomodoro() => _cancel(_pomodoroId);

  /// Shows the timer in the status bar. The system itself renders the
  /// ticking clock, so it keeps counting while the app is in the background.
  /// Pass [countDownTo] for pomodoro phases, [countUpFrom] for the stopwatch.
  Future<void> showRunningTimer({
    required String title,
    required String subject,
    DateTime? countDownTo,
    DateTime? countUpFrom,
  }) {
    final down = countDownTo != null;
    final when = (countDownTo ?? countUpFrom ?? DateTime.now()).millisecondsSinceEpoch;
    final left = when - DateTime.now().millisecondsSinceEpoch;
    return _show(
      title,
      subject,
      AndroidNotificationDetails(
        _timerChannel,
        _timerChannelName,
        channelDescription: _timerChannelDesc,
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
        ongoing: true,
        autoCancel: false,
        when: when,
        usesChronometer: true,
        chronometerCountDown: down,
        // Disappear at zero; the end alarm takes over from there.
        timeoutAfter: down ? (left < 1 ? 1 : left) : null,
        category: AndroidNotificationCategory.stopwatch,
        visibility: NotificationVisibility.public,
      ),
    );
  }

  /// Static, dismissible status-bar entry for a paused timer.
  Future<void> showPausedTimer({required String title, required String subject}) => _show(
        title,
        subject,
        const AndroidNotificationDetails(
          _timerChannel,
          _timerChannelName,
          channelDescription: _timerChannelDesc,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          onlyAlertOnce: true,
          showWhen: false,
          visibility: NotificationVisibility.public,
        ),
      );

  Future<void> cancelTimer() => _cancel(_timerId);

  /// Schedules (or, when [count] is 0, cancels) the review reminder.
  Future<void> scheduleReviewReminder(DateTime at, int count) => count == 0
      ? _cancel(_reviewId)
      : _schedule(
          _reviewId,
          at,
          'Bugün $count tekrarın var',
          '7. ve 30. gün tekrarlarını yaparak bilgini kalıcı hale getir.',
        );

  /// Timer entries are Android-only (iOS has no live status-bar timer).
  Future<void> _show(String title, String body, AndroidNotificationDetails android) async {
    if (!_ready || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _plugin.show(
        id: _timerId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: android),
        payload: _pomodoroPayload,
      );
    } catch (e) {
      debugPrint('Notification show failed: $e');
    }
  }

  Future<void> _schedule(
    int id,
    DateTime at,
    String title,
    String body, {
    NotificationDetails details = _details,
    String? payload,
    // Inexact by default: needs no exact-alarm permission; drift is fine for reminders.
    AndroidScheduleMode mode = AndroidScheduleMode.inexactAllowWhileIdle,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: details,
        payload: payload,
        androidScheduleMode: mode,
      );
    } catch (e) {
      debugPrint('Notification schedule failed: $e');
    }
  }

  Future<void> _cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Notification cancel failed: $e');
    }
  }
}
