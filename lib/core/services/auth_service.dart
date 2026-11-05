import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'calendar_service.dart';

/// Google Sign-In → Firebase Auth. Unavailable (but harmless) when Firebase
/// is not configured or the platform has no interactive Google sign-in.
///
/// Every Google sign-in, whether from the login button or from the account
/// sheet Android shows on startup, also signs into Firebase, so the user
/// never has to pick an account twice.
class AuthService extends ChangeNotifier {
  AuthService({required this.firebaseReady});

  final bool firebaseReady;
  bool _available = false;
  User? _user;
  StreamSubscription<User?>? _sub;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleSub;

  /// The Firebase sign-in in progress; shared so the button flow and the
  /// startup sheet never sign in twice for the same account.
  Future<void>? _linking;

  bool get isAvailable => _available;
  User? get user => _user;

  /// True while a chosen Google account is being signed into Firebase.
  bool get isSigningIn => _linking != null;

  Future<void> init() async {
    if (!firebaseReady) return;
    _user = FirebaseAuth.instance.currentUser;
    _sub = FirebaseAuth.instance.authStateChanges().listen((u) {
      _user = u;
      notifyListeners();
    });
    try {
      await GoogleSignIn.instance.initialize();
      _available = GoogleSignIn.instance.supportsAuthenticate();
      _googleSub = GoogleSignIn.instance.authenticationEvents.listen((e) {
        if (e is GoogleSignInAuthenticationEventSignIn && FirebaseAuth.instance.currentUser == null) {
          _linkFirebase(e.user).catchError((Object err) => debugPrint('Firebase sign-in failed: $err'));
        }
      }, onError: (Object e) => debugPrint('Google sign-in event error: $e'));
      // Restores the Google session (for Calendar) of a returning user; on a
      // fresh install Android may show an account sheet, which signs in too.
      unawaited(GoogleSignIn.instance.attemptLightweightAuthentication()?.catchError((_) => null));
    } catch (e) {
      debugPrint('Google Sign-In unavailable: $e');
    }
  }

  /// Throws on failure/cancel; the caller shows the message.
  Future<void> signIn() async {
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: CalendarService.scopes,
    );
    await _linkFirebase(account);
  }

  Future<void> _linkFirebase(GoogleSignInAccount account) {
    final pending = _linking;
    if (pending != null) return pending;
    final linking = _signInWith(account);
    _linking = linking;
    notifyListeners();
    return linking.whenComplete(() {
      _linking = null;
      notifyListeners();
    });
  }

  Future<void> _signInWith(GoogleSignInAccount account) async {
    if (FirebaseAuth.instance.currentUser != null) return;
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
    _googleSub?.cancel();
    super.dispose();
  }
}
