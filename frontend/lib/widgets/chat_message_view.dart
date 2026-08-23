import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../core/theme/app_colors.dart';
import '../providers/voice_provider.dart';
import 'package:intl/intl.dart';

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
  bool _autoSpokenForThisMessage = false;

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _maybeAutoSpeak(BuildContext context) {
    if (_autoSpokenForThisMessage) return;
    if (widget.message.role != MessageRole.assistant) return;
    if (widget.message.isStreaming) return;
    if (widget.message.content.trim().isEmpty) return;

    final voiceProvider = context.read<VoiceProvider>();
    if (!voiceProvider.autoSpeechEnabled) return;

    _autoSpokenForThisMessage = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      voiceProvider.speakMessage(widget.message.id, widget.message.content);
    });
  }

  @override
  Widget build(BuildContext context) {
    _maybeAutoSpeak(context);
    final isUser = widget.message.role == MessageRole.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(48, 6, 16, 6),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.emeraldDark.withValues(alpha: 0.35)
                  : AppColors.emeraldDark,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
              border: Border.all(
                color: isDark
                    ? AppColors.emeraldNeon.withValues(alpha: 0.4)
                    : Colors.transparent,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              widget.message.content,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                height: 1.45,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      );
    }

    // Assistant Message
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFF00FF87),
                  Color(0xFF059669),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emeraldNeon.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'WeatherGPT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('hh:mm a').format(widget.message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      ),
                    ),
                    if (widget.message.personaApplied != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.message.personaApplied!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.emeraldGlow : AppColors.emeraldDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // Tool Execution Chips (Tool transparency)
                if (widget.message.toolsCalled.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: widget.message.toolsCalled.map((tool) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt, size: 11, color: AppColors.sunnyGold),
                            const SizedBox(width: 3),
                            Text(
                              tool,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],

                // Main card content
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.message.content,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          height: 1.55,
                          letterSpacing: -0.1,
                        ),
                      ),

                      // Render Structured Advisory Card (Farming, Travel, Urban)
                      if (widget.message.advisory != null)
                        _buildAdvisoryCard(widget.message.advisory!, isDark),

                      // Render Weather Data Card Snapshot if returned
                      if (widget.message.weatherContext != null)
                        _buildWeatherContextCard(widget.message.weatherContext!, isDark),

                      const SizedBox(height: 12),

                      // Action Bar: Copy & Speak buttons
                      Consumer<VoiceProvider>(
                        builder: (context, voiceProvider, _) {
                          final speaking = voiceProvider.isSpeaking(widget.message.id);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (speaking) {
                                    voiceProvider.stop();
                                  } else {
                                    voiceProvider.speakMessage(
                                      widget.message.id,
                                      widget.message.content,
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: speaking
                                        ? (isDark
                                            ? AppColors.emeraldNeon.withValues(alpha: 0.15)
                                            : AppColors.emeraldDark.withValues(alpha: 0.1))
                                        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        speaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                                        size: 13,
                                        color: speaking
                                            ? (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                                            : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        speaking ? 'Stop' : 'Speak',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: speaking
                                              ? (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                                              : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _copyToClipboard(widget.message.content),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                                        size: 13,
                                        color: _copied
                                            ? (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                                            : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _copied ? 'Copied' : 'Copy',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: _copied
                                              ? (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                                              : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Suggested Prompt Action Chips
                if (widget.message.suggestedActions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.message.suggestedActions.map((action) {
                      return GestureDetector(
                        onTap: () {
                          if (widget.onActionSelected != null) {
                            widget.onActionSelected!(action.query);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.emeraldNeon.withValues(alpha: 0.08)
                                : AppColors.emeraldDark.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.emeraldNeon.withValues(alpha: 0.25)
                                  : AppColors.emeraldDark.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_outlined,
                                size: 13,
                                color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                action.title,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisoryCard(AdvisoryData adv, bool isDark) {
    final isDanger = adv.riskLevel.toUpperCase().contains('HIGH') ||
        adv.riskLevel.toUpperCase().contains('SEVERE') ||
        adv.verdict.toUpperCase().contains('AVOID') ||
        adv.verdict.toUpperCase().contains('DELAY');

    final color = isDanger ? AppColors.alertCrimson : AppColors.emeraldNeon;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                adv.headline,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  adv.riskLevel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? color : (isDanger ? AppColors.alertCrimson : AppColors.emeraldDark),
                  ),
                ),
              ),
            ],
          ),
          if (adv.verdict.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              adv.verdict,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
          if (adv.reasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...adv.reasons.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Text(
                          r,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          if (adv.actionableSteps.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Actionable Steps:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            ...adv.actionableSteps.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✓ ', style: TextStyle(fontSize: 11, color: AppColors.emeraldNeon)),
                      Expanded(
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildWeatherContextCard(Map<String, dynamic> data, bool isDark) {
    final temp = data['temperature']?.toString() ?? '--';
    final cond = data['condition']?.toString() ?? 'Weather Fact';
    final loc = data['location']?.toString() ?? 'Target Area';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_outlined, size: 16, color: AppColors.emeraldNeon),
              const SizedBox(width: 6),
              Text(
                '$loc: $cond',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Text(
            '$temp°C',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
