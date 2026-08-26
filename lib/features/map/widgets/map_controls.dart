import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'glass.dart';

class RoundMapButton extends StatelessWidget {
  const RoundMapButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.highlighted = false,
    this.foreground,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool highlighted;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Glass(
        borderRadius: 28,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              icon,
              color: foreground ??
                  (highlighted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

class CompassRose extends StatelessWidget {
  const CompassRose({
    super.key,
    required this.rotationDegrees,
    required this.onNorthUp,
  });

  final double rotationDegrees;
  final VoidCallback onNorthUp;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'North up',
      child: Glass(
        borderRadius: 28,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onNorthUp,
          child: SizedBox(
            width: 56,
            height: 56,
            child: AnimatedRotation(
              turns: rotationDegrees / 360.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: CustomPaint(painter: _RosePainter()),
            ),
          ),
        ),
      ),
    );
  }
}

class _RosePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final n = Path()
      ..moveTo(c.dx, 8)
      ..lineTo(c.dx + 6, c.dy)
      ..lineTo(c.dx, c.dy - 2)
      ..close();
    final s = Path()
      ..moveTo(c.dx, size.height - 8)
      ..lineTo(c.dx - 6, c.dy)
      ..lineTo(c.dx, c.dy + 2)
      ..close();
    canvas.drawPath(n, Paint()..color = const Color(0xFFE11D48));
    canvas.drawPath(s, Paint()..color = const Color(0xFF64748B));
    final tp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Color(0xFFE11D48),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, 9));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ZoomControls extends StatelessWidget {
  const ZoomControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Glass(
      borderRadius: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom in',
            onPressed: onZoomIn,
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 36, child: Divider(height: 1)),
          IconButton(
            tooltip: 'Zoom out',
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}

class RouteChevron extends StatelessWidget {
  const RouteChevron({super.key, required this.bearing, required this.color});

  final double bearing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: bearing * math.pi / 180.0,
      child: Icon(Icons.navigation, size: 16, color: color),
    );
  }
}
