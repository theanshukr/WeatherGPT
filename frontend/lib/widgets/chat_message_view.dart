import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../core/theme/app_colors.dart';
import '../providers/voice_provider.dart';
import 'gemini_sparkle_icon.dart';

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
  // User Message Bubble (Gemini Charcoal / Soft Cloud Pill)
  // ---------------------------------------------------------------------------
  Widget _buildUserMessage(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 6, 16, 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
            border: Border.all(
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              width: 1,
            ),
          ),
          child: Text(
            widget.message.content,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Gemini Assistant Message (Gemini Sparkle + Markdown + Tool Badges)
  // ---------------------------------------------------------------------------
  Widget _buildAssistantMessage(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gemini Brand Header
          Row(
            children: [
              const GeminiSparkleIcon(size: 20),
              const SizedBox(width: 8),
              Text(
                'WeatherGPT',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(width: 6),
              if (widget.message.personaApplied != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1F20) : const Color(0xFFE8EEF7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.message.personaApplied!.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.geminiBlue,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Tools Grounding Chip (e.g. Checked Open-Meteo Radar)
          if (widget.message.toolsCalled.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1F20) : const Color(0xFFF0F4F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 13,
                      color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Grounded with ${_formatToolNames(widget.message.toolsCalled)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Main Response Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              widget.message.content,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                height: 1.55,
              ),
            ),
          ),

          // Structured Weather Advisory Card (Travel, Farming, Urban)
          if (widget.message.advisory != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildAdvisoryCard(widget.message.advisory!, isDark),
            ),

          // Weather Snapshot Card
          if (widget.message.weatherContext != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildWeatherContextCard(widget.message.weatherContext!, isDark),
            ),

          // Suggested Action Chips
          if (widget.message.suggestedActions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.message.suggestedActions.map((action) {
                  return GestureDetector(
                    onTap: () => widget.onActionSelected?.call(action.query),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
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

          const SizedBox(height: 10),

          // Gemini Action Bar: Speak, Copy, Like, Dislike, Regenerate
          Consumer<VoiceProvider>(
            builder: (context, voiceProvider, _) {
              final speaking = voiceProvider.isSpeaking(widget.message.id);
              return Row(
                children: [
                  // Speak Action Button (Sarvam Natural Voice)
                  _buildActionButton(
                    icon: speaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                    label: speaking ? 'Stop' : 'Listen',
                    active: speaking,
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
                    isDark: isDark,
                  ),

                  const SizedBox(width: 8),

                  // Copy to Clipboard
                  _buildActionButton(
                    icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                    label: _copied ? 'Copied' : 'Copy',
                    active: _copied,
                    onTap: () => _copyToClipboard(widget.message.content),
                    isDark: isDark,
                  ),

                  const SizedBox(width: 8),

                  // Like Button
                  _buildIconButton(
                    icon: _feedbackLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                    active: _feedbackLiked,
                    onTap: () {
                      setState(() {
                        _feedbackLiked = !_feedbackLiked;
                        _feedbackDisliked = false;
                      });
                    },
                    isDark: isDark,
                  ),

                  const SizedBox(width: 4),

                  // Dislike Button
                  _buildIconButton(
                    icon: _feedbackDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                    active: _feedbackDisliked,
                    onTap: () {
                      setState(() {
                        _feedbackDisliked = !_feedbackDisliked;
                        _feedbackLiked = false;
                      });
                    },
                    isDark: isDark,
                  ),

                  if (widget.onRegenerate != null) ...[
                    const Spacer(),
                    _buildIconButton(
                      icon: Icons.refresh_rounded,
                      active: false,
                      onTap: widget.onRegenerate!,
                      isDark: isDark,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? AppColors.geminiBlue.withValues(alpha: 0.18) : AppColors.geminiBlue.withValues(alpha: 0.12))
              : (isDark ? const Color(0xFF1E1F20) : const Color(0xFFF0F4F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? AppColors.geminiBlue.withValues(alpha: 0.4)
                : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? AppColors.geminiBlue : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.geminiBlue : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        size: 15,
        color: active ? AppColors.geminiBlue : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
      ),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  String _formatToolNames(List<String> tools) {
    if (tools.contains('get_rain_timeline')) return 'Rain Timeline Engine';
    if (tools.contains('evaluate_farming_conditions')) return 'Agrometeorological Tools';
    if (tools.contains('evaluate_travel_conditions')) return 'Highway Safety Radar';
    if (tools.contains('evaluate_climate_trend')) return 'Historical Climate Data';
    if (tools.contains('get_official_disaster_alerts')) return 'NDMA SACHET CAP Alerts';
    return 'Open-Meteo & NWP Radar';
  }

  Widget _buildAdvisoryCard(AdvisoryData advisory, bool isDark) {
    Color badgeColor = AppColors.emeraldNeon;
    if (advisory.riskLevel == 'HIGH' || advisory.riskLevel == 'SEVERE' || advisory.riskLevel == 'AVOID_SPRAYING') {
      badgeColor = AppColors.alertCrimson;
    } else if (advisory.riskLevel == 'MODERATE' || advisory.riskLevel == 'DELAY_IRRIGATION') {
      badgeColor = AppColors.sunnyGold;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                advisory.headline,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  advisory.riskLevel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          if (advisory.verdict.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              advisory.verdict,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeatherContextCard(Map<String, dynamic> weather, bool isDark) {
    final temp = weather['temperature']?.toString() ?? '--';
    final condition = weather['condition']?.toString() ?? 'Current Condition';
    final loc = weather['location']?.toString() ?? 'Location';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined, size: 20, color: AppColors.sunnyGold),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    condition,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            '$temp°C',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
