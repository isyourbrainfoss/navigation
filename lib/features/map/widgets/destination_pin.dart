import 'package:flutter/material.dart';

/// Teardrop destination marker: 2px casing, inner white disc, drop shadow.
class DestinationPin extends StatelessWidget {
  const DestinationPin({super.key, this.color = const Color(0xFFE11D48)});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 48,
      child: CustomPaint(painter: _TeardropPainter(color: color)),
    );
  }
}

class _TeardropPainter extends CustomPainter {
  _TeardropPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _teardrop(size);
    const inset = 4.0;
    final r = (size.width / 2) - inset;
    final head = Offset(size.width / 2, inset + r);

    canvas.drawShadow(path, const Color(0x88000000), 4, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(head, 6, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0B0B0C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Round head, pointed tip; inset so casing and shadow stay inside 40×48.
  static Path _teardrop(Size size) {
    const inset = 4.0;
    final cx = size.width / 2;
    final r = (size.width / 2) - inset;
    final cy = inset + r;
    final left = Offset(cx - r, cy);
    final right = Offset(cx + r, cy);
    final tip = Offset(cx, size.height - 3);
    final sideCtrlY = (cy + tip.dy) / 2;

    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(left.dx, sideCtrlY, left.dx, left.dy)
      ..arcToPoint(right, radius: Radius.circular(r), clockwise: true)
      ..quadraticBezierTo(right.dx, sideCtrlY, tip.dx, tip.dy)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _TeardropPainter oldDelegate) =>
      oldDelegate.color != color;
}
