import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Google-style puck: heading cone, pulsing accuracy, white-cased chevron.
class UserPuck extends StatefulWidget {
  const UserPuck({
    super.key,
    this.headingDegrees,
    this.accuracyMeters,
    this.courseUp = false,
    this.navigating = false,
  });

  final double? headingDegrees;
  final double? accuracyMeters;
  final bool courseUp;
  final bool navigating;

  @override
  State<UserPuck> createState() => _UserPuckState();
}

class _UserPuckState extends State<UserPuck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = widget.headingDegrees;
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.navigating)
                CustomPaint(
                  size: const Size(72, 72),
                  painter: _ConePainter(
                    color: color.withValues(alpha: 0.22),
                  ),
                ),
              Opacity(
                opacity: (1 - t) * 0.45,
                child: Transform.scale(
                  scale: 0.7 + t * 0.9,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
              Transform.rotate(
                angle: heading == null ? 0 : heading * math.pi / 180.0,
                child: CustomPaint(
                  size: const Size(40, 40),
                  painter: _ChevronPainter(color: color),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConePainter extends CustomPainter {
  _ConePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final path = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx - 22, 4)
      ..quadraticBezierTo(cx, -6, cx + 22, 4)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ConePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final path = Path()
      ..moveTo(cx, 1)
      ..lineTo(size.width - 5, size.height - 3)
      ..lineTo(cx, size.height - 11)
      ..lineTo(5, size.height - 3)
      ..close();
    canvas.drawShadow(path, const Color(0x88000000), 4, false);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0B0B0C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withValues(alpha: 0.85)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter oldDelegate) =>
      oldDelegate.color != color;
}
