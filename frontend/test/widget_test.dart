import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/weather_model.dart';
import 'package:frontend/models/user_context.dart';
import 'package:frontend/providers/theme_provider.dart';
import 'package:frontend/providers/user_context_provider.dart';

void main() {
  group('WeatherGPT Unit & State Tests', () {
    test('WeatherData default model initialization test', () {
      final defaultWeather = WeatherData.defaultData();
      expect(defaultWeather.location.name, 'New Delhi');
      expect(defaultWeather.temperature, 28.0);
      expect(defaultWeather.rainProbability, 65.0);
      expect(defaultWeather.hourlyForecast.isNotEmpty, true);
      expect(defaultWeather.dailyForecast.isNotEmpty, true);
    });

    test('UserContext & Persona switching test', () {
      final provider = UserContextProvider();
      expect(provider.currentPersona, DetectedPersona.farmer);

      provider.setPersona(DetectedPersona.traveller);
      expect(provider.currentPersona, DetectedPersona.traveller);
      expect(provider.userContext.confidenceScore, 0.95);
    });

    test('ThemeProvider toggle test', () {
      final themeProvider = ThemeProvider();
      expect(themeProvider.isDarkMode, true);

      themeProvider.toggleTheme();
      expect(themeProvider.isDarkMode, false);

      themeProvider.toggleTheme();
      expect(themeProvider.isDarkMode, true);
    });
  });
}
