import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated DNA double helix made of glowing particles.
///
/// It is drawn live with a [CustomPainter] rather than played from a video
/// file, so it stays razor sharp on any screen (4K included), costs no
/// download size, and never stutters on a loop point. It is only used on the
/// login page.
class HelixBackground extends StatefulWidget {
  const HelixBackground({super.key});

  @override
  State<HelixBackground> createState() => _HelixBackgroundState();
}

class _HelixBackgroundState extends State<HelixBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    // The value itself is not used - the painter reads elapsed time - the
    // controller is just a steady 60 fps heartbeat that repaints the canvas.
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "reduce motion" setting: show a still frame.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _HelixPainter(_clock),
        size: Size.infinite,
      ),
    );
  }
}

class _Dust {
  const _Dust(this.x, this.y, this.size, this.speed, this.phase);

  final double x;
  final double y;
  final double size;
  final double speed;
  final double phase;
}

class _HelixPainter extends CustomPainter {
  _HelixPainter(this._clock) : super(repaint: _clock);

  final AnimationController _clock;

  static const int _beads = 70; // particles per strand
  static const double _turns = 2.6; // full twists along the helix
  static const int _rungEvery = 3; // a base pair every N beads

  static const Color _strandA = Color(0xFF29B6F6);
  static const Color _strandB = Color(0xFF7C4DFF);
  static const Color _rung = Color(0xFFB3E5FC);

  /// Background dust, generated once with a fixed seed so every frame (and
  /// every launch) is the same field of stars.
  static final List<_Dust> _dust = _makeDust();

  static List<_Dust> _makeDust() {
    final random = math.Random(7);
    return List.generate(90, (_) {
      return _Dust(
        random.nextDouble(),
        random.nextDouble(),
        0.6 + random.nextDouble() * 1.6,
        0.008 + random.nextDouble() * 0.02,
        random.nextDouble() * math.pi * 2,
      );
    });
  }

  final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    // Time in seconds, from the controller's monotonic clock.
    final seconds = _clock.lastElapsedDuration == null
        ? 0.0
        : _clock.lastElapsedDuration!.inMicroseconds / 1e6;

    _paintBackdrop(canvas, size);
    _paintDust(canvas, size, seconds);
    _paintHelix(canvas, size, seconds);
  }

  void _paintBackdrop(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    _paint
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF020B24), Color(0xFF031447), Color(0xFF00205F)],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, _paint);
    _paint.shader = null;

    // Soft light behind the helix.
    final glowCenter = Offset(size.width * 0.5, size.height * 0.28);
    _paint.shader = RadialGradient(
      colors: [
        const Color(0xFF0098DB).withValues(alpha: 0.28),
        Colors.transparent,
      ],
    ).createShader(
      Rect.fromCircle(center: glowCenter, radius: size.width * 0.9),
    );
    canvas.drawRect(rect, _paint);
    _paint.shader = null;
  }

  void _paintDust(Canvas canvas, Size size, double t) {
    for (final d in _dust) {
      final y = ((d.y - t * d.speed) % 1.0 + 1.0) % 1.0;
      final twinkle = 0.35 + 0.35 * math.sin(t * 1.3 + d.phase);
      _paint.color = Colors.white.withValues(alpha: twinkle.clamp(0.05, 0.7));
      canvas.drawCircle(
        Offset(d.x * size.width, y * size.height),
        d.size,
        _paint,
      );
    }
  }

  void _paintHelix(Canvas canvas, Size size, double t) {
    // The helix sits in the upper part of the screen, behind the title.
    final centerX = size.width / 2;
    final top = size.height * 0.04;
    final bottom = size.height * 0.56;
    final length = bottom - top;
    final radius = math.min(size.width * 0.30, 130.0);
    final spin = t * 0.9; // radians per second

    final front = <_Bead>[];
    final back = <_Bead>[];

    final strandA = <Offset>[];
    final strandB = <Offset>[];
    final depthA = <double>[];
    final depthB = <double>[];

    for (var i = 0; i < _beads; i++) {
      final p = i / (_beads - 1);
      final y = top + p * length;

      // Narrow the helix slightly at both ends so it fades into the page.
      final envelope = 0.45 + 0.55 * math.sin(math.pi * p);
      final angle = p * _turns * math.pi * 2 + spin;

      final xa = math.cos(angle) * radius * envelope;
      final za = math.sin(angle);
      final xb = math.cos(angle + math.pi) * radius * envelope;
      final zb = math.sin(angle + math.pi);

      strandA.add(Offset(centerX + xa, y));
      strandB.add(Offset(centerX + xb, y));
      depthA.add(za);
      depthB.add(zb);

      final fade = math.pow(math.sin(math.pi * p), 0.6).toDouble();
      (za >= 0 ? front : back)
          .add(_Bead(Offset(centerX + xa, y), za, _strandA, fade));
      (zb >= 0 ? front : back)
          .add(_Bead(Offset(centerX + xb, y), zb, _strandB, fade));
    }

    // 1) rungs (base pairs) - behind everything else
    for (var i = 0; i < _beads; i += _rungEvery) {
      final a = strandA[i];
      final b = strandB[i];
      final depth = (depthA[i] + depthB[i]) / 2; // ~0, rungs sit in the middle
      final p = i / (_beads - 1);
      final fade = math.pow(math.sin(math.pi * p), 0.6).toDouble();

      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = LinearGradient(
          colors: [
            _strandA.withValues(alpha: 0.45 * fade),
            _rung.withValues(alpha: 0.18 * fade),
            _strandB.withValues(alpha: 0.45 * fade),
          ],
        ).createShader(Rect.fromPoints(a, b).inflate(1));
      canvas.drawLine(a, b, _paint);
      _paint
        ..shader = null
        ..style = PaintingStyle.fill;

      // Three small particles on every rung give the "base pair" look.
      for (var k = 1; k <= 3; k++) {
        final point = Offset.lerp(a, b, k / 4)!;
        _paint.color = _rung.withValues(
          alpha: (0.35 + 0.15 * depth) * fade,
        );
        canvas.drawCircle(point, 1.3, _paint);
      }
    }

    // 2) far side first, then the near side, so the near beads cover them
    for (final bead in back) {
      _drawBead(canvas, bead);
    }
    for (final bead in front) {
      _drawBead(canvas, bead);
    }
  }

  /// Glowing sphere: a wide faint halo, a mid ring and a bright core.
  /// Beads near the viewer (z > 0) are bigger and brighter.
  void _drawBead(Canvas canvas, _Bead bead) {
    final depth01 = (bead.z + 1) / 2; // 0 = far, 1 = near
    final size = 2.2 + depth01 * 3.6;
    final alpha = (0.35 + 0.65 * depth01) * bead.fade;

    _paint.style = PaintingStyle.fill;
    _paint.color = bead.color.withValues(alpha: 0.10 * alpha);
    canvas.drawCircle(bead.position, size * 3.4, _paint);
    _paint.color = bead.color.withValues(alpha: 0.28 * alpha);
    canvas.drawCircle(bead.position, size * 1.8, _paint);
    _paint.color = Color.lerp(bead.color, Colors.white, 0.55)!
        .withValues(alpha: alpha);
    canvas.drawCircle(bead.position, size, _paint);
  }

  @override
  bool shouldRepaint(covariant _HelixPainter oldDelegate) =>
      oldDelegate._clock != _clock;
}

class _Bead {
  const _Bead(this.position, this.z, this.color, this.fade);

  final Offset position;
  final double z;
  final Color color;
  final double fade;
}
