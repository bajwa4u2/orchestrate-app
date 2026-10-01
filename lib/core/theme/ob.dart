import 'package:flutter/material.dart';

/// DIRECTION B: "THE PATH TO PAID" (DD-26, founder, 2026-09-30).
///
/// One look for the public product and the workspace: paper ground, white
/// cards, ink. Depth comes from layering cards on paper, never from gradients.
///
/// COLOUR HAS ONE MEANING EACH, AND THAT IS THE WHOLE SYSTEM.
///
/// Amber says exactly one thing: this is waiting for your yes. Green says
/// exactly one thing: money. A screen that uses either for anything else
/// (decoration, a heading, a "healthy" badge) teaches the owner to stop
/// reading them, and the two most important facts in the product stop being
/// glanceable. Everything else is ink on paper.
///
/// Type: Newsreader for what is said to a person (headings, names), Public
/// Sans for everything read in quantity, JetBrains Mono for amounts and counts
/// so figures line up and read as figures.
class Ob {
  const Ob._();

  // ── Ground ─────────────────────────────────────────────────────────
  static const paper = Color(0xFFF3EFE7);
  static const card = Color(0xFFFFFFFF);
  static const cardSoft = Color(0xFFF7F4EE);
  static const well = Color(0xFFEEE9DF);
  static const line = Color(0xFFE4DED2);
  static const lineStrong = Color(0xFFD6D1C6);
  static const track = Color(0xFFE7E2D8);

  // ── Ink ────────────────────────────────────────────────────────────
  static const ink = Color(0xFF17202B);
  static const inkSoft = Color(0xFF3A4553);
  static const inkMuted = Color(0xFF5B6573);
  static const inkFaint = Color(0xFF8A8F98);
  static const onInk = Color(0xFFF3EFE7);
  static const onInkMuted = Color(0xFFD6D3CC);

  // ── Waiting for your yes. Nothing else. ────────────────────────────
  static const yes = Color(0xFFD97706);
  static const yesDeep = Color(0xFFB45309);
  static const yesSoft = Color(0xFFFEF3C7);
  static const yesInk = Color(0xFF92400E);

  // ── Money. Nothing else. ───────────────────────────────────────────
  static const money = Color(0xFF15803D);
  static const moneyBright = Color(0xFF16A34A);
  static const moneySoft = Color(0xFFDCFCE7);
  static const moneyInk = Color(0xFF166534);
  static const moneyOnInk = Color(0xFF86EFAC);

  // ── Something could not be done. Used with its reason, always. ─────
  static const refused = Color(0xFFB91C1C);
  static const refusedSoft = Color(0xFFFEE2E2);

  // ── Families ───────────────────────────────────────────────────────
  static const serif = 'Newsreader';
  static const sans = 'PublicSans';
  static const mono = 'JetBrainsMono';

  // ── Geometry ───────────────────────────────────────────────────────
  static const radiusControl = 10.0;
  static const radiusCard = 16.0;
  static const radiusPanel = 18.0;
  static const radiusPill = 999.0;

  static const List<BoxShadow> lift = [
    BoxShadow(color: Color(0x1A17202B), blurRadius: 36, offset: Offset(0, 18)),
  ];
  static const List<BoxShadow> liftHigh = [
    BoxShadow(color: Color(0x2417202B), blurRadius: 52, offset: Offset(0, 26)),
  ];

  // ── Type ───────────────────────────────────────────────────────────
  static TextStyle display(double size, {Color color = ink}) => TextStyle(
        fontFamily: serif,
        fontWeight: FontWeight.w600,
        fontSize: size,
        height: 1.05,
        letterSpacing: -size * 0.015,
        color: color,
      );

  /// The italic half of a headline: "Three things need your *yes.*"
  static TextStyle displayAccent(double size, {Color color = yesDeep}) =>
      display(size, color: color).copyWith(fontStyle: FontStyle.italic);

  static TextStyle name(double size, {Color color = ink}) => TextStyle(
        fontFamily: serif,
        fontWeight: FontWeight.w600,
        fontSize: size,
        height: 1.2,
        color: color,
      );

  static TextStyle body(double size,
          {Color color = inkSoft, FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: sans,
        fontSize: size,
        height: 1.5,
        fontWeight: weight,
        color: color,
      );

  static TextStyle strong(double size, {Color color = ink}) =>
      body(size, color: color, weight: FontWeight.w600);

  static TextStyle figure(double size,
          {Color color = ink, FontWeight weight = FontWeight.w600}) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        fontWeight: weight,
        height: 1.1,
        // Large mono figures close up slightly, so "29.99" reads as one
        // number rather than five cells.
        letterSpacing: size >= 24 ? -size * 0.045 : 0,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Small capitals label: "WAITING FOR YOUR YES", "STEP 2 OF 6".
  static TextStyle eyebrow({Color color = inkMuted}) => TextStyle(
        fontFamily: mono,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.6,
        height: 1.2,
        color: color,
      );

  /// The one theme both shells build on.
  static ThemeData theme() {
    const scheme = ColorScheme.light(
      primary: ink,
      onPrimary: card,
      secondary: inkSoft,
      surface: card,
      onSurface: ink,
      error: refused,
    );
    OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: c, width: w),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      canvasColor: paper,
      fontFamily: sans,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      dividerColor: line,
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      textTheme: TextTheme(
        displayLarge: display(60),
        displayMedium: display(48),
        displaySmall: display(40),
        headlineLarge: display(34),
        headlineMedium: display(26),
        headlineSmall: name(21),
        titleLarge: strong(17),
        titleMedium: strong(15),
        titleSmall: strong(13.5),
        bodyLarge: body(16),
        bodyMedium: body(14.5),
        bodySmall: body(13, color: inkMuted),
        labelLarge: strong(14.5),
        labelMedium: body(12.5, color: inkMuted, weight: FontWeight.w600),
        labelSmall: body(11.5, color: inkMuted, weight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: card,
          disabledBackgroundColor: track,
          disabledForegroundColor: inkFaint,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: strong(15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: card,
          minimumSize: const Size(0, 46),
          side: const BorderSide(color: lineStrong, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: strong(15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: strong(15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        hintStyle: body(16, color: inkFaint),
        labelStyle: strong(15),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: border(lineStrong),
        enabledBorder: border(lineStrong),
        focusedBorder: border(ink, 2),
        errorBorder: border(refused, 2),
        focusedErrorBorder: border(refused, 2),
        errorStyle: body(13.5, color: refused),
        errorMaxLines: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: ink,
        labelStyle: body(14, color: ink),
        secondaryLabelStyle: body(14, color: onInk),
        side: const BorderSide(color: lineStrong),
        shape: const StadiumBorder(),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? ink : card),
        side: const BorderSide(color: lineStrong, width: 1.5),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: ink.withValues(alpha: 0.16),
        cursorColor: ink,
        selectionHandleColor: ink,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: body(14.5, color: onInk),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 400),
      ),
    );
  }
}
