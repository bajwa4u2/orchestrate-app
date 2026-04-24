import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFF090D14);
  static const sidebar = Color(0xFF0B1018);
  static const panel = Color(0xFF101722);
  static const panelRaised = Color(0xFF151F2E);
  static const panelSoft = Color(0xFF121B28);
  static const line = Color(0xFF263244);
  static const lineSoft = Color(0xFF334155);
  static const text = Color(0xFFF5F7FB);
  static const muted = Color(0xFFBAC5D6);
  static const subdued = Color(0xFF8795AA);
  static const accent = Color(0xFF6FD3C3);
  static const accentSoft = Color(0xFF143A36);
  static const amber = Color(0xFFE5B454);
  static const rose = Color(0xFFE06F72);
  static const emerald = Color(0xFF51C38E);

  // Added for the new inquiry screens so they compile cleanly
  static const slate = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  static const publicBackground = Color(0xFFF7F8FA);
  static const publicSurface = Color(0xFFFFFFFF);
  static const publicSurfaceSoft = Color(0xFFF1F4F7);
  static const publicLine = Color(0xFFDDE3EA);
  static const publicText = Color(0xFF10151F);
  static const publicMuted = Color(0xFF5F6B7A);
  static const publicAccent = Color(0xFF176B5D);
  static const publicAccentSoft = Color(0xFFE6F4F1);
  static const publicAmberSoft = Color(0xFFFFF4D8);
  static const publicRoseSoft = Color(0xFFFFECEC);

  static const radius = 8.0;
  static const radiusLarge = 12.0;

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
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: text,
          height: 1.12,
          letterSpacing: 0,
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
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: publicText,
          height: 1.12,
          letterSpacing: 0,
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
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: publicLine),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: publicSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: publicLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: publicLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: publicAccent, width: 1.2),
        ),
      ),
    );
  }
}
