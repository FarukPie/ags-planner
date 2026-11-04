import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_constants.dart';
import 'core/app_theme.dart';
import 'core/local_storage.dart';
import 'core/services/auth_service.dart';
import 'core/services/calendar_service.dart';
import 'core/services/notification_service.dart';
import 'features/onboarding/auth_gate.dart';
import 'features/pomodoro/lock_alarm_screen.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');

  // Firebase is optional: on platforms without a generated config (e.g.
  // Windows) currentPlatform throws and the app runs local-only.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase not configured, running offline/local-only: $e');
  }

  final notifications = NotificationService();
  await notifications.init();

  final auth = AuthService(firebaseReady: firebaseReady);
  await auth.init();

  final app = AppProvider(
    LocalStorage(await SharedPreferences.getInstance()),
    notifications: notifications,
    calendar: firebaseReady ? CalendarService() : null,
  );
  // Link/unlink cloud sync whenever the signed-in user changes.
  void syncUser() => app.setCloudUser(auth.user?.uid);
  auth.addListener(syncUser);
  syncUser();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: const AgsApp(),
    ),
  );
}

class AgsApp extends StatelessWidget {
  const AgsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: context.select<AppProvider, ThemeMode>((p) => p.themeMode),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => LockAlarmGate(
        notifications: context.read<AppProvider>().notifications,
        child: child!,
      ),
      home: const AuthGate(),
    );
  }
}
