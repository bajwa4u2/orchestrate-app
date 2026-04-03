import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFF07101F);
  static const sidebar = Color(0xFF08101D);
  static const panel = Color(0xFF0D172A);
  static const panelRaised = Color(0xFF101D34);
  static const panelSoft = Color(0xFF0F1A2E);
  static const line = Color(0xFF182742);
  static const lineSoft = Color(0xFF223252);
  static const text = Color(0xFFF5F7FB);
  static const muted = Color(0xFF95A4C2);
  static const subdued = Color(0xFF70809F);
  static const accent = Color(0xFF72B7FF);
  static const accentSoft = Color(0xFF16304D);
  static const amber = Color(0xFFF4BF63);
  static const rose = Color(0xFFE67777);
  static const emerald = Color(0xFF48C08F);

  static const publicBackground = Color(0xFFF6F7F4);
  static const publicSurface = Color(0xFFFFFFFF);
  static const publicSurfaceSoft = Color(0xFFF0F2EE);
  static const publicLine = Color(0xFFE1E5DE);
  static const publicText = Color(0xFF111827);
  static const publicMuted = Color(0xFF5C6675);
  static const publicAccent = Color(0xFF1F4ED8);
  static const publicAccentSoft = Color(0xFFE7EDFF);

  static ThemeData get darkTheme {
    final scheme = const ColorScheme.dark(
      primary: accent,
      surface: panel,
      onSurface: text,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: text,
          height: 1.04,
          letterSpacing: -1.1,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: text,
          height: 1.12,
          letterSpacing: -0.45,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: text,
          height: 1.2,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: text,
          height: 1.24,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          color: text,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: muted,
          height: 1.5,
        ),
      ),
      dividerColor: line,
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: line),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    final scheme = const ColorScheme.light(
      primary: publicAccent,
      surface: publicSurface,
      onSurface: publicText,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: publicBackground,
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 54,
          fontWeight: FontWeight.w700,
          color: publicText,
          height: 1.02,
          letterSpacing: -1.6,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: publicText,
          height: 1.12,
          letterSpacing: -0.55,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: publicText,
          height: 1.2,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: publicText,
          height: 1.24,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: publicText,
          height: 1.55,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: publicMuted,
          height: 1.55,
        ),
      ),
      dividerColor: publicLine,
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      cardTheme: CardThemeData(
        color: publicSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: publicLine),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: publicSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: publicLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: publicLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: publicAccent, width: 1.2),
        ),
      ),
    );
  }
}
