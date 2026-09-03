import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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

  static WorkspaceSize sizeOf(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < phone) return WorkspaceSize.phone;
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
                icon: const Icon(Icons.arrow_back, size: 20),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
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
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.publicLine.withValues(alpha: 0.6)),
            ),
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
                Icon(icon, size: 16, color: AppTheme.publicMuted),
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
