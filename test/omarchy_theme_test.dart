import 'package:flutter_test/flutter_test.dart';
import 'package:Mirarr/functions/themeprovider_class.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ThemeProvider & Omarchy Theme Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'theme': 'orange'});
    });

    test('initializes with default theme and loads shared preferences', () async {
      final provider = ThemeProvider(AppThemes.orangeTheme);
      await provider.loadTheme();
      expect(provider.currentTheme, equals(AppThemes.orangeTheme));
      expect(provider.isOmarchyLinux, isTrue); // True on this host machine
    });

    test('sets Omarchy theme when available', () async {
      final provider = ThemeProvider(AppThemes.orangeTheme);
      await provider.loadTheme();
      if (provider.isOmarchyLinux) {
        await provider.setOmarchyTheme();
        expect(provider.omarchyTheme, isNotNull);
        expect(provider.currentTheme, equals(provider.omarchyTheme));
      }
    });
  });
}
