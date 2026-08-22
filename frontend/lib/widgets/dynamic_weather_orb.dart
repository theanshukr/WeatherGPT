import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class DynamicWeatherOrb extends StatefulWidget {
  final double size;
  final bool isListening;
  final VoidCallback? onTap;
  final Color primaryGlowColor;
  final Color secondaryGlowColor;

  const DynamicWeatherOrb({
    super.key,
    this.size = 240,
    this.isListening = false,
    this.onTap,
    this.primaryGlowColor = AppColors.emeraldNeon,
    this.secondaryGlowColor = AppColors.emeraldGlow,
  });

  @override
  State<DynamicWeatherOrb> createState() => _DynamicWeatherOrbState();
}

class _DynamicWeatherOrbState extends State<DynamicWeatherOrb> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void didUpdateWidget(covariant DynamicWeatherOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _pulseController.duration = const Duration(milliseconds: 900);
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.duration = const Duration(milliseconds: 2200);
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotationController, _pulseController]),
        builder: (context, child) {
          final scale = _pulseAnimation.value * (widget.isListening ? 1.12 : 1.0);
          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Ambient Glow Aura
                  Container(
                    width: widget.size * 0.9,
                    height: widget.size * 0.9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.primaryGlowColor.withValues(alpha: widget.isListening ? 0.45 : 0.28),
                          blurRadius: 75,
                          spreadRadius: 20,
                        ),
                        BoxShadow(
                          color: widget.secondaryGlowColor.withValues(alpha: widget.isListening ? 0.35 : 0.18),
                          blurRadius: 110,
                          spreadRadius: 35,
                        ),
                      ],
                    ),
                  ),
                  // Swirling Fluid Rings Canvas
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _OrbVortexPainter(
                      rotation: _rotationController.value * 2 * math.pi,
                      pulse: _pulseController.value,
                      isListening: widget.isListening,
                      primaryColor: widget.primaryGlowColor,
                      secondaryColor: widget.secondaryGlowColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrbVortexPainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final bool isListening;
  final Color primaryColor;
  final Color secondaryColor;

  _OrbVortexPainter({
    required this.rotation,
    required this.pulse,
    required this.isListening,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.38;

    // Draw 4 overlapping swirling glowing bezier loops
    for (int i = 0; i < 4; i++) {
      final angleOffset = (i * math.pi / 2) + rotation * (i % 2 == 0 ? 1 : -0.7);
      final currentRadius = baseRadius + (math.sin(pulse * math.pi + i) * 6);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isListening ? 3.5 : (2.0 + (i * 0.4))
        ..shader = SweepGradient(
          startAngle: 0.0,
          endAngle: math.pi * 2,
          colors: [
            primaryColor.withValues(alpha: 0.95),
            secondaryColor.withValues(alpha: 0.7),
            primaryColor.withValues(alpha: 0.15),
            secondaryColor.withValues(alpha: 0.95),
          ],
          transform: GradientRotation(angleOffset),
        ).createShader(Rect.fromCircle(center: center, radius: currentRadius));

      final path = Path();
      const int points = 60;
      for (int p = 0; p <= points; p++) {
        final theta = (p / points) * 2 * math.pi;
        // Elliptical distortion to create organic fluid ribbon effect
        final r = currentRadius * (1 + 0.14 * math.sin(theta * 3 + angleOffset));
        final x = center.dx + r * math.cos(theta + angleOffset);
        final y = center.dy + r * math.sin(theta + angleOffset);

        if (p == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    // Inner Core Glow
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: isListening ? 0.35 : 0.18),
          primaryColor.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 0.75));

    canvas.drawCircle(center, baseRadius * 0.75, corePaint);
  }

  @override
  bool shouldRepaint(covariant _OrbVortexPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.pulse != pulse ||
        oldDelegate.isListening != isListening ||
        oldDelegate.primaryColor != primaryColor;
  }
}
