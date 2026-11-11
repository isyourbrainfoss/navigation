import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Google-style location puck: pulsing dot, plus a heading chevron and view
/// cone when the direction of travel is known.
///
/// [headingDegrees] is a true bearing (0 = north, clockwise). The puck is a
/// flutter_map [Marker] without `rotate: true`, so it lives in the map's own
/// rotated frame: drawing it at the true bearing points it the right way on
/// screen in both north-up and course-up. (Course-up used to pass 0 here,
/// which pointed the chevron at north instead of the direction of travel.)
/// With no heading (standing still, no compass) a plain dot is drawn rather
/// than a chevron pointing at an arbitrary direction.
class UserPuck extends StatefulWidget {
  const UserPuck({
    super.key,
    this.headingDegrees,
    this.accuracyMeters,
    this.navigating = false,
    this.stale = false,
  });

  final double? headingDegrees;
  final double? accuracyMeters;
  final bool navigating;

  /// The last fix is old: draw the puck grey so it is not mistaken for live.
  final bool stale;

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
    final color = widget.stale
        ? const Color(0xFF94A3B8)
        : Theme.of(context).colorScheme.primary;
    final angle = heading == null ? 0.0 : heading * math.pi / 180.0;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = widget.stale ? 0.0 : _pulse.value;
        return SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (heading != null)
                Transform.rotate(
                  angle: angle,
                  child: CustomPaint(
                    size: const Size(72, 72),
                    painter: _ConePainter(
                      color: color.withValues(
                        alpha: widget.navigating ? 0.24 : 0.16,
                      ),
                    ),
                  ),
                ),
              if (!widget.stale)
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
              if (heading != null)
                Transform.rotate(
                  key: const ValueKey('puck-chevron'),
                  angle: angle,
                  child: CustomPaint(
                    size: const Size(40, 40),
                    painter: _ChevronPainter(color: color),
                  ),
                )
              else
                Container(
                  key: const ValueKey('puck-dot'),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x66000000), blurRadius: 4),
                    ],
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
