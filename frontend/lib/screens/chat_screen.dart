import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/chat_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/user_context_provider.dart';
import '../widgets/chat_message_view.dart';

class ChatScreen extends StatefulWidget {
  final String? initialQuery;

  const ChatScreen({super.key, this.initialQuery});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _starterPrompts = [
    '🌾 Is it safe to spray crops today?',
    '🌧️ What is the rain timeline for the next 6 hours?',
    '✈️ What should I pack for travel this weekend?',
    '⚡ Any severe weather warnings active near me?',
  ];

  @override
  void initState() {
    super.initState();
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
    if (text.trim().isEmpty) return;
    final weatherProv = context.read<WeatherProvider>();
    final contextProv = context.read<UserContextProvider>();

    context.read<ChatProvider>().sendUserMessage(
          text,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProv = context.watch<ChatProvider>();
    final weatherProv = context.watch<WeatherProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left_rounded,
            size: 32,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'WeatherGPT',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              '${weatherProv.weatherData.location.name} • Live Intelligence',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.emeraldGlow : AppColors.emeraldDark,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.restart_alt_rounded,
              size: 22,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            tooltip: 'New Conversation',
            onPressed: () => chatProv.clearConversation(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Message Thread or Starter Prompts
            Expanded(
              child: chatProv.messages.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: chatProv.messages.length,
                      itemBuilder: (context, index) {
                        final message = chatProv.messages[index];
                        return ChatMessageView(
                          message: message,
                          onActionSelected: (query) => _handleSendMessage(query),
                        );
                      },
                    ),
            ),

            // Typing Indicator
            if (chatProv.isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'WeatherGPT is analyzing radar & forecasts...',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ChatGPT Inspired Bottom Pill Input Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Text Input Pill
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: GoogleFonts.inter(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask WeatherGPT anything...',
                          hintStyle: GoogleFonts.inter(
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (value) => _handleSendMessage(value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send Action Button
                  GestureDetector(
                    onTap: () => _handleSendMessage(_textController.text),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                                .withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 22,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                border: Border.all(
                  color: isDark ? AppColors.emeraldNeon.withValues(alpha: 0.3) : AppColors.emeraldDark.withValues(alpha: 0.2),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 32,
                  color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'How can I help you with weather today?',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask for agricultural spray forecasts, precipitation radar, packing tips, or atmospheric alerts.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Starter Prompts Grid
            Column(
              children: _starterPrompts.map((prompt) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => _handleSendMessage(prompt),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              prompt,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
