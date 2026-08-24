import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'svg_icon.dart';
import 'bouncing_button.dart';

class IosAudioPlayerBubble extends StatefulWidget {
  final VoidCallback? onPlayToggle;
  final bool isPlaying;

  const IosAudioPlayerBubble({
    super.key,
    this.onPlayToggle,
    this.isPlaying = false,
  });

  @override
  State<IosAudioPlayerBubble> createState() => _IosAudioPlayerBubbleState();
}

class _IosAudioPlayerBubbleState extends State<IosAudioPlayerBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _playing = false;

  final List<double> _barHeights = [
    0.35, 0.6, 0.4, 0.8, 0.55, 0.9, 0.7, 0.45, 0.95, 0.65,
    0.3, 0.75, 0.85, 0.5, 0.65, 0.9, 0.4, 0.7, 0.55, 0.35,
    0.6, 0.8, 0.45, 0.9, 0.75, 0.5, 0.3, 0.65, 0.85, 0.4,
  ];

  @override
  void initState() {
    super.initState();
    _playing = widget.isPlaying;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant IosAudioPlayerBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      setState(() => _playing = widget.isPlaying);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111113),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play / Pause pill button
          IosBouncingButton(
            onTap: () {
              setState(() => _playing = !_playing);
              widget.onPlayToggle?.call();
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              child: Center(
                child: IosSvgIcon(
                  _playing ? 'pause' : 'play',
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Animated Waveform Bars
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(_barHeights.length, (index) {
                  final baseH = _barHeights[index];
                  final animatedH = _playing
                      ? (baseH + (math.sin(_animController.value * 2 * math.pi + index * 0.4) * 0.25)).clamp(0.2, 1.0)
                      : baseH;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 2.5,
                    height: 24 * animatedH,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: index < 12 ? 0.95 : 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
