import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class IosSvgIcon extends StatelessWidget {
  final String name;
  final double? size;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit fit;

  const IosSvgIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.width,
    this.height,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size;
    final effectiveHeight = height ?? size;
    final assetPath = name.endsWith('.svg') ? 'assets/icons/$name' : 'assets/icons/$name.svg';

    return SvgPicture.asset(
      assetPath,
      width: effectiveWidth,
      height: effectiveHeight,
      fit: fit,
      colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
    );
  }
}
