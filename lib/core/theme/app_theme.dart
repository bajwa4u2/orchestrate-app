import 'package:flutter/material.dart';

/// NAVIGATING A WORKSPACE IS NOT TURNING A PAGE.
///
/// Flutter's default page transition cross-fades two full-screen surfaces. In
/// a rail-based workspace both surfaces are opaque, so for the length of the
/// animation the screen a person just left is painted ON TOP of the one they
/// asked for. The rail updates immediately, the content does not, and the
/// reading is unambiguous: nothing happened.
///
/// That is exactly what "clicking the logo does not take me home" was. The
/// logo always navigated; the destination was simply behind the surface it
/// replaced, for long enough to look broken.
///
/// A workspace destination should arrive the way a rail selection implies:
/// immediately. Applied here rather than per route so there is one answer for
/// the whole estate — 139 real routes across four shells — instead of a
/// transition policy that drifts screen by screen.
class _ImmediateTransitions extends PageTransitionsBuilder {
  const _ImmediateTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

const _workspaceTransitions = PageTransitionsTheme(builders: {
  TargetPlatform.android: _ImmediateTransitions(),
  TargetPlatform.iOS: _ImmediateTransitions(),
  TargetPlatform.linux: _ImmediateTransitions(),
  TargetPlatform.macOS: _ImmediateTransitions(),
  TargetPlatform.windows: _ImmediateTransitions(),
});

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

  // Orchestrate public-estate canvas tokens. Light chapters remain available
  // as intentional content fields, but the page substrate is always owned by
  // the Orchestrate environment.
  static const publicCanvas = Color(0xFF091521);
  static const publicDeepField = Color(0xFF0E1723);
  static const publicSecondaryField = Color(0xFF132A38);
  static const publicLightField = Color(0xFFF2F5F3);
  static const publicSupportField = Color(0xFF15343A);
  static const publicFooterField = Color(0xFF071019);
  static const publicOnDark = Color(0xFFF4FAF8);
  static const publicOnDarkMuted = Color(0xFFB9C8D6);

  // ─── Canonical substrate tokens ──────────────────────────────────
  // Mirror `company/visuals/system/tokens/design-tokens.md`. These are
  // the visual identifiers used on the public website and the flagship
  // cognition artifacts (OR-01 / OR-02 / CG-03 / AU-01 / CG-01). New
  // substrate-substantive surfaces should use these directly so the
  // app and the website remain visually coherent. Existing legacy
  // constants above are preserved — no in-place regression.
  //
  // Source: company/visuals/system/tokens/design-tokens.md §4-§5
  // Source: company/visuals/system/diagnostics/diagnostics-grammar.md §3.3
  //         (the verdant / sun / rose / mist triad)
  static const coAbyss = Color(0xFF0E1326);
  static const coMidnight = Color(0xFF151B33);
  static const coMidnightSoft = Color(0xFF181E36);
  static const coSlate = Color(0xFF1E2540);
  static const coEdge = Color(0xFF2A3458);
  static const coSnow = Color(0xFFF5F7FB);
  static const coMist = Color(0xFFA6AECC);
  static const coTeal = Color(0xFF0D9488);
  static const coTealDeep = Color(0xFF176B5D);
  static const coVerdant = Color(0xFF22C55E);
  static const coSun = Color(0xFFEAB308);
  static const coRose = Color(0xFFF43F5E);
  // Functional darker variants for light-register surfaces
  static const coVerdantDeep = Color(0xFF16A34A);
  static const coSunDeep = Color(0xFFCA8A04);
  static const coRoseDeep = Color(0xFFE11D48);

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
      pageTransitionsTheme: _workspaceTransitions,
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
      // Text selection must be clearly visible on the dark shell —
      // Orchestrate is an operational workspace; operators select and
      // copy diagnostics, IDs, rationale, and logs constantly.
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: accent.withValues(alpha: 0.30),
        cursorColor: accent,
        selectionHandleColor: accent,
      ),
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
      pageTransitionsTheme: _workspaceTransitions,
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
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: publicAccent.withValues(alpha: 0.22),
        cursorColor: publicAccent,
        selectionHandleColor: publicAccent,
      ),
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

/// Shared responsive thresholds for shells and screens.
///
/// Use these named constants instead of inline `< 760`/`< 860`/`< 980`
/// magic numbers so every surface (public, client, operator) interprets
/// "mobile" or "stacked" the same way. Changing one breakpoint here
/// updates the entire product.
class WorkspaceBreakpoints {
  WorkspaceBreakpoints._();

  /// Below this width the workspace rail collapses into a drawer.
  static const double mobile = 760;

  /// Below this width small two-column compositions (metric strips,
  /// short side-by-side cards) stack into a single column.
  static const double compact = 860;

  /// Below this width large two-pane layouts (overview hero + side panel,
  /// leads list + intelligence panel, reply detail + thread) stack into a
  /// single column.
  static const double stacked = 980;

  /// Maximum content column width inside the workspace shell. Keeps lines
  /// readable on ultrawide monitors without leaving cramped side voids on
  /// tablet/desktop.
  static const double contentMax = 1320;
}
