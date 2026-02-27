import 'package:flutter/material.dart';

/// EchoNova design system: colors, typography, and component theming
/// inspired by the brand logo (vivid violets, magentas, and oranges).
class EchoNovaTheme {
  EchoNovaTheme._();

  /// Core brand colors
  static const Color primary = Color(0xFF7C3AED); // violet
  static const Color secondary = Color(0xFFF97316); // orange accent
  static const Color background = Color(0xFF020617); // deep navy
  static const Color surface = Color(0xFF0B1020);
  static const Color surfaceElevated = Color(0xFF111827);
  static const Color textHigh = Colors.white;
  static const Color textMedium = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);

  /// Shared gradient used across hero areas, primary CTAs, and player.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4C1D95), // deep violet
      primary,
      secondary,
    ],
  );

  /// Build the global [ThemeData] for the app.
  static ThemeData buildTheme() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      secondary: secondary,
      background: background,
      surface: surface,
      error: error,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textHigh,
        ),
      ),
      cardColor: surface,
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceElevated,
        contentTextStyle: TextStyle(color: textHigh),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: primary,
          foregroundColor: textHigh,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      cardTheme: base.cardTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textMedium),
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textHigh,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textHigh,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: textMedium,
        ),
        labelSmall: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
      ),
    );
  }
}

