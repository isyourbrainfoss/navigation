import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/geometry.dart';
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

/// Map compass. The needle points at true north on screen.
///
/// [mapRotationDegrees] is `MapCamera.rotation`: flutter_map rotates the map
/// clockwise by that many degrees, so north sits at that angle clockwise from
/// "up". Course-up driving east uses rotation -90, and the needle points
/// left. The rotation is already eased by the camera, so the needle follows
/// it directly; animating it again (the old `AnimatedRotation` on raw turns)
/// spun the needle a full circle whenever the angle wrapped at 0/360.
class CompassRose extends StatelessWidget {
  const CompassRose({
    super.key,
    required this.mapRotationDegrees,
    required this.onNorthUp,
  });

  final double mapRotationDegrees;
  final VoidCallback onNorthUp;

  /// Screen angle (radians, clockwise from up) the needle is drawn at.
  static double needleAngleRadians(double mapRotationDegrees) =>
      GeoMath.normalizeSignedDegrees(mapRotationDegrees) * math.pi / 180.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Compass. Tap to turn the map north up.',
      child: Tooltip(
        message: 'Compass: tap for north up',
        child: Glass(
          borderRadius: 28,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onNorthUp,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Transform.rotate(
                key: const ValueKey('compass-needle'),
                angle: needleAngleRadians(mapRotationDegrees),
                child: CustomPaint(
                  painter: _RosePainter(
                    south: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RosePainter extends CustomPainter {
  _RosePainter({required this.south});

  final Color south;

  static const _north = Color(0xFFE11D48);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const halfWidth = 5.5;
    // "N" sits above the needle tip so it never overlaps the red half.
    final tp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: _north,
          fontSize: 14,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, 3));
    final tipN = Offset(c.dx, 3 + tp.height + 2);
    final tipS = Offset(c.dx, size.height - 10);
    final northHalf = Path()
      ..moveTo(tipN.dx, tipN.dy)
      ..lineTo(c.dx + halfWidth, c.dy)
      ..lineTo(c.dx - halfWidth, c.dy)
      ..close();
    final southHalf = Path()
      ..moveTo(tipS.dx, tipS.dy)
      ..lineTo(c.dx - halfWidth, c.dy)
      ..lineTo(c.dx + halfWidth, c.dy)
      ..close();
    canvas.drawPath(southHalf, Paint()..color = south.withValues(alpha: 0.75));
    canvas.drawPath(northHalf, Paint()..color = _north);
    canvas.drawCircle(c, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RosePainter oldDelegate) =>
      oldDelegate.south != south;
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

/// Small caption under a map button ("Course up", "North up", "Free").
class MapModeLabel extends StatelessWidget {
  const MapModeLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Glass(
      borderRadius: 10,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          key: const Key('map_mode_label'),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
