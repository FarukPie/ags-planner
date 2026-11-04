import 'dart:math';

import 'package:flutter/material.dart';

/// Bursts confetti over everything currently on screen (including dialogs
/// that are already open). Ignores touches and removes itself when done.
void showConfetti(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => ConfettiBurst(onDone: () => entry.remove()));
  overlay.insert(entry);
}

/// One confetti burst filling its parent; [onDone] runs when it has fallen.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  static const _colors = [
    Color(0xFF6C4CF1), Color(0xFF3D8BFD), Color(0xFF22C7B8),
    Color(0xFFFFC23D), Color(0xFFFF6B6B), Color(0xFF3FC380), Color(0xFFFF8FD8),
  ];

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    })
    ..forward();

  late final List<_Piece> _pieces = () {
    final r = Random();
    return List.generate(140, (i) {
      // Two cannons in the bottom corners, shooting up and inwards.
      final left = i.isEven;
      final angle = (left ? -pi / 2 + 0.15 : -pi / 2 - 0.15) + (r.nextDouble() - 0.5) * 0.9 + (left ? 0.35 : -0.35);
      final speed = 1.6 + r.nextDouble() * 1.0;
      return _Piece(
        startX: left ? 0 : 1,
        vx: cos(angle) * speed * 0.55,
        vy: sin(angle) * speed,
        spin: (r.nextDouble() - 0.5) * 18,
        size: 6 + r.nextDouble() * 6,
        color: _colors[r.nextInt(_colors.length)],
        round: r.nextInt(3) == 0,
      );
    });
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _c.value)),
      ),
    );
  }
}

class _Piece {
  _Piece({
    required this.startX,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.size,
    required this.color,
    required this.round,
  });

  final double startX, vx, vy, spin, size;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 2.4;
    final time = t * 2.2; // simulated seconds
    final fade = t < 0.75 ? 1.0 : (1 - t) / 0.25;
    final paint = Paint();
    for (final p in pieces) {
      // Positions in screen-height units, with air drag on horizontal speed.
      final x = p.startX * size.width + p.vx * size.height * (1 - exp(-1.5 * time)) / 1.5;
      final y = size.height + (p.vy * time + 0.5 * gravity * time * time) * size.height * 0.6;
      if (y > size.height + 20) continue;
      paint.color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * time);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        // Flip vertically over time so the paper looks like it tumbles.
        final h = p.size * 0.6 * cos(p.spin * time * 0.7).abs().clamp(0.2, 1.0);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: h), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
