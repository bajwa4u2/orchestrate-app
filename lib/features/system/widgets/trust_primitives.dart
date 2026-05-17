import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';

/// Shared trust-visualization primitives.
///
/// One widget library used across public + client surfaces so trust
/// state, ownership, and operational flow render with consistent
/// vocabulary. Every primitive in this file is calm, infrastructural,
/// and truthful — no greenwashing, no fake "healthy" states.
///
/// Primitives:
///   - TrustState          (enum of canonical trust states)
///   - OperationalOwnership (enum: client / orchestrate / operator)
///   - TrustStateBadge     (pill rendering a trust state)
///   - OperationalStatusPill (compact label + value pair)
///   - InfrastructureOwnershipChip (small ownership tag)
///   - ProviderTrustIndicator (provider name + state row)
///   - ConnectionFlowIndicator (linear progression bar with named steps)
///   - ReadinessBoundaryCard (card framing a single readiness boundary)
///   - TrustGuaranteePanel (a panel listing trust guarantees)
///   - PulsingDot          (subtle operational-motion indicator)

/// Canonical trust / operational state vocabulary the platform uses
/// everywhere a state pill is rendered. Mirrors the backend
/// classification but kept independent so the frontend can map any
/// numeric / string state into one of these values.
enum TrustState {
  /// Connected, verified, full trust on this layer.
  verified,

  /// In progress — DNS propagating, OAuth refresh fresh, transport
  /// settling. Not yet verified but on track.
  pending,

  /// Partial trust posture. Warmup-allowed, limited-dispatch, or a
  /// subsystem reporting degraded — the layer works at reduced
  /// capability.
  partial,

  /// Connected but not currently passing checks; reconnect or
  /// remediation required.
  degraded,

  /// Hard block — subscription, mailbox revoked, DNS regression
  /// after ACTIVE, suppression triggered for the recipient.
  blocked,

  /// Layer is currently waiting on a prerequisite layer. Not the
  /// client's action yet.
  waiting,

  /// Operator-attention state — Orchestrate owns the next step.
  operatorOwned,
}

extension TrustStateUx on TrustState {
  String get label {
    switch (this) {
      case TrustState.verified:
        return 'Verified';
      case TrustState.pending:
        return 'Pending';
      case TrustState.partial:
        return 'Partial';
      case TrustState.degraded:
        return 'Degraded';
      case TrustState.blocked:
        return 'Blocked';
      case TrustState.waiting:
        return 'Waiting';
      case TrustState.operatorOwned:
        return 'Orchestrate-owned';
    }
  }

  /// Whether the state should pulse to convey operational motion.
  /// Used by [PulsingDot]. Pending + operator-owned states pulse;
  /// terminal states do not.
  bool get shouldPulse {
    return this == TrustState.pending || this == TrustState.operatorOwned;
  }

  Color color(ThemeData theme) {
    switch (this) {
      case TrustState.verified:
        return AppTheme.publicAccent;
      case TrustState.pending:
        return theme.colorScheme.tertiary;
      case TrustState.partial:
        return theme.colorScheme.secondary;
      case TrustState.degraded:
        return theme.colorScheme.error;
      case TrustState.blocked:
        return theme.colorScheme.error;
      case TrustState.waiting:
        return theme.colorScheme.outline;
      case TrustState.operatorOwned:
        return theme.colorScheme.primary;
    }
  }
}

/// Ownership semantics — who acts on this layer next.
enum OperationalOwnership { client, orchestrate, operator }

extension OperationalOwnershipUx on OperationalOwnership {
  String get label {
    switch (this) {
      case OperationalOwnership.client:
        return 'Client';
      case OperationalOwnership.orchestrate:
        return 'Orchestrate';
      case OperationalOwnership.operator:
        return 'Operator';
    }
  }

  Color color(ThemeData theme) {
    switch (this) {
      case OperationalOwnership.client:
        return AppTheme.publicAccent;
      case OperationalOwnership.orchestrate:
        return theme.colorScheme.primary;
      case OperationalOwnership.operator:
        return theme.colorScheme.tertiary;
    }
  }
}

/// Small pulsing dot. Calm, slow rhythm — used in active-but-waiting
/// contexts to convey continuity without being attention-grabbing.
class PulsingDot extends StatefulWidget {
  const PulsingDot({
    super.key,
    required this.color,
    this.size = 8,
    this.pulse = true,
  });

  final Color color;
  final double size;
  final bool pulse;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.pulse) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulse && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = widget.pulse ? _controller.value : 0.0;
        final glowOpacity = widget.pulse ? 0.16 + (0.18 * (1 - t)) : 0.0;
        return SizedBox(
          width: widget.size * 2.4,
          height: widget.size * 2.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.pulse)
                Container(
                  width: widget.size * (1.6 + 0.8 * t),
                  height: widget.size * (1.6 + 0.8 * t),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: glowOpacity),
                    shape: BoxShape.circle,
                  ),
                ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TrustStateBadge extends StatelessWidget {
  const TrustStateBadge({
    super.key,
    required this.state,
    this.label,
    this.dense = false,
  });

  final TrustState state;
  /// Override the canonical state label.
  final String? label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = state.color(theme);
    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        border: Border.all(color: colour.withValues(alpha: 0.40)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingDot(
            color: colour,
            size: dense ? 6 : 7,
            pulse: state.shouldPulse,
          ),
          const SizedBox(width: 6),
          Text(
            label ?? state.label,
            style: (dense ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
                ?.copyWith(
              color: colour,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class InfrastructureOwnershipChip extends StatelessWidget {
  const InfrastructureOwnershipChip({super.key, required this.ownership});

  final OperationalOwnership ownership;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = ownership.color(theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        border: Border.all(color: colour.withValues(alpha: 0.40)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ownership.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colour,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class OperationalStatusPill extends StatelessWidget {
  const OperationalStatusPill({
    super.key,
    required this.label,
    required this.value,
    this.state,
  });

  final String label;
  final String value;
  final TrustState? state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = state?.color(theme) ?? AppTheme.publicMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        border: Border.all(color: AppTheme.publicLine),
        borderRadius: BorderRadius.circular(AppTheme.radius - 4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state != null) ...[
            PulsingDot(
              color: colour,
              size: 6,
              pulse: state!.shouldPulse,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            '$label  ',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: AppTheme.publicMuted),
          ),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.publicText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ProviderTrustIndicator extends StatelessWidget {
  const ProviderTrustIndicator({
    super.key,
    required this.provider,
    required this.state,
    this.detail,
  });

  /// Display name: "Google Workspace", "Microsoft 365", "Custom SMTP / IMAP".
  final String provider;
  final TrustState state;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        border: Border.all(color: AppTheme.publicLine),
        borderRadius: BorderRadius.circular(AppTheme.radius - 4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.publicMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          TrustStateBadge(state: state, dense: true),
        ],
      ),
    );
  }
}

class ConnectionFlowStep {
  const ConnectionFlowStep({
    required this.label,
    required this.state,
    this.ownership,
  });

  final String label;
  final TrustState state;
  final OperationalOwnership? ownership;
}

/// Linear progression indicator. Renders ordered steps left-to-right
/// (or stacked on narrow viewports) with a per-step pulsing node and
/// labels. Used to communicate progress through the activation chain
/// or the operational flow at a glance.
class ConnectionFlowIndicator extends StatelessWidget {
  const ConnectionFlowIndicator({super.key, required this.steps});

  final List<ConnectionFlowStep> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++)
                _FlowStepTile(
                  step: steps[i],
                  index: i,
                  isLast: i == steps.length - 1,
                  vertical: true,
                  theme: theme,
                ),
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < steps.length; i++)
              Expanded(
                child: _FlowStepTile(
                  step: steps[i],
                  index: i,
                  isLast: i == steps.length - 1,
                  vertical: false,
                  theme: theme,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FlowStepTile extends StatelessWidget {
  const _FlowStepTile({
    required this.step,
    required this.index,
    required this.isLast,
    required this.vertical,
    required this.theme,
  });

  final ConnectionFlowStep step;
  final int index;
  final bool isLast;
  final bool vertical;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colour = step.state.color(theme);
    final node = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        shape: BoxShape.circle,
        border: Border.all(color: colour, width: 2),
      ),
      child: PulsingDot(
        color: colour,
        size: 8,
        pulse: step.state.shouldPulse,
      ),
    );
    final connector = isLast
        ? const SizedBox.shrink()
        : Expanded(
            child: Container(
              height: vertical ? 18 : 2,
              width: vertical ? 2 : null,
              color: AppTheme.publicLine,
              margin: vertical
                  ? const EdgeInsets.symmetric(vertical: 4, horizontal: 13)
                  : const EdgeInsets.symmetric(horizontal: 6),
            ),
          );
    final labelBlock = Padding(
      padding: vertical
          ? EdgeInsets.fromLTRB(12, 2, 0, isLast ? 0 : 8)
          : const EdgeInsets.fromLTRB(0, 10, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. ${step.label}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.publicText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          TrustStateBadge(state: step.state, dense: true),
        ],
      ),
    );

    if (vertical) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              node,
              if (!isLast)
                Container(
                  height: 22,
                  width: 2,
                  color: AppTheme.publicLine,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
            ],
          ),
          Expanded(child: labelBlock),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            node,
            connector,
          ],
        ),
        labelBlock,
      ],
    );
  }
}

class ReadinessBoundaryCard extends StatelessWidget {
  const ReadinessBoundaryCard({
    super.key,
    required this.title,
    required this.body,
    required this.state,
    this.ownership,
    this.action,
  });

  final String title;
  final String body;
  final TrustState state;
  final OperationalOwnership? ownership;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius - 4),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TrustStateBadge(state: state, dense: true),
            ],
          ),
          if (ownership != null) ...[
            const SizedBox(height: 8),
            InfrastructureOwnershipChip(ownership: ownership!),
          ],
          const SizedBox(height: 10),
          Text(
            body,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppTheme.publicText, height: 1.45),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            action!,
          ],
        ],
      ),
    );
  }
}

class TrustGuaranteePanel extends StatelessWidget {
  const TrustGuaranteePanel({
    super.key,
    required this.title,
    required this.guarantees,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<String> guarantees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.publicMuted),
            ),
          ],
          const SizedBox(height: 14),
          for (final item in guarantees)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7, right: 12),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.publicAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.publicText,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
