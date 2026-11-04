import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'calendar_service.dart';

/// Google Sign-In → Firebase Auth. Unavailable (but harmless) when Firebase
/// is not configured or the platform has no interactive Google sign-in.
class AuthService extends ChangeNotifier {
  AuthService({required this.firebaseReady});

  final bool firebaseReady;
  bool _available = false;
  User? _user;
  StreamSubscription<User?>? _sub;

  bool get isAvailable => _available;
  User? get user => _user;

  Future<void> init() async {
    if (!firebaseReady) return;
    try {
      await GoogleSignIn.instance.initialize();
      _available = GoogleSignIn.instance.supportsAuthenticate();
      // Restore the Google session silently so Calendar calls work after restart.
      unawaited(GoogleSignIn.instance.attemptLightweightAuthentication()?.catchError((_) => null));
    } catch (e) {
      debugPrint('Google Sign-In unavailable: $e');
    }
    _user = FirebaseAuth.instance.currentUser;
    _sub = FirebaseAuth.instance.authStateChanges().listen((u) {
      _user = u;
      notifyListeners();
    });
  }

  /// Throws on failure/cancel; the caller shows the message.
  Future<void> signIn() async {
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: CalendarService.scopes,
    );
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google kimlik bilgisi alınamadı.');
    }
    await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Google sign-out failed: $e');
    }
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
