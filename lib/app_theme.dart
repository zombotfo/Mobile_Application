import 'package:flutter/material.dart';

enum AppThemeChoice { red, green }

class AppTheme {
  static final ValueNotifier<AppThemeChoice> choice =
      ValueNotifier(AppThemeChoice.red);

  static Color seed(AppThemeChoice choice) => switch (choice) {
        AppThemeChoice.red => const Color(0xFFED4245),
        AppThemeChoice.green => const Color(0xFF3BA55C),
      };

  static ThemeData build(AppThemeChoice choice) {
    final colors = ColorScheme.fromSeed(
      seedColor: seed(choice),
      brightness: Brightness.light,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colors,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F4F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
