import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../providers/app_provider.dart';
import '../home/home_shell.dart';
import 'login_screen.dart';
import 'profile_form_page.dart';

/// Decides what the user sees:
/// 1. Google sign-in (mandatory wherever sign-in is supported),
/// 2. a short wait while the account's data (and maybe profile) syncs,
/// 3. the profile form until the required fields are filled,
/// 4. the app.
///
/// Where sign-in is impossible (Firebase not configured / unsupported
/// platform) step 1 is skipped and the app works locally.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final app = context.watch<AppProvider>();

    final (String key, Widget screen) = switch (()) {
      _ when auth.isAvailable && auth.user == null => ('login', const LoginScreen()),
      _ when app.profile == null && !app.initialSyncDone => ('loading', const _SyncingScreen()),
      _ when app.profile == null => ('profile', ProfileFormPage(initialName: auth.user?.displayName)),
      _ => ('home', const HomeShell()),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(anim), child: child),
      ),
      child: KeyedSubtree(key: ValueKey(key), child: screen),
    );
  }
}

class _SyncingScreen extends StatelessWidget {
  const _SyncingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppTheme.brandGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(dimension: 44, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
              SizedBox(height: 20),
              Text(
                'Hesabın hazırlanıyor…',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
