import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/workspace_theme.dart';

/// THE SHARED WORKSPACE LAYOUT MODEL.
///
/// One hierarchy — rail → list → work → inspector — rendered as panes when
/// there is width and as a stack when there is not. Before this, forty files
/// made their own breakpoint decisions across six different values, which is
/// how the same product ends up being a different shape on every screen.
///
/// The rule the whole workspace is built on:
///
///   HEALTHY STATE CONSUMES ALMOST NO SPACE. Problems, decisions, work in
///   flight and meaningful change earn space. Everything else is silent.
///
/// A client already inside Orchestrate does not need to be told what
/// Orchestrate does. The space belongs to their work.
class Workspace {
  const Workspace._();

  /// Below this, one pane at a time and navigation pushes.
  static const double phone = 760;

  /// Above this, a list pane can sit beside the work pane.
  static const double twoPane = 1000;

  /// Above this, an inspector can sit beside both without crushing them.
  static const double threePane = 1440;

  /// Width measured in the text that has to fit inside it.
  ///
  /// A breakpoint in raw pixels assumes text of a known size, and the operating
  /// system does not guarantee that. Windows "Make text bigger" at 175% renders
  /// every string almost twice as wide while the window stays exactly as it
  /// was, so a 1266-pixel window holds about as much text as a 723-pixel one.
  /// Compared against a raw breakpoint it looks roomy and behaves cramped:
  /// headings clip, rows run past the right edge, and labels truncate with
  /// visible space beside them.
  ///
  /// So layout decisions are made in this width rather than the real one. The
  /// scale is clamped at the bottom because a user who has made text smaller
  /// has not asked for a denser layout, and at the top because past a point the
  /// answer is a simpler arrangement rather than an ever-narrower one.
  static double effectiveWidth(BuildContext context, [double? available]) {
    final media = MediaQuery.of(context);
    final width = available ?? media.size.width;
    final scale = media.textScaler.scale(14) / 14;
    return width / scale.clamp(1.0, 2.2);
  }

  /// An icon size that keeps its relationship to the text beside it.
  ///
  /// Icons do not follow the text scaler. With the OS enlarging text by three
  /// quarters, every label grows and every mark beside it stays put, so a row
  /// stops reading as one control: the icon drifts from its own label, and the
  /// hit target stops matching the thing it belongs to.
  ///
  /// Capped below the text's own growth on purpose. A sentence has to stay
  /// readable at any size; an icon is a mark, and past a point making it larger
  /// stops helping and starts crowding the words it was meant to support.
  static double icon(BuildContext context, double base) {
    final scale = MediaQuery.of(context).textScaler.scale(14) / 14;
    return base * scale.clamp(1.0, 1.5);
  }

  /// Whether the OS is enlarging text enough to change what fits.
  static bool textIsEnlarged(BuildContext context) =>
      MediaQuery.of(context).textScaler.scale(14) / 14 > 1.15;

  /// HOW WIDE THE RAIL HAS TO BE TO SAY WHAT IT SAYS.
  ///
  /// The rail was a fixed 232px while its labels followed the OS text scale,
  /// so with text enlarged the labels grew and the space they lived in did
  /// not. It scales with them, capped: past a point a navigation rail that
  /// keeps widening is taking the work area hostage, and collapsing to icons
  /// is the better answer than a rail half the window wide.
  static double railWidth(BuildContext context) {
    final scale = MediaQuery.of(context).textScaler.scale(14) / 14;
    // Capped low. Measured on the founder's machine at 1.75x the rail took
    // 27% of a 1265pt window, which is a navigation bar wearing the work
    // area's clothes. Labels stay legible because the type scale grew with
    // them; the rail only has to grow enough to hold the longest one.
    return 232 * scale.clamp(1.0, 1.25);
  }

  /// WHETHER THE RAIL SHOWS LABELS.
  ///
  /// Deliberately NOT sizeOf. That divides by the text scale because content
  /// decisions are about how much fits, and at 1.75x a 1600px window reads as
  /// 914 — under the two-pane threshold, so the rail collapsed to icons on a
  /// wide desktop monitor and took the destination labels and the business
  /// identity with it.
  ///
  /// The rail is not content. The question it has to answer is whether the
  /// work beside it still has room once the rail has taken what it needs, and
  /// that is a question about real pixels.
  static bool railIsCollapsed(BuildContext context, double available) {
    return available < railWidth(context) + 560;
  }

  /// PHONE IS A SHAPE. THE REST IS A QUESTION OF HOW MUCH FITS.
  ///
  /// Every boundary used to be measured in effective width — real width
  /// divided by the OS text scale — and for the upper boundaries that is
  /// right: how many panes fit beside each other genuinely depends on how
  /// large the text is.
  ///
  /// Applying it to the phone boundary was wrong, and measurably so. On this
  /// machine a 1582px desktop window is 1265.6 logical pixels at a device
  /// pixel ratio of 1.25, and with the OS enlarging text 1.75x that came out
  /// as 723 effective — under the 760 phone boundary. So the workspace
  /// classified a desktop monitor as a phone: bottom navigation bar, app bar,
  /// no rail, single stacked column. That is not a workspace that FEELS like
  /// an enlarged phone; it is one that has decided it IS a phone.
  ///
  /// Whether there is a pointer, a keyboard and a window manager is not a
  /// function of type size. Somebody who enlarges text on a desktop wants
  /// larger text, not a different product — so structure follows the real
  /// viewport, and only the density decisions above it follow the text.
  static WorkspaceSize sizeOf(BuildContext context, [double? available]) {
    final raw = available ?? MediaQuery.of(context).size.width;
    if (raw < phone) return WorkspaceSize.phone;

    final w = effectiveWidth(context, available);
    if (w < twoPane) return WorkspaceSize.compact;
    if (w < threePane) return WorkspaceSize.wide;
    return WorkspaceSize.extraWide;
  }
}

enum WorkspaceSize {
  /// One pane. Navigation pushes; the inspector is a sheet.
  phone,

  /// One pane with a nav rail. The list and the work take turns.
  compact,

  /// List beside work. The inspector overlays.
  wide,

  /// List, work and inspector together.
  extraWide;

  bool get isPhone => this == WorkspaceSize.phone;
  bool get canShowList => index >= WorkspaceSize.wide.index;
  bool get canShowInspector => this == WorkspaceSize.extraWide;
}

/// Compact orientation for a primary destination.
///
/// Deliberately small. The construction this replaces spent roughly 250–350px
/// of vertical space, on every surface, restating the account's lifecycle to
/// someone who had already signed in — before any of their work appeared.
class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.title,
    this.context_,
    this.trailing,
    this.onBack,
  });

  final String title;

  /// Only current state, a blocker, or something that changes what to do next.
  /// Never plan, tier, onboarding status or targeting mode.
  final String? context_;

  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                onPressed: onBack,
                icon: Icon(Icons.arrow_back, size: Workspace.icon(context, 20)),
                visualDensity: VisualDensity.compact,
                tooltip: 'Back',
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                if (context_ != null && context_!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      context_!,
                      style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A titled band of work — the unit Today is built from.
///
/// A band with nothing in it renders nothing at all, not an empty container
/// with a heading. Silence is the correct rendering of a healthy system.
class WorkspaceBand extends StatelessWidget {
  const WorkspaceBand({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    // A BAND IS A SURFACE, NOT A HEADING WITH ROWS UNDER IT.
    //
    // This used to be a label and a list painted straight onto the page, which
    // is why the workspace read as a flat document however carefully the rows
    // were composed: nothing was contained by anything, so nothing had weight,
    // and the eye had no structure to move between.
    //
    // Containment is the cheapest depth there is and the one an operational
    // surface can actually afford. The band lifts to the working surface, the
    // canvas shows around it, and a hairline closes it — no shadow, because at
    // this density a shadow under every group blurs the grid it is supposed to
    // clarify.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Ws.surface,
          borderRadius: BorderRadius.circular(Ws.radiusLarge),
          border: Border.all(color: Ws.hairline),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The label belongs to the surface it heads, so it sits inside it on
          // a slightly recessed strip rather than floating above it.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            decoration: BoxDecoration(
              color: Ws.surfaceSoft,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Ws.radiusLarge)),
              border: const Border(
                  bottom: BorderSide(color: Ws.hairline)),
            ),
            child: Row(
            children: [
              // Flexible, because a band title is written for what the band
              // contains and not for the width it gets. Unconstrained beside a
              // Spacer, any title longer than the viewport overflows the row —
              // which is a red-and-yellow stripe across a real workspace, and
              // it waited here until a title happened to be long enough.
              //
              // Wrapping rather than ellipsis: these titles are the only label
              // the band has, and half of one is not a heading.
              Flexible(
                child: Text(
                  title,
                  style: text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subtitle!,
                    style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
                  ),
                ),
              ] else
                const Spacer(),
              if (trailing != null) trailing!,
            ],
            ),
          ),
          // SEPARATION BELONGS TO THE CONTAINER, NOT TO EACH ROW.
          //
          // A row that draws its own bottom rule puts one against the panel
          // edge when it happens to be last, which reads as a double line and
          // is the sort of thing that makes a careful surface look careless.
          // The band knows which row is last; a row does not.
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1),
            _BandScope(child: children[i]),
          ],
        ],
        ),
      ),
    );
  }
}

/// Marks a subtree as living inside a band, so rows can stop drawing their own
/// separation and let the band place it.
class _BandScope extends InheritedWidget {
  const _BandScope({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BandScope>() != null;

  @override
  bool updateShouldNotify(_BandScope oldWidget) => false;
}

/// One line of work: what happened, and what resolves it.
///
/// A list row rather than a card. Cards are for containment, and a queue of
/// eight cards is a wall, not a queue.
class WorkspaceRow extends StatelessWidget {
  const WorkspaceRow({
    super.key,
    required this.title,
    this.detail,
    this.meta,
    this.leading,
    this.action,
    this.onTap,
    this.tone = RowTone.neutral,
  });

  final String title;
  final String? detail;
  final String? meta;
  final Widget? leading;
  final Widget? action;
  final VoidCallback? onTap;
  final RowTone tone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            border: _BandScope.of(context)
                ? null
                : const Border(bottom: BorderSide(color: Ws.hairline)),
          ),
          // Meta sits beside the title where there is room and underneath it
          // where there is not. It used to be an unconstrained child of this
          // Row, so a real sender address overflowed a phone by 167px — the
          // content was simply off the edge of the screen.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < Workspace.phone;
              final metaText = meta == null
                  ? null
                  : Text(
                      meta!,
                      style: text.bodySmall
                          ?.copyWith(color: AppTheme.publicMuted),
                      softWrap: narrow,
                      overflow:
                          narrow ? TextOverflow.clip : TextOverflow.ellipsis,
                    );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ToneMark(tone: tone),
                  if (leading != null) ...[const SizedBox(width: 10), leading!],
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: text.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        if (detail != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(detail!,
                                style: text.bodySmall
                                    ?.copyWith(color: AppTheme.publicMuted)),
                          ),
                        if (narrow && metaText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: metaText,
                          ),
                      ],
                    ),
                  ),
                  if (!narrow && metaText != null) ...[
                    const SizedBox(width: 12),
                    // Bounded, so a long sender address shortens instead of
                    // pushing the row off the screen.
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: constraints.maxWidth * 0.32),
                      child: metaText,
                    ),
                  ],
                  if (action != null) ...[const SizedBox(width: 12), action!],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum RowTone { neutral, waiting, attention, problem, good }

class _ToneMark extends StatelessWidget {
  const _ToneMark({required this.tone});

  final RowTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      RowTone.attention => AppTheme.amber,
      RowTone.problem => AppTheme.rose,
      RowTone.good => AppTheme.emerald,
      RowTone.waiting => AppTheme.publicMuted.withValues(alpha: 0.5),
      RowTone.neutral => Colors.transparent,
    };
    return Container(
      width: 3,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// What a surface says when there is genuinely nothing to do.
///
/// Small and plain. A large card announcing that no action is needed is itself
/// a demand for attention, which is the opposite of what it claims.
class QuietState extends StatelessWidget {
  const QuietState({super.key, required this.message, this.hint});

  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Nothing to say is said with nothing.
    if (message.isEmpty && (hint == null || hint!.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message,
              style: text.bodyMedium?.copyWith(color: AppTheme.publicMuted)),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(hint!,
                  style: text.bodySmall?.copyWith(
                      color: AppTheme.publicMuted.withValues(alpha: 0.8))),
            ),
        ],
      ),
    );
  }
}

/// A grouped area inside a destination — used by Business and Account, where
/// several settled capabilities live together without each earning a
/// navigation slot.
class WorkspaceSection extends StatelessWidget {
  const WorkspaceSection({
    super.key,
    required this.title,
    required this.description,
    required this.children,
    this.icon,
  });

  final String title;
  final String description;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: Workspace.icon(context, 16), color: AppTheme.publicMuted),
                const SizedBox(width: 8),
              ],
              Text(title,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: EdgeInsets.only(left: icon != null ? 24 : 0),
            child: Text(description,
                style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
