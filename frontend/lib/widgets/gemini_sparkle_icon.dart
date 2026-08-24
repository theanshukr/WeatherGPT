import 'package:flutter/material.dart';
import 'ios_svg_icon.dart';

class IosSparkleIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final bool animate;

  const IosSparkleIcon({
    super.key,
    this.size = 22,
    this.color = const Color(0xFF7C3AED),
    this.animate = false,
    Gradient? gradient,
  });

  @override
  Widget build(BuildContext context) {
    return IosSvgIcon(
      'sparkles',
      size: size,
      color: color,
    );
  }
}

// Backward-compatible alias
typedef GeminiSparkleIcon = IosSparkleIcon;
