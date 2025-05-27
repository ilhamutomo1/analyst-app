import 'dart:math' as math;
import 'package:flutter/material.dart';

class CenterOverlayHalfCirclePainter extends CustomPainter {
  final Color color;
  final bool
      isTop; // if true, draws the arc with its flat edge at the top (upside down)
  CenterOverlayHalfCirclePainter({required this.color, required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke // only draws the line (stroke)
      ..strokeWidth = 3.0; // adjust stroke width as needed

    // Draw arc in the given rect.
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    // For an upside down effect:
    // - If isTop is true, draw the arc starting from angle 0 (flat edge at the top).
    // - If isTop is false, draw the arc starting from math.pi (flat edge at the bottom).
    final double startAngle = isTop ? 0 : math.pi;
    canvas.drawArc(rect, startAngle, math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
