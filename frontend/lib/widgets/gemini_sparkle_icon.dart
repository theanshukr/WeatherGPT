import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Renders the iconic Google Gemini 4-pointed sparkle / star with
/// gradient fill, glowing aura, and optional smooth rotation/pulse.
class GeminiSparkleIcon extends StatelessWidget {
  final double size;
  final bool animate;
  final Gradient gradient;

  const GeminiSparkleIcon({
    super.key,
    this.size = 24,
    this.animate = false,
    this.gradient = AppColors.geminiSparkleGradient,
  });

  @override
  Widget build(BuildContext context) {
    Widget star = ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: CustomPaint(
        size: Size(size, size),
        painter: _GeminiStarPainter(),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B72CF).withValues(alpha: 0.25),
            blurRadius: size * 0.5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: star,
    );
  }
}

class _GeminiStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // 4-pointed curved star shape (Astroid / Hypercycloid characteristic of Gemini logo)
    path.moveTo(cx, cy - r);
    path.quadraticBezierTo(cx, cy, cx + r, cy);
    path.quadraticBezierTo(cx, cy, cx, cy + r);
    path.quadraticBezierTo(cx, cy, cx - r, cy);
    path.quadraticBezierTo(cx, cy, cx, cy - r);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
