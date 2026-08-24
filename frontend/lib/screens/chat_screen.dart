import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/user_context_provider.dart';
import '../widgets/chat_message_view.dart';
import '../widgets/ios_svg_icon.dart';
import '../widgets/ios_bouncing_button.dart';
import 'gemini_live_screen.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? initialQuery;

  const ChatScreen({super.key, this.initialQuery});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasInputText = false;

  final List<Map<String, dynamic>> _starterPrompts = [
    {
      'icon': 'surprise',
      'title': 'Crop & Spray Advice',
      'query': 'Is the weather suitable for pesticide spraying on crops today?',
    },
    {
      'icon': 'cloud_rain',
      'title': 'Rain Timeline',
      'query': 'What is the exact rain probability and timeline for the next 6 hours?',
    },
    {
      'icon': 'lightning',
      'title': 'Travel Safety Risk',
      'query': 'Evaluate driving conditions, road visibility and storm risk for travel.',
    },
    {
      'icon': 'bell',
      'title': 'Severe Alerts Status',
      'query': 'Are there any official NDMA SACHET or extreme weather alerts active?',
    },
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasInputText) {
        setState(() => _hasInputText = hasText);
      }
    });

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSendMessage(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSendMessage(String text) {
    final queryText = text.trim();
    if (queryText.isEmpty) return;

    final weatherProv = context.read<WeatherProvider>();
    final contextProv = context.read<UserContextProvider>();

    context.read<ChatProvider>().sendUserMessage(
          queryText,
          lat: weatherProv.weatherData.location.latitude,
          lon: weatherProv.weatherData.location.longitude,
          locationName: weatherProv.weatherData.location.name,
          activePersona: contextProv.currentPersona.name,
        );

    _textController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _openGeminiLive() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GeminiLiveScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProv = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Center(
            child: IosBouncingButton(
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  _showChatOptionsSheet(context, isDark);
                }
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Center(
                  child: Navigator.canPop(context)
                      ? Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        )
                      : IosSvgIcon(
                          'menu',
                          size: 16,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'Speaking to LIX',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.iosBlack,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: IosBouncingButton(
                onTap: _openGeminiLive,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                    ),
                  ),
                  child: const Center(
                    child: IosSvgIcon(
                      'sparkles',
                      size: 18,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat Message Thread or Starter Prompts
            Expanded(
              child: chatProv.messages.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: chatProv.messages.length + (chatProv.isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == chatProv.messages.length) {
                          return _buildTypingIndicator(isDark);
                        }

                        final msg = chatProv.messages[index];
                        return ChatMessageView(
                          message: msg,
                          onActionSelected: (query) => _handleSendMessage(query),
                          onRegenerate: msg.role == MessageRole.assistant &&
                                  index == chatProv.messages.length - 1
                              ? () {
                                  // Find the preceding user message to resend
                                  for (int i = index - 1; i >= 0; i--) {
                                    if (chatProv.messages[i].role == MessageRole.user) {
                                      _handleSendMessage(chatProv.messages[i].content);
                                      break;
                                    }
                                  }
                                }
                              : null,
                        );
                      },
                    ),
            ),

            // Bottom Input Dock matching Screen 3 (+ Message... mic send)
            _buildBottomInputDock(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 30),
          // Glowing Orb Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFEC4899), Color(0xFF38BDF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

          const SizedBox(height: 18),

          Text(
            'How can I help you today?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.iosBlack,
              letterSpacing: -0.4,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

          const SizedBox(height: 6),

          Text(
            'Ask about hyper-local forecasts, farming schedules, or live radars.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? AppColors.darkTextTertiary : const Color(0xFF71717A),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 150.ms),

          const SizedBox(height: 28),

          // Starter Prompts
          ...List.generate(_starterPrompts.length, (index) {
            final prompt = _starterPrompts[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: IosBouncingButton(
                onTap: () => _handleSendMessage(prompt['query'] as String),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IosSvgIcon(
                        prompt['icon'] as String,
                        size: 20,
                        color: const Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          prompt['title'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.iosBlack,
                          ),
                        ),
                      ),
                      const IosSvgIcon(
                        'arrow_right',
                        size: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 350.ms, delay: (200 + index * 50).ms).slideY(begin: 0.1, end: 0);
          }),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF7C3AED),
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
     .scaleXY(begin: 0.5, end: 1.2, duration: 400.ms, delay: (index * 150).ms);
  }

  Widget _buildBottomInputDock(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkCardBorder : const Color(0xFFEBE6F5),
            width: 0.8,
          ),
        ),
      ),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 4),

            // Text Input Field
            Expanded(
              child: TextField(
                controller: _textController,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextTertiary : const Color(0xFFA1A1AA),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onSubmitted: (text) => _handleSendMessage(text),
              ),
            ),

            // Mic Shortcut Button
            IosBouncingButton(
              onTap: _openGeminiLive,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: IosSvgIcon(
                  'mic',
                  size: 20,
                  color: isDark ? AppColors.darkTextTertiary : const Color(0xFF71717A),
                ),
              ),
            ),

            const SizedBox(width: 6),

            // Black Circular Send Button
            IosBouncingButton(
              onTap: () => _handleSendMessage(_textController.text),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.iosBlack,
                ),
                child: const Center(
                  child: IosSvgIcon(
                    'send',
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatOptionsSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const IosSvgIcon('refresh', size: 20, color: Color(0xFF7C3AED)),
                title: Text('New Conversation', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<ChatProvider>().clearConversation();
                },
              ),
              ListTile(
                leading: const IosSvgIcon('mic', size: 20, color: Color(0xFFEC4899)),
                title: Text('Live Voice Mode', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openGeminiLive();
                },
              ),
              ListTile(
                leading: const IosSvgIcon('sliders', size: 20, color: Color(0xFF38BDF8)),
                title: Text('Settings & Intelligence', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
