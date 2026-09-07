import 'package:flutter/material.dart';

/// THE AUTHENTICATED WORKSPACE HAS ITS OWN THEME, AND UNTIL NOW IT DID NOT.
///
/// `client_shell` rendered with `AppTheme.lightTheme` — the same ThemeData the
/// public marketing site uses. That is the structural reason the workspace
/// drifted to black, white and grey while the public product gained depth: the
/// public pages build their identity on top of that theme with deep fields and
/// rich composition, and the workspace inherited only the neutral base.
///
/// It inherited the marketing PROPORTIONS too. A 54px headline, 16px of
/// vertical padding inside every button and a 16px body are written for a page
/// somebody reads once, standing back. A commercial operating environment is
/// read all day at arm's length, and those proportions are most of what makes
/// a desktop workspace feel like an enlarged phone.
///
/// WHAT THIS IS NOT.
///
/// It is not the operator console. That one is genuinely dark — near-black
/// ground, bright teal — because it is Orchestrate's own internal instrument.
/// A client's commercial workspace that looked like it would be indistinguish-
/// able from the tool their supplier runs, and the product is careful about
/// that boundary everywhere else.
///
/// It is not the marketing site either. The public product invites, explains
/// and reassures. This one orients, decides and carries consequence.
///
/// WHAT IT IS.
///
/// The same product at depth. Identity carries across through the things that
/// actually signify — the teal, the typeface, the deep field — while the
/// working surfaces get denser, quieter and genuinely layered.
///
/// The deep field is the join. The public site already puts its most
/// deliberate moments on `publicCanvas`; the workspace uses that same field
/// for the rail, so entering the product reads as descending into it rather
/// than arriving somewhere else.
///
/// COLOUR IS NOT DECORATION HERE.
///
/// One accent, three consequences, one informational tone. Domains are
/// separated by composition and tonal weight rather than by hue, because a
/// palette that assigns every area its own colour stops being able to say
/// anything with colour — and status is the thing that has to survive being
/// glanced at.
class Ws {
  const Ws._();

  // ── Ground and surfaces ────────────────────────────────────────────
  //
  // Four steps, each one doing a job. The canvas is deliberately not white:
  // a workspace whose ground is the same colour as its panels has no depth to
  // spend, and everything on it has to earn separation with a border.

  /// The workspace ground. Cool, tinted, and clearly behind everything.
  static const canvas = Color(0xFFEDF1F5);

  /// Where work sits.
  static const surface = Color(0xFFFFFFFF);

  /// Secondary panels, and anything subordinate to the work in front.
  static const surfaceSoft = Color(0xFFF6F8FA);

  /// Wells: inputs, code, quoted material. Reads as cut into the surface.
  static const sunken = Color(0xFFE6EBF1);

  /// Raised above the surface — menus, sheets, anything overlaying.
  static const raised = Color(0xFFFFFFFF);

  // ── Lines ──────────────────────────────────────────────────────────

  /// Ordinary separation. Quiet enough to use often.
  static const hairline = Color(0xFFDCE3EA);

  /// Structural separation: rail edges, header, panel boundaries.
  static const hairlineStrong = Color(0xFFC6D0DB);

  // ── Ink ────────────────────────────────────────────────────────────

  static const ink = Color(0xFF0F1720);
  static const inkMuted = Color(0xFF55606E);
  static const inkSubtle = Color(0xFF7D8894);

  // ── The deep field: identity, and the join to the public product ───

  static const field = Color(0xFF0C1620);
  static const fieldDeep = Color(0xFF081019);
  static const fieldRaised = Color(0xFF13212E);
  static const onField = Color(0xFFE8EFF3);
  static const onFieldMuted = Color(0xFF93A3B2);
  static const onFieldSubtle = Color(0xFF64798C);

  // ── Accent: continuity and orientation ─────────────────────────────
  //
  // The same teal the public product uses. Identity is carried by the things
  // that signify, and this is the one that does.

  static const accent = Color(0xFF176B5D);
  static const accentBright = Color(0xFF1E8C79);
  static const accentSoft = Color(0xFFE4F1EE);
  static const accentEdge = Color(0xFFB4D8D0);
  static const onAccent = Color(0xFFF4FAF8);

  // ── Consequence ────────────────────────────────────────────────────
  //
  // Three, and only three. Each names something that happened or will happen,
  // and none of them is used to decorate a heading.

  /// Something completed, delivered, paid, reached.
  static const positive = Color(0xFF2F7D53);
  static const positiveSoft = Color(0xFFE6F3EB);

  /// Something needs a person. Not an error — a decision that is owed.
  static const caution = Color(0xFF98680F);
  static const cautionSoft = Color(0xFFFBF0D9);

  /// Something failed, was refused, or cannot proceed.
  static const critical = Color(0xFFAF3A44);
  static const criticalSoft = Color(0xFFFBE9EA);

  /// Stated, not urgent. Governance, provenance, the reason for a thing.
  static const info = Color(0xFF3F5B78);
  static const infoSoft = Color(0xFFE9EFF6);

  // ── Geometry ───────────────────────────────────────────────────────
  //
  // Tighter than the public product on purpose. Marketing radii read as
  // friendly; operational radii read as precise, and at workspace density a
  // large radius eats the corner of every dense row.

  static const radiusSmall = 4.0;
  static const radius = 6.0;
  static const radiusLarge = 10.0;

  /// The rail. Wide enough for a label at workspace density, and fixed so the
  /// work area has a stable left edge to compose against.
  static const railWidth = 232.0;
  static const railCollapsed = 68.0;

  /// Vertical rhythm. Everything spaces in multiples of this.
  static const unit = 4.0;

  // ── Elevation, done with light rather than shadow ───────────────────
  //
  // A workspace at this density cannot afford drop shadows on every panel —
  // they blur the grid and read as clutter. Separation comes from the surface
  // step plus a hairline, and shadow is reserved for things that genuinely
  // float above the page.

  static const List<BoxShadow> overlayShadow = [
    BoxShadow(color: Color(0x1A0F1720), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0D0F1720), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// A panel edge: the hairline that does the work a shadow would.
  static Border panelBorder({Color? color}) =>
      Border.all(color: color ?? hairline, width: 1);

  /// THE WORKSPACE THEME.
  ///
  /// The type scale is the part that changes everything, because screens take
  /// their sizes from here and override only colour. Operational proportions:
  /// a page title that fits on a line beside context, a body sized to be read
  /// in quantity, and a label small enough that a dense row still breathes.
  static ThemeData get data {
    const scheme = ColorScheme.light(
      primary: accent,
      onPrimary: onAccent,
      secondary: info,
      surface: surface,
      onSurface: ink,
      error: critical,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Inter',
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: hairline,
      dividerTheme: const DividerThemeData(
        color: hairline,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        // A surface title. Not a headline — nobody is being introduced to
        // anything here, and 54px of type would take the first screenful.
        headlineLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: ink,
          height: 1.15,
          letterSpacing: -0.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ink,
          height: 1.2,
          letterSpacing: -0.1,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: ink,
          height: 1.25,
        ),
        titleMedium: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: ink,
          height: 1.3,
        ),
        titleSmall: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: ink,
          height: 1.3,
        ),
        bodyLarge: TextStyle(
          fontSize: 14.5,
          color: ink,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 13.5,
          color: ink,
          height: 1.5,
        ),
        // Where most of a workspace actually lives: secondary lines, reasons,
        // metadata. Muted by default so a screen does not have to say so 273
        // times.
        bodySmall: TextStyle(
          fontSize: 12.5,
          color: inkMuted,
          height: 1.45,
        ),
        // Band and section labels.
        labelLarge: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: inkSubtle,
          height: 1.2,
          letterSpacing: 0.7,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: inkMuted,
          height: 1.2,
          letterSpacing: 0.3,
        ),
        labelSmall: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: inkSubtle,
          height: 1.2,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: hairline),
        ),
      ),
      // Controls at operational density. The marketing theme pads buttons to
      // 18x16, which is a thumb target; this is a pointer environment and the
      // same button at that size dominates a dense row.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: hairlineStrong),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        hintStyle: const TextStyle(color: inkSubtle, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: hairlineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: hairlineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: accent.withValues(alpha: 0.20),
        cursorColor: accent,
        selectionHandleColor: accent,
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 400),
      ),
    );
  }
}
