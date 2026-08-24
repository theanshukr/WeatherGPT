import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/user_context_provider.dart';
import '../widgets/chat_message_view.dart';
import '../widgets/gemini_sparkle_icon.dart';
import 'gemini_live_screen.dart';

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
      'icon': Icons.agriculture_rounded,
      'color': Color(0xFF00FF87),
      'title': 'Farming & Spray Advice',
      'query': 'Is the weather suitable for pesticide spraying on crops today?',
    },
    {
      'icon': Icons.water_drop_rounded,
      'color': Color(0xFF00E5FF),
      'title': 'Rain Timeline',
      'query': 'What is the exact rain probability and timeline for the next 6 hours?',
    },
    {
      'icon': Icons.flight_takeoff_rounded,
      'color': Color(0xFF9B72CF),
      'title': 'Highway & Travel Safety',
      'query': 'Evaluate driving conditions, road visibility and storm risk for travel.',
    },
    {
      'icon': Icons.warning_amber_rounded,
      'color': Color(0xFFFF758C),
      'title': 'Severe Warnings',
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
          curve: Curves.easeOut,
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
    final weatherProv = context.watch<WeatherProvider>();
    final locationName = weatherProv.weatherData.location.name.isNotEmpty &&
            weatherProv.weatherData.location.name != 'Loading...'
        ? weatherProv.weatherData.location.name
        : 'Live Location';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const GeminiSparkleIcon(size: 22),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'WeatherGPT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '2.0 Flash',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.geminiBlue,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Gemini Live Shortcut Icon in Header
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.geminiSparkleGradient,
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
            ),
            tooltip: 'Gemini Live Voice',
            onPressed: _openGeminiLive,
          ),

          // New Chat Reset Button
          IconButton(
            icon: Icon(
              Icons.add_comment_outlined,
              size: 20,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            tooltip: 'New Conversation',
            onPressed: () => chatProv.clearConversation(),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Message Stream or Gemini Hero Greeting
            Expanded(
              child: chatProv.messages.isEmpty
                  ? _buildGeminiEmptyState(context, locationName, isDark)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: chatProv.messages.length,
                      itemBuilder: (context, index) {
                        final message = chatProv.messages[index];
                        return ChatMessageView(
                          message: message,
                          onActionSelected: (query) => _handleSendMessage(query),
                          onRegenerate: index == chatProv.messages.length - 1 &&
                                  message.role == MessageRole.assistant
                              ? () {
                                  // Re-send previous user query if regenerating
                                  final prevIndex = index - 1;
                                  if (prevIndex >= 0) {
                                    _handleSendMessage(chatProv.messages[prevIndex].content);
                                  }
                                }
                              : null,
                        );
                      },
                    ),
            ),

            // Typing & Tool Analysis Indicator
            if (chatProv.isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const GeminiSparkleIcon(size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Thinking and analyzing meteorological radar...',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // Floating Gemini Bottom Input Bar
            _buildFloatingInputBar(isDark),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Gemini Signature Empty State with Gradient Greeting & Category Grid
  // ---------------------------------------------------------------------------
  Widget _buildGeminiEmptyState(BuildContext context, String locationName, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Radiant Gemini 4-point Star Header
          const GeminiSparkleIcon(size: 40),

          const SizedBox(height: 20),

          // Gradient "Hello" Header
          ShaderMask(
            shaderCallback: (bounds) => AppColors.geminiSparkleGradient.createShader(bounds),
            child: Text(
              'Hello',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1.0,
                height: 1.1,
              ),
            ),
          ),

          Text(
            'How can I help with weather in $locationName today?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              letterSpacing: -0.4,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 32),

          // Gemini 2x2 Suggestion Cards Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
            ),
            itemCount: _starterPrompts.length,
            itemBuilder: (context, index) {
              final prompt = _starterPrompts[index];
              final iconColor = prompt['color'] as Color;

              return GestureDetector(
                onTap: () => _handleSendMessage(prompt['query'] as String),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: iconColor.withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          prompt['icon'] as IconData,
                          size: 18,
                          color: iconColor,
                        ),
                      ),
                      Text(
                        prompt['title'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Floating Gemini Input Bar (Pill with Live Mic + Send Button)
  // ---------------------------------------------------------------------------
  Widget _buildFloatingInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left Quick Action Icon (Location / Attach)
            IconButton(
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                size: 22,
              ),
              onPressed: () {
                final weatherProv = context.read<WeatherProvider>();
                _textController.text =
                    'Current atmospheric conditions and forecast for ${weatherProv.weatherData.location.name}';
              },
            ),

            // Expandable Text Input
            Expanded(
              child: TextField(
                controller: _textController,
                style: GoogleFonts.inter(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontSize: 15,
                ),
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Ask WeatherGPT...',
                  hintStyle: GoogleFonts.inter(
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (value) => _handleSendMessage(value),
              ),
            ),

            // Gemini Live Voice Microphone
            IconButton(
              icon: Icon(
                Icons.mic_rounded,
                color: AppColors.geminiCyan,
                size: 24,
              ),
              tooltip: 'Gemini Live Voice',
              onPressed: _openGeminiLive,
            ),

            // Send Action Button
            if (_hasInputText)
              GestureDetector(
                onTap: () => _handleSendMessage(_textController.text),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.geminiSparkleGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.geminiBlue.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      size: 20,
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
}
