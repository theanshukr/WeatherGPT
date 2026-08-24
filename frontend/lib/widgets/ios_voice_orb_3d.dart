import 'dart:math' as math;
import 'package:flutter/material.dart';

enum IosVoiceOrbState {
  idle,
  listening,
  thinking,
  speaking,
}

class IosVoiceOrb3D extends StatefulWidget {
  final double size;
  final IosVoiceOrbState state;
  final VoidCallback? onTap;

  const IosVoiceOrb3D({
    super.key,
    this.size = 230,
    this.state = IosVoiceOrbState.listening,
    this.onTap,
  });

  @override
  State<IosVoiceOrb3D> createState() => _IosVoiceOrb3DState();
}

class _IosVoiceOrb3DState extends State<IosVoiceOrb3D>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _wobbleController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant IosVoiceOrb3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _updateSpeed();
    }
  }

  void _updateSpeed() {
    switch (widget.state) {
      case IosVoiceOrbState.idle:
        _rotationController.duration = const Duration(seconds: 12);
        _pulseController.duration = const Duration(milliseconds: 2400);
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
        break;
      case IosVoiceOrbState.listening:
        _rotationController.duration = const Duration(seconds: 5);
        _pulseController.duration = const Duration(milliseconds: 1400);
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
        break;
      case IosVoiceOrbState.thinking:
        _rotationController.duration = const Duration(milliseconds: 1800);
        _pulseController.duration = const Duration(milliseconds: 800);
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
        break;
      case IosVoiceOrbState.speaking:
        _rotationController.duration = const Duration(seconds: 3);
        _pulseController.duration = const Duration(milliseconds: 1100);
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
        break;
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _wobbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _rotationController,
          _pulseController,
          _wobbleController,
        ]),
        builder: (context, child) {
          final pulse = _pulseController.value;
          final wobble = _wobbleController.value;
          final rot = _rotationController.value * 2 * math.pi;
          final scale = 0.95 + (pulse * 0.1);

          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Ambient Soft Glow
                  Container(
                    width: widget.size * 0.85,
                    height: widget.size * 0.85,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF936DFF).withValues(alpha: 0.35),
                          blurRadius: 70,
                          spreadRadius: 20,
                        ),
                        BoxShadow(
                          color: const Color(0xFFE879F9).withValues(alpha: 0.25),
                          blurRadius: 90,
                          spreadRadius: 30,
                        ),
                        BoxShadow(
                          color: const Color(0xFF60A5FA).withValues(alpha: 0.18),
                          blurRadius: 100,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),

                  // Custom Painter for Layered 3D Petals
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _LayeredPetalOrbPainter(
                      rotation: rot,
                      pulse: pulse,
                      wobble: wobble,
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

class _LayeredPetalOrbPainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final double wobble;

  _LayeredPetalOrbPainter({
    required this.rotation,
    required this.pulse,
    required this.wobble,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.44;

    // Palette of the 3D translucent layers matching reference
    final layers = [
      {
        'color1': const Color(0xFF7C3AED), // Deep violet
        'color2': const Color(0xFFC084FC), // Lavender
        'alpha': 0.70,
        'tilt': 0.0,
        'speed': 1.0,
        'eccentricity': 1.15,
      },
      {
        'color1': const Color(0xFFEC4899), // Hot pink/magenta
        'color2': const Color(0xFFF472B6), // Soft rose
        'alpha': 0.65,
        'tilt': math.pi / 3,
        'speed': -0.85,
        'eccentricity': 1.25,
      },
      {
        'color1': const Color(0xFF6366F1), // Indigo
        'color2': const Color(0xFFA855F7), // Purple
        'alpha': 0.60,
        'tilt': 2 * math.pi / 3,
        'speed': 0.65,
        'eccentricity': 1.18,
      },
      {
        'color1': const Color(0xFF8B5CF6), // Violet core
        'color2': const Color(0xFFE879F9), // Fuchsia
        'alpha': 0.75,
        'tilt': math.pi / 4,
        'speed': -1.1,
        'eccentricity': 1.1,
      },
      {
        'color1': const Color(0xFF38BDF8), // Cyan edge tint
        'color2': const Color(0xFFA78BFA), // Pastel lilac
        'alpha': 0.50,
        'tilt': 5 * math.pi / 6,
        'speed': 0.9,
        'eccentricity': 1.3,
      },
    ];

    // Draw spherical backdrop mask
    final sphereRect = Rect.fromCircle(center: center, radius: radius);
    canvas.save();
    final clipPath = Path()..addOval(sphereRect);
    canvas.clipPath(clipPath);

    // Deep base ambient fill
    final baseGradient = RadialGradient(
      center: Alignment(math.sin(wobble * math.pi) * 0.2, -0.2),
      radius: 0.9,
      colors: [
        const Color(0xFFDDD6FE).withValues(alpha: 0.9),
        const Color(0xFFC4B5FD).withValues(alpha: 0.7),
        const Color(0xFF818CF8).withValues(alpha: 0.4),
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 0.8, 1.0],
    );
    final basePaint = Paint()..shader = baseGradient.createShader(sphereRect);
    canvas.drawCircle(center, radius, basePaint);

    // Draw overlapping translucent rotating elliptical petals
    for (int i = 0; i < layers.length; i++) {
      final layer = layers[i];
      final color1 = (layer['color1'] as Color).withValues(alpha: layer['alpha'] as double);
      final color2 = (layer['color2'] as Color).withValues(alpha: (layer['alpha'] as double) * 0.6);
      final tilt = layer['tilt'] as double;
      final speed = layer['speed'] as double;
      final ecc = layer['eccentricity'] as double;

      final currentAngle = tilt + (rotation * speed);
      final rx = radius * 0.92 * (1.0 + (pulse * 0.05 * (i % 2 == 0 ? 1 : -1)));
      final ry = rx / ecc;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(currentAngle);

      final petalRect = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
      final petalGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color1, color2, Colors.white.withValues(alpha: 0.15)],
        stops: const [0.0, 0.7, 1.0],
      );

      final petalPaint = Paint()
        ..shader = petalGradient.createShader(petalRect)
        ..blendMode = BlendMode.screen;

      canvas.drawOval(petalRect, petalPaint);

      // Add a fine bright rim highlight
      final rimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.8),
            color1.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ).createShader(petalRect);

      canvas.drawOval(petalRect, rimPaint);
      canvas.restore();
    }

    // Top-left soft specular glass reflection highlight
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.45),
        radius: 0.55,
        colors: [
          Colors.white.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(sphereRect)
      ..blendMode = BlendMode.screen;

    canvas.drawCircle(center, radius, highlightPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LayeredPetalOrbPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.pulse != pulse ||
        oldDelegate.wobble != wobble;
  }
}
