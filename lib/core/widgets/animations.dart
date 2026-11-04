import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fades and slides its child in once, after a stagger based on [index].
/// Uses a single controller (no timers), so it is test-friendly.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  static const _step = 70; // ms between items
  static const _anim = 420; // ms per item

  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    final delay = math.min(widget.index, 8) * _step;
    final total = delay + _anim;
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: total))..forward();
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, 24 * (1 - _t.value)), child: child),
      ),
    );
  }
}

/// Counts from the previous value to [value] whenever it changes.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final String Function(double v) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}

/// Circular progress ring with a gradient stroke that animates to [progress].
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.colors,
    this.size = 64,
    this.stroke = 8,
    this.child,
    this.animate = true,
    this.trackColor,
  });

  final double progress;
  final List<Color> colors;
  final double size;
  final double stroke;
  final Widget? child;

  /// False for values that change every frame (e.g. a running timer).
  final bool animate;

  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final track = trackColor ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    Widget ring(double p) => CustomPaint(
          painter: _RingPainter(p.clamp(0.0, 1.0), colors, stroke, track),
          child: SizedBox.square(dimension: size, child: Center(child: child)),
        );
    if (!animate) return ring(progress);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, p, _) => ring(p),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.colors, this.stroke, this.track);

  final double progress;
  final List<Color> colors;
  final double stroke;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: colors.length == 1 ? [colors.first, colors.first] : colors,
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.colors != colors || old.track != track || old.stroke != stroke;
}

/// Gently pulses (scales) its child while [active] — e.g. a running timer.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(Pulse old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active && _c.isAnimating) {
      _c.animateTo(0, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => Transform.scale(
        scale: 1 + 0.025 * Curves.easeInOut.transform(_c.value),
        child: child,
      ),
    );
  }
}
