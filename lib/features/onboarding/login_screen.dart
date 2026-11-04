import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/animations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().signIn();
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _error = 'Giriş yapılamadı. İnternet bağlantını kontrol edip tekrar dene.';
      }
    } catch (_) {
      _error = 'Giriş yapılamadı. İnternet bağlantını kontrol edip tekrar dene.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;

    Widget feature(IconData icon, String title, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: white, fontWeight: FontWeight.w800)),
                    Text(text, style: TextStyle(color: white.withValues(alpha: 0.8), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 24),
                        FadeSlideIn(
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: white.withValues(alpha: 0.4), width: 2),
                            ),
                            child: const Icon(Icons.school_rounded, color: white, size: 54),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const FadeSlideIn(
                          index: 1,
                          child: Text(
                            'AGS Asistanı',
                            style: TextStyle(color: white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FadeSlideIn(
                          index: 2,
                          child: Text(
                            'Akademi Giriş Sınavı yolculuğunda\nkişisel çalışma arkadaşın',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: white.withValues(alpha: 0.9), fontSize: 15, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 32),
                        FadeSlideIn(
                          index: 3,
                          child: Column(
                            children: [
                              feature(Icons.timer_rounded, 'Odaklan', 'Pomodoro ile çalış, her dakikayı kaydet.'),
                              feature(Icons.replay_rounded, 'Unutma', '7. ve 30. gün tekrarları otomatik planlanır.'),
                              feature(Icons.insights_rounded, 'Gelişimini gör', 'Deneme netlerini ve zayıf konularını izle.'),
                              feature(Icons.cloud_done_rounded, 'Her cihazda', 'Verilerin hesabınla güvenle senkronize.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    FadeSlideIn(
                      index: 4,
                      child: Column(
                        children: [
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            child: _error == null
                                ? const SizedBox(width: double.infinity)
                                : Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(_error!, style: const TextStyle(color: white)),
                                  ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: white,
                                foregroundColor: const Color(0xFF1F1F1F),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: _busy ? null : _signIn,
                              child: _busy
                                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _GoogleMark(),
                                        SizedBox(width: 12),
                                        Text('Google ile devam et', style: TextStyle(fontSize: 16)),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Devam ederek verilerinin yalnızca senin hesabında saklanmasını kabul edersin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: white.withValues(alpha: 0.75), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple multicolor "G" (no bundled asset needed).
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => const SweepGradient(
        colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335), Color(0xFF4285F4)],
      ).createShader(r),
      child: const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
    );
  }
}
