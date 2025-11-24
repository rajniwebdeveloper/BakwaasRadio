import 'dart:math' as math;
import 'package:flutter/material.dart';

class OrbitalRingPainter extends CustomPainter {
  final double tick;
  final Color color;
  final double intensity;

  const OrbitalRingPainter(
      {required this.tick, required this.color, this.intensity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 6;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    const rings = 5;
    for (int i = 0; i < rings; i++) {
      final phase = tick * 2 * math.pi + (i * 0.9);
      final amp = 0.6 + 0.4 * math.sin(phase * (1 + i * 0.2));
      paint.strokeWidth = 1.2 + i * 0.6;
      final alpha = (160 * amp * intensity).clamp(18, 220).toInt();
      paint.color = color.withAlpha(alpha);

      final segments = 60 - i * 6;
      for (int s = 0; s < segments; s++) {
        final start = (s / segments) * 2 * math.pi +
            (i * 0.12) +
            tick * 2 * math.pi * (0.4 + i * 0.2);
        final sweep = 0.06 + 0.02 * math.sin(phase + s * 0.12);
        final path = Path();
        path.addArc(Rect.fromCircle(center: center, radius: radius - i * 4),
            start, sweep);
        canvas.drawPath(path, paint);
      }
    }

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withAlpha((30 * intensity).toInt());
    canvas.drawCircle(center, radius + 6, glow);
  }

  @override
  bool shouldRepaint(covariant OrbitalRingPainter oldDelegate) {
    return oldDelegate.tick != tick ||
        oldDelegate.intensity != intensity ||
        oldDelegate.color != color;
  }
}
