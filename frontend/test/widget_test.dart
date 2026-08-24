import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/weather_model.dart';
import 'package:frontend/models/user_context.dart';
import 'package:frontend/providers/theme_provider.dart';
import 'package:frontend/providers/user_context_provider.dart';

void main() {
  group('WeatherGPT Unit & State Tests', () {
    test('WeatherData empty model initialization test', () {
      final weather = WeatherData.empty();
      expect(weather.location.name, 'Loading...');
      expect(weather.temperature, 0.0);
      expect(weather.rainProbability, 0.0);
      expect(weather.hourlyForecast.isEmpty, true);
      expect(weather.dailyForecast.isEmpty, true);
    });

    test('UserContext & Persona switching test', () {
      final provider = UserContextProvider();
      expect(provider.currentPersona, DetectedPersona.general);

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
