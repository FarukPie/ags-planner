import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// What keeps the pomodoro end alarm from waking the screen (Android).
enum WakeBlocker {
  /// Android 14+ full-screen alarm permission is off.
  fullScreenIntent,

  /// Xiaomi (MIUI/HyperOS) "show on lock screen" or "open new windows while
  /// running in the background" is off; these are off by default there.
  xiaomi,
}

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
  static const _pomodoroPayload = 'pomodoro';
  static const _workEndPayload = 'pomodoro:work';
  static const _restEndPayload = 'pomodoro:rest';
  static const _lockChannel = MethodChannel('ags/lock_alarm');
  static const _timerNotification = MethodChannel('ags/timer_notification');

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

  /// Why the end alarm can't wake the screen, or null when it can.
  Future<WakeBlocker?> wakeBlocker() async {
    if (!_ready || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final name = await _lockChannel.invokeMethod<String>('wakeBlocker');
      return WakeBlocker.values.where((b) => b.name == name).firstOrNull;
    } catch (e) {
      debugPrint('Wake-screen check failed: $e');
      return null;
    }
  }

  /// Opens the system page where the user lifts [blocker].
  Future<void> requestWakeScreen(WakeBlocker blocker) async {
    try {
      switch (blocker) {
        case WakeBlocker.fullScreenIntent:
          await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestFullScreenIntentPermission();
        case WakeBlocker.xiaomi:
          await _lockChannel.invokeMethod<void>('openXiaomiPermissions');
      }
    } catch (e) {
      debugPrint('Wake-screen request failed: $e');
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

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
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
      await _initTimerTaps();
      // A fresh start has no running timer, so a leftover status-bar timer is stale.
      await cancelTimer();
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

  /// Shows the timer in the status bar, a large clock on the left. The
  /// system renders the ticking clock, so it keeps counting while the app is
  /// in the background. [value] is the time left ([countDown], pomodoro) or
  /// elapsed (stopwatch); a paused timer ([running] false) shows it frozen.
  /// Android only (iOS has no live status-bar timer).
  Future<void> showTimer({
    required String title,
    required String subject,
    required Duration value,
    required bool countDown,
    required bool running,
  }) =>
      _timerCall('show', {
        'title': title,
        'subject': subject,
        'valueMs': value.inMilliseconds,
        'countDown': countDown,
        'running': running,
      });

  Future<void> cancelTimer() => _timerCall('cancel');

  Future<void> _timerCall(String method, [Map<String, Object>? args]) async {
    if (!_ready || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _timerNotification.invokeMethod<void>(method, args);
    } catch (e) {
      debugPrint('Timer notification $method failed: $e');
    }
  }

  /// Taps on the status-bar timer open the pomodoro tab, like the alarm's.
  Future<void> _initTimerTaps() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _timerNotification.setMethodCallHandler((call) async {
      if (call.method == 'tap') pomodoroTaps.value++;
    });
    try {
      if (await _timerNotification.invokeMethod<bool>('takeLaunch') ?? false) _launchedFromPomodoro = true;
    } catch (e) {
      debugPrint('Timer notification unavailable: $e');
    }
  }

  /// Schedules (or, when [count] is 0, cancels) the review reminder.
  Future<void> scheduleReviewReminder(DateTime at, int count) => count == 0
      ? _cancel(_reviewId)
      : _schedule(
          _reviewId,
          at,
          'Bugün $count tekrarın var',
          '7. ve 30. gün tekrarlarını yaparak bilgini kalıcı hale getir.',
        );

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
