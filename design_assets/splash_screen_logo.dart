import 'package:flutter/material.dart';

class ModernLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Background Frame
    final basePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1A1E23), Color(0xFF0A0C0E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.05, h * 0.05, w * 0.9, h * 0.9), const Radius.circular(24)),
      basePaint,
    );

    // 2. Logic Grid
    final gridPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00FFC2), Color(0xFF00D2FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    const double sqSize = 0.38;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.12, w * sqSize, h * sqSize), const Radius.circular(8)), gridPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.58, h * 0.12, w * sqSize, h * sqSize), const Radius.circular(8)), gridPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.58, w * sqSize, h * sqSize), const Radius.circular(8)), gridPaint);

    // 3. Active Node (Vibrant)
    final activePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.white, Color(0xFF00FFC2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.58, h * 0.58, w * sqSize, h * sqSize), const Radius.circular(8)), activePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
