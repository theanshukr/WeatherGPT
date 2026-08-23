import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/weather_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/user_context_provider.dart';
import 'providers/voice_provider.dart';
import 'screens/splash_screen.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase Cloud Auth & Database
  try {
    await SupabaseService.initialize();
    await SupabaseService.signInAnonymously();
  } catch (e) {
    debugPrint('Supabase initialization fallback: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => UserContextProvider()),
        ChangeNotifierProvider(create: (_) => VoiceProvider()),
      ],
      child: const WeatherGptApp(),
    ),
  );
}

class WeatherGptApp extends StatelessWidget {
  const WeatherGptApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'WeatherGPT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}
