import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../core/theme/app_colors.dart';
import '../providers/voice_provider.dart';
import 'ios_svg_icon.dart';
import 'ios_bouncing_button.dart';
import 'ios_audio_player_bubble.dart';

class ChatMessageView extends StatefulWidget {
  final ChatMessage message;
  final Function(String query)? onActionSelected;
  final VoidCallback? onRegenerate;

  const ChatMessageView({
    super.key,
    required this.message,
    this.onActionSelected,
    this.onRegenerate,
  });

  @override
  State<ChatMessageView> createState() => _ChatMessageViewState();
}

class _ChatMessageViewState extends State<ChatMessageView> {
  bool _copied = false;
  bool _feedbackLiked = false;
  bool _feedbackDisliked = false;

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == MessageRole.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isUser) {
      return _buildUserMessage(isDark);
    } else {
      return _buildAssistantMessage(isDark);
    }
  }

  // ---------------------------------------------------------------------------
  // User Message Bubble (iOS Clean Dark Pill or Frosted Card)
  // ---------------------------------------------------------------------------
  Widget _buildUserMessage(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 6, 16, 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF24242C) : const Color(0xFFF1EEF8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              width: 1,
            ),
          ),
          child: Text(
            widget.message.content,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
              color: isDark ? AppColors.darkTextPrimary : AppColors.iosBlack,
              height: 1.4,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  // ---------------------------------------------------------------------------
  // Assistant Message matching Screen 3 (Mini Orb Avatar + Speech Bubble + Feedback)
  // ---------------------------------------------------------------------------
  Widget _buildAssistantMessage(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with mini glowing orb avatar and message bubble
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mini Glowing 3D Orb Avatar matching Screen 3
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF7C3AED),
                      Color(0xFFEC4899),
                      Color(0xFF38BDF8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Main Message Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Text Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.message.content,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          height: 1.45,
                        ),
                      ),
                    ),

                    // Audio Waveform Voice Bubble if voice reply active
                    Consumer<VoiceProvider>(
                      builder: (context, voiceProvider, _) {
                        final isSpeaking = voiceProvider.isSpeaking(widget.message.id);
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: IosAudioPlayerBubble(
                            isPlaying: isSpeaking,
                            onPlayToggle: () {
                              if (isSpeaking) {
                                voiceProvider.stop();
                              } else {
                                voiceProvider.speakMessage(
                                  widget.message.id,
                                  widget.message.content,
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),

                    // Structured Advisory Card (if present)
                    if (widget.message.advisory != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _buildAdvisoryCard(widget.message.advisory!, isDark),
                      ),

                    // Suggested Action Chips
                    if (widget.message.suggestedActions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.message.suggestedActions.map((action) {
                            return IosBouncingButton(
                              onTap: () => widget.onActionSelected?.call(action.query),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                  ),
                                ),
                                child: Text(
                                  action.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Feedback and Action Bar matching Screen 3
                    Row(
                      children: [
                        // Regenerate Button
                        if (widget.onRegenerate != null) ...[
                          IosBouncingButton(
                            onTap: widget.onRegenerate,
                            child: Row(
                              children: [
                                const IosSvgIcon(
                                  'refresh',
                                  size: 14,
                                  color: Color(0xFF71717A),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Regenerate',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF71717A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],

                        // Thumbs Up
                        IosBouncingButton(
                          onTap: () {
                            setState(() {
                              _feedbackLiked = !_feedbackLiked;
                              _feedbackDisliked = false;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: IosSvgIcon(
                              'thumbs_up',
                              size: 15,
                              color: _feedbackLiked
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Thumbs Down
                        IosBouncingButton(
                          onTap: () {
                            setState(() {
                              _feedbackDisliked = !_feedbackDisliked;
                              _feedbackLiked = false;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: IosSvgIcon(
                              'thumbs_down',
                              size: 15,
                              color: _feedbackDisliked
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Copy Button
                        IosBouncingButton(
                          onTap: () => _copyToClipboard(widget.message.content),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              _copied ? 'Copied' : 'Copy',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildAdvisoryCard(AdvisoryData advisory, bool isDark) {
    final title = advisory.headline.isNotEmpty ? advisory.headline : 'Intelligence Advisory';
    final items = advisory.reasons.isNotEmpty ? advisory.reasons : advisory.actionableSteps;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : const Color(0xFFFAF7FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFDDD6FE),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IosSvgIcon(
                'sparkles',
                size: 15,
                color: Color(0xFF7C3AED),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF5B21B6),
                  ),
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xFF7C3AED))),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
