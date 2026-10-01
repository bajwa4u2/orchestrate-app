import 'package:flutter/material.dart';

import 'ob.dart';

/// DD-26: these names now carry direction B values (see `ob.dart`), so every
/// workspace screen that spoke in `Ws` moved to paper and ink at once. New
/// work uses `Ob` directly; `Ws` stays so nothing had to be rewritten blind.
///
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
  static const canvas = Ob.paper;

  /// Where work sits.
  static const surface = Ob.card;

  /// Secondary panels, and anything subordinate to the work in front.
  static const surfaceSoft = Ob.cardSoft;

  /// Wells: inputs, code, quoted material. Reads as cut into the surface.
  static const sunken = Ob.well;

  /// Raised above the surface — menus, sheets, anything overlaying.
  static const raised = Ob.card;

  // ── Lines ──────────────────────────────────────────────────────────

  /// Ordinary separation. Quiet enough to use often.
  static const hairline = Ob.line;

  /// Structural separation: rail edges, header, panel boundaries.
  static const hairlineStrong = Ob.lineStrong;

  // ── Ink ────────────────────────────────────────────────────────────

  static const ink = Ob.ink;
  static const inkMuted = Ob.inkMuted;
  static const inkSubtle = Ob.inkFaint;

  // ── The deep field: identity, and the join to the public product ───

  static const field = Ob.ink;
  static const fieldDeep = Color(0xFF111820);
  static const fieldRaised = Color(0xFF222D3A);
  static const onField = Ob.onInk;
  static const onFieldMuted = Ob.onInkMuted;
  static const onFieldSubtle = Color(0xFFA7ADB5);

  // ── Accent: continuity and orientation ─────────────────────────────
  //
  // The same teal the public product uses. Identity is carried by the things
  // that signify, and this is the one that does.

  static const accent = Ob.ink;
  static const accentBright = Ob.inkSoft;
  static const accentSoft = Ob.well;
  static const accentEdge = Ob.lineStrong;
  static const onAccent = Ob.card;

  // ── Consequence ────────────────────────────────────────────────────
  //
  // Three, and only three. Each names something that happened or will happen,
  // and none of them is used to decorate a heading.

  /// Something completed, delivered, paid, reached.
  static const positive = Ob.money;
  static const positiveSoft = Ob.moneySoft;

  /// Something needs a person. Not an error — a decision that is owed.
  static const caution = Ob.yesDeep;
  static const cautionSoft = Ob.yesSoft;

  /// Something failed, was refused, or cannot proceed.
  static const critical = Ob.refused;
  static const criticalSoft = Ob.refusedSoft;

  /// Stated, not urgent. Governance, provenance, the reason for a thing.
  static const info = Ob.inkSoft;
  static const infoSoft = Ob.well;

  // ── Geometry ───────────────────────────────────────────────────────
  //
  // Tighter than the public product on purpose. Marketing radii read as
  // friendly; operational radii read as precise, and at workspace density a
  // large radius eats the corner of every dense row.

  static const radiusSmall = 6.0;
  static const radius = 10.0;
  static const radiusLarge = 16.0;

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
  static ThemeData get data => Ob.theme();
}
