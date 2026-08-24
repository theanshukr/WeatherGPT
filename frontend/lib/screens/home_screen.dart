import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/weather_model.dart';
import '../providers/weather_provider.dart';
import '../providers/user_context_provider.dart';
import '../widgets/context_badge.dart';
import '../widgets/error_dialog.dart';
import '../widgets/gemini_sparkle_icon.dart';
import 'alerts_screen.dart';
import 'map_screen.dart';
import 'chat_screen.dart';
import 'gemini_live_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWeatherStatus();
    });
  }

  void _checkWeatherStatus() {
    final weatherProv = context.read<WeatherProvider>();
    if (weatherProv.errorMessage != null && mounted) {
      ConnectionErrorDialog.show(
        context,
        message: 'Could not connect to backend server. ${weatherProv.errorMessage}',
        onRetry: () => weatherProv.loadWeatherData(),
      );
    }
  }

  void _openGeminiLive() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GeminiLiveScreen()),
    );
  }

  void _openTextChat({String? query}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(initialQuery: query),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weatherProv = context.watch<WeatherProvider>();
    final contextProv = context.watch<UserContextProvider>();
    final weather = weatherProv.weatherData;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // Background Subtle Radiant Aurora Glow
            if (isDark)
              Positioned(
                top: -80,
                left: MediaQuery.of(context).size.width * 0.15,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.geminiBlue.withValues(alpha: 0.08),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.geminiPurple.withValues(alpha: 0.12),
                        blurRadius: 160,
                        spreadRadius: 60,
                      ),
                    ],
                  ),
                ),
              ),

            // Main Scrollable Content
            RefreshIndicator(
              color: AppColors.geminiBlue,
              onRefresh: () async {
                await weatherProv.loadWeatherData();
                _checkWeatherStatus();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // Top Bar: Gemini Sparkle + Location & Action Icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const GeminiSparkleIcon(size: 26),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WeatherGPT',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 12, color: AppColors.geminiBlue),
                                    const SizedBox(width: 2),
                                    Text(
                                      weather.location.name.isNotEmpty && weather.location.name != 'Loading...'
                                          ? weather.location.name
                                          : 'Locating...',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),

                        Row(
                          children: [
                            // GIS Radar Map Button
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                                  border: Border.all(
                                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.public_rounded,
                                  size: 18,
                                  color: AppColors.geminiCyan,
                                ),
                              ),
                              tooltip: 'GIS Radar & Alert Map',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const MapScreen()),
                                );
                              },
                            ),
                            const SizedBox(width: 4),

                            // Severe Weather Alert Bell
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                                  border: Border.all(
                                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.notifications_active_outlined,
                                  size: 18,
                                  color: AppColors.sunnyGold,
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Gemini Persona Context Badge
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ContextBadge(
                        persona: contextProv.currentPersona,
                        confidence: contextProv.userContext.confidenceScore,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Gemini Live Voice Orb Hero Card
                    GestureDetector(
                      onTap: _openGeminiLive,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.geminiSparkleGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.geminiBlue.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Gemini Live Voice',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.geminiBlue.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'NEW',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.geminiBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Talk naturally with Megha AI about forecasts, rain & alerts.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Live Weather Overview Card
                    _buildLiveWeatherCard(context, weatherProv: weatherProv, weather: weather, isDark: isDark),

                    const SizedBox(height: 16),

                    // Hourly Forecast Strip
                    if (weather.hourlyForecast.isNotEmpty)
                      _buildHourlyForecastStrip(context, weather: weather, isDark: isDark),

                    const SizedBox(height: 18),

                    // Quick AI Prompt Chips
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'QUICK QUESTIONS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? AppColors.geminiBlue : const Color(0xFF1A73E8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickChip('🌧️ Will it rain today?', isDark),
                        _buildQuickChip('🌾 Crop spraying advice', isDark),
                        _buildQuickChip('✈️ Weekend travel risk', isDark),
                        _buildQuickChip('⚡ Severe alerts status', isDark),
                      ],
                    ),

                    const SizedBox(height: 90), // Space for floating input pill
                  ],
                ),
              ),
            ),

            // Floating Bottom Ask Pill Bar (Gemini Home Bar)
            Positioned(
              bottom: 16,
              left: 20,
              right: 20,
              child: GestureDetector(
                onTap: () => _openTextChat(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black54 : Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const GeminiSparkleIcon(size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ask WeatherGPT anything...',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _openGeminiLive,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF1E1F20) : const Color(0xFFF0F4F9),
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            size: 18,
                            color: AppColors.geminiCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, bool isDark) {
    return GestureDetector(
      onTap: () => _openTextChat(query: label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveWeatherCard(BuildContext context, {required WeatherProvider weatherProv, required WeatherData weather, required bool isDark}) {
    if (weatherProv.isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.geminiBlue),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Connecting to atmospheric telemetry...',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 17, color: AppColors.geminiBlue),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            weather.location.name,
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weather.conditionDescription,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${weather.temperature.toStringAsFixed(1)}°C',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 34,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 4 Grid Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Precip', '${weather.rainfallAmount.toStringAsFixed(1)} mm', Icons.water_drop_outlined, isDark),
              _buildStatItem('Humidity', '${weather.humidity.toStringAsFixed(0)}%', Icons.opacity_rounded, isDark),
              _buildStatItem('Wind', '${weather.windSpeed.toStringAsFixed(1)} km/h', Icons.air_rounded, isDark),
              _buildStatItem('Wind Dir', '${weather.windDirection.toInt()}°', Icons.explore_outlined, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 19, color: isDark ? AppColors.geminiBlue : const Color(0xFF1A73E8)),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyForecastStrip(BuildContext context, {required WeatherData weather, required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'HOURLY RAIN & TEMPERATURE TIMELINE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? AppColors.geminiBlue : const Color(0xFF1A73E8),
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: weather.hourlyForecast.length.clamp(0, 16),
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final item = weather.hourlyForecast[i];
              final hourStr = '${item.time.hour.toString().padLeft(2, '0')}:00';
              return Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(hourStr, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                    Text('${item.temperature.toStringAsFixed(0)}°', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text('${item.rainProbability.toStringAsFixed(0)}% 🌧️', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? AppColors.geminiCyan : const Color(0xFF1A73E8))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
