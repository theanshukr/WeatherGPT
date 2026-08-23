import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/user_context.dart';
import '../providers/theme_provider.dart';
import '../providers/user_context_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/voice_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _severeAlertsEnabled = true;
  bool _rainPrecipAlertsEnabled = true;
  bool _dailyBriefingEnabled = true;
  bool _isCelsius = true;
  bool _preciseGpsLocation = true;

  void _showPrivacyPolicyModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Privacy & Data Policy',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'At WeatherGPT, your privacy and atmospheric data ownership are paramount. Here is how your data is handled:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
              _buildPrivacyPoint(
                context,
                title: '📍 Location Intelligence',
                description:
                    'Your GPS coordinates are used exclusively to fetch localized real-time radar and meteorological data. They are never sold or shared with advertisers.',
              ),
              _buildPrivacyPoint(
                context,
                title: '🧠 AI Voice & Context Processing',
                description:
                    'Conversations with WeatherGPT are processed to tailor agricultural and travel recommendations to your active persona. Context can be reset anytime.',
              ),
              _buildPrivacyPoint(
                context,
                title: '🔒 Local Encryption & Anonymization',
                description:
                    'All cached chat threads and persona insights are encrypted on-device with zero persistent tracking IDs.',
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      'I Understand',
                      style: TextStyle(
                        color: isDark ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyPoint(BuildContext context, {required String title, required String description}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Clear Chat History?'),
        content: const Text('This will delete all previous conversations and restart your WeatherGPT assistant thread.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertCrimson,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              context.read<ChatProvider>().clearConversation();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat history cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProv = context.watch<ThemeProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 26,
                    color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // SECTION 1: APPEARANCE
                  _buildSectionHeader(context, title: 'Appearance & Theme'),
                  _buildCard(
                    context,
                    children: [
                      _buildSwitchTile(
                        context,
                        icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        title: 'Dark Mode (OLED Emerald)',
                        subtitle: isDark ? 'OLED pitch-black theme enabled' : 'Clean frosted light theme',
                        value: isDark,
                        onChanged: (val) => themeProv.toggleTheme(),
                      ),
                      const Divider(height: 1),
                      _buildSwitchTile(
                        context,
                        icon: Icons.thermostat_rounded,
                        title: 'Temperature Unit (°C / °F)',
                        subtitle: _isCelsius ? 'Celsius (°C)' : 'Fahrenheit (°F)',
                        value: _isCelsius,
                        onChanged: (val) => setState(() => _isCelsius = val),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // SECTION 2: NOTIFICATIONS & ALERTS
                  _buildSectionHeader(context, title: 'Alerts & Notifications'),
                  _buildCard(
                    context,
                    children: [
                      _buildSwitchTile(
                        context,
                        icon: Icons.warning_amber_rounded,
                        title: 'Severe Weather Alerts',
                        subtitle: 'Proactive warnings for storms, heatwaves & gale winds',
                        value: _severeAlertsEnabled,
                        onChanged: (val) => setState(() => _severeAlertsEnabled = val),
                      ),
                      const Divider(height: 1),
                      _buildSwitchTile(
                        context,
                        icon: Icons.water_drop_outlined,
                        title: 'Rain & Precipitation Heads-Up',
                        subtitle: 'Notify 30 mins before rain starts in your area',
                        value: _rainPrecipAlertsEnabled,
                        onChanged: (val) => setState(() => _rainPrecipAlertsEnabled = val),
                      ),
                      const Divider(height: 1),
                      _buildSwitchTile(
                        context,
                        icon: Icons.wb_sunny_outlined,
                        title: 'Daily Morning Briefing',
                        subtitle: '7:00 AM summary tailored to your active persona',
                        value: _dailyBriefingEnabled,
                        onChanged: (val) => setState(() => _dailyBriefingEnabled = val),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // SECTION 3: AI PERSONA & VOICE
                  _buildSectionHeader(context, title: 'AI Persona & Voice Mode'),
                  _buildCard(
                    context,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Weather Intelligence Persona',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Influences how WeatherGPT formulates advice and forecasts.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildPersonaChoice(context, persona: DetectedPersona.farmer, label: '🌾 Farmer'),
                                const SizedBox(width: 8),
                                _buildPersonaChoice(context, persona: DetectedPersona.traveller, label: '✈️ Traveller'),
                                const SizedBox(width: 8),
                                _buildPersonaChoice(context, persona: DetectedPersona.general, label: '☀️ General'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Consumer<VoiceProvider>(
                        builder: (context, voiceProvider, _) => Column(
                          children: [
                            _buildSwitchTile(
                              context,
                              icon: Icons.record_voice_over_rounded,
                              title: 'Voice Auto-Speech Feedback',
                              subtitle: 'Automatically read WeatherGPT\'s replies aloud',
                              value: voiceProvider.autoSpeechEnabled,
                              onChanged: voiceProvider.setAutoSpeechEnabled,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              context,
                              icon: Icons.graphic_eq_rounded,
                              title: 'Natural Voice (Cloud)',
                              subtitle: voiceProvider.naturalVoiceEnabled
                                  ? 'Higher-quality voice \u2014 uses data, needs network'
                                  : 'Off: using free on-device voice, works offline',
                              value: voiceProvider.naturalVoiceEnabled,
                              onChanged: voiceProvider.setNaturalVoiceEnabled,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // SECTION 4: PRIVACY & DATA
                  _buildSectionHeader(context, title: 'Privacy & Security'),
                  _buildCard(
                    context,
                    children: [
                      _buildSwitchTile(
                        context,
                        icon: Icons.location_on_outlined,
                        title: 'Precise GPS Location',
                        subtitle: 'High precision radar lookup vs approximate city',
                        value: _preciseGpsLocation,
                        onChanged: (val) => setState(() => _preciseGpsLocation = val),
                      ),
                      const Divider(height: 1),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            Icons.privacy_tip_outlined,
                            color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                          ),
                          title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text('Read our zero-tracking data promise', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                          onTap: () => _showPrivacyPolicyModal(context),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_outline_rounded, color: AppColors.alertCrimson),
                        title: const Text('Clear Chat History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.alertCrimson)),
                        subtitle: const Text('Wipe cached assistant messages', style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                        onTap: () => _showClearCacheDialog(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // App Version Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'WeatherGPT v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Powered by Google Gemini & Open-Meteo API',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, {required String title}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.emeraldNeon,
        secondary: Icon(
          icon,
          color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
          size: 22,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPersonaChoice(
    BuildContext context, {
    required DetectedPersona persona,
    required String label,
  }) {
    final contextProv = context.watch<UserContextProvider>();
    final isSelected = contextProv.currentPersona == persona;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => contextProv.setPersona(persona),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.emeraldNeon.withValues(alpha: 0.2) : AppColors.emeraldDark.withValues(alpha: 0.15))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
