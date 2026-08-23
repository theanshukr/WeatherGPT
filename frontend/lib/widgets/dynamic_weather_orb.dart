import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

enum VoiceOrbState {
  idle,
  listening,
  thinking,
  speaking,
}

class DynamicWeatherOrb extends StatefulWidget {
  final double size;
  final VoiceOrbState orbState;
  final VoidCallback? onTap;
  final Color primaryGlowColor;
  final Color secondaryGlowColor;

  const DynamicWeatherOrb({
    super.key,
    this.size = 220,
    this.orbState = VoiceOrbState.idle,
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
  late AnimationController _waveController;
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

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _updateAnimationSpeeds();
  }

  @override
  void didUpdateWidget(covariant DynamicWeatherOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.orbState != oldWidget.orbState) {
      _updateAnimationSpeeds();
    }
  }

  void _updateAnimationSpeeds() {
    switch (widget.orbState) {
      case VoiceOrbState.idle:
        _rotationController.duration = const Duration(seconds: 10);
        _pulseController.duration = const Duration(milliseconds: 2200);
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
        break;
      case VoiceOrbState.listening:
        _rotationController.duration = const Duration(seconds: 4);
        _pulseController.duration = const Duration(milliseconds: 800);
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
        break;
      case VoiceOrbState.thinking:
        _rotationController.duration = const Duration(milliseconds: 1500);
        _pulseController.duration = const Duration(milliseconds: 600);
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
        break;
      case VoiceOrbState.speaking:
        _rotationController.duration = const Duration(seconds: 3);
        _pulseController.duration = const Duration(milliseconds: 900);
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
        break;
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color activePrimary = widget.primaryGlowColor;
    Color activeSecondary = widget.secondaryGlowColor;

    if (widget.orbState == VoiceOrbState.listening) {
      activePrimary = const Color(0xFF00FFCC);
      activeSecondary = AppColors.emeraldNeon;
    } else if (widget.orbState == VoiceOrbState.thinking) {
      activePrimary = const Color(0xFF38BDF8);
      activeSecondary = const Color(0xFF818CF8);
    } else if (widget.orbState == VoiceOrbState.speaking) {
      activePrimary = const Color(0xFF34D399);
      activeSecondary = const Color(0xFF38BDF8);
    }

    final isActionActive = widget.orbState != VoiceOrbState.idle;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotationController, _pulseController, _waveController]),
        builder: (context, child) {
          final scale = _pulseAnimation.value * (isActionActive ? 1.08 : 1.0);
          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Ambient Dynamic Glow Aura
                  Container(
                    width: widget.size * 0.88,
                    height: widget.size * 0.88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: activePrimary.withValues(alpha: isActionActive ? 0.45 : 0.22),
                          blurRadius: isActionActive ? 85 : 60,
                          spreadRadius: isActionActive ? 25 : 15,
                        ),
                        BoxShadow(
                          color: activeSecondary.withValues(alpha: isActionActive ? 0.35 : 0.15),
                          blurRadius: isActionActive ? 120 : 90,
                          spreadRadius: isActionActive ? 40 : 25,
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
                      wave: _waveController.value,
                      orbState: widget.orbState,
                      primaryColor: activePrimary,
                      secondaryColor: activeSecondary,
                    ),
                  ),

                  // Center Mic / Status Icon
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.35),
                      border: Border.all(
                        color: activePrimary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      widget.orbState == VoiceOrbState.listening
                          ? Icons.mic
                          : widget.orbState == VoiceOrbState.thinking
                              ? Icons.auto_awesome
                              : widget.orbState == VoiceOrbState.speaking
                                  ? Icons.graphic_eq_rounded
                                  : Icons.mic_none_rounded,
                      color: activePrimary,
                      size: 26,
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
  final double wave;
  final VoiceOrbState orbState;
  final Color primaryColor;
  final Color secondaryColor;

  _OrbVortexPainter({
    required this.rotation,
    required this.pulse,
    required this.wave,
    required this.orbState,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.36;

    // Draw 4 overlapping swirling glowing bezier loops
    for (int i = 0; i < 4; i++) {
      final angleOffset = (i * math.pi / 2) + rotation * (i % 2 == 0 ? 1 : -0.7);
      final currentRadius = baseRadius + (math.sin(pulse * math.pi + i) * 6);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = orbState != VoiceOrbState.idle ? (3.0 + (i * 0.5)) : (1.8 + (i * 0.4))
        ..shader = SweepGradient(
          startAngle: 0.0,
          endAngle: math.pi * 2,
          colors: [
            primaryColor.withValues(alpha: 0.95),
            secondaryColor.withValues(alpha: 0.75),
            primaryColor.withValues(alpha: 0.15),
            secondaryColor.withValues(alpha: 0.95),
          ],
          transform: GradientRotation(angleOffset),
        ).createShader(Rect.fromCircle(center: center, radius: currentRadius));

      final path = Path();
      const int points = 60;
      for (int p = 0; p <= points; p++) {
        final theta = (p / points) * 2 * math.pi;
        final waveDistort = orbState == VoiceOrbState.speaking
            ? math.sin(theta * 5 + (wave * 2 * math.pi)) * 5
            : 0;
        final r = (currentRadius + waveDistort) * (1 + 0.12 * math.sin(theta * 3 + angleOffset));
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
          primaryColor.withValues(alpha: orbState != VoiceOrbState.idle ? 0.35 : 0.18),
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
        oldDelegate.wave != wave ||
        oldDelegate.orbState != orbState ||
        oldDelegate.primaryColor != primaryColor;
  }
}
