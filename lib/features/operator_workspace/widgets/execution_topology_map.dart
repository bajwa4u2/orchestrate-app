import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/widgets/substrate_chip.dart';
import '../models/cognition_models.dart';

/// Execution Topology Map — renders the three-stage outbound
/// execution lane as it actually exists in runtime substrate:
///
///   PROVIDERS  →  MAILBOXES  →  SENDING IDENTITY
///
/// At each stage the canonical `SubstrateChip` set surfaces the
/// observed health rollup (healthy / degraded / critical / requires
/// reauth / blocked / pending). The widget composes data already
/// loaded by `OperatorCognitionRepository.fetchRuntimeTruth()`; it
/// makes no new requests and invents no state.
///
/// Doctrine mirror — Orchestrate ships substrate as three
/// independently-observable layers; deterministic green-path
/// classification requires the operator see each layer as itself,
/// not a single rolled-up "health" score. Per OR-01 §5 (Diagnostics
/// & Readiness Topology) and the runtime-truth doctrine that there
/// is exactly one truth object.
class ExecutionTopologyMap extends StatelessWidget {
  const ExecutionTopologyMap({super.key, required this.truth});

  final TruthHighlights truth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final lanes = [
                _ProvidersLane(rows: truth.providers),
                _MailboxesLane(mailboxes: truth.mailboxes),
                _SendingIdentityLane(domains: truth.sendingDomains),
              ];
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < lanes.length; i++) ...[
                      Expanded(child: lanes[i]),
                      if (i < lanes.length - 1) const _LaneEdge(),
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < lanes.length; i++) ...[
                    lanes[i],
                    if (i < lanes.length - 1) const _VerticalLaneEdge(),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Execution topology',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                'Provider → mailbox → sending identity. Each layer is independently observable; an unknown is rendered as itself.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.muted, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProvidersLane extends StatelessWidget {
  const _ProvidersLane({required this.rows});
  final List<TruthProviderRow> rows;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<int>(0, (sum, r) => sum + r.total);
    final healthy = rows.fold<int>(0, (sum, r) => sum + r.healthy);
    final degraded = rows.fold<int>(0, (sum, r) => sum + r.degraded);
    final critical = rows.fold<int>(0, (sum, r) => sum + r.critical);
    return _Lane(
      label: 'PROVIDERS',
      caption: rows.isEmpty
          ? 'No providers connected.'
          : '$total connected · ${rows.length} kind${rows.length == 1 ? '' : 's'}',
      chips: [
        _chip('$healthy healthy', SubstrateChipState.verdant, healthy > 0),
        _chip('$degraded degraded', SubstrateChipState.sun, degraded > 0),
        _chip('$critical critical', SubstrateChipState.rose, critical > 0),
      ],
    );
  }
}

class _MailboxesLane extends StatelessWidget {
  const _MailboxesLane({required this.mailboxes});
  final TruthMailboxes mailboxes;

  @override
  Widget build(BuildContext context) {
    return _Lane(
      label: 'MAILBOXES',
      caption: mailboxes.total == 0
          ? 'No mailbox records yet.'
          : '${mailboxes.total} mailbox${mailboxes.total == 1 ? '' : 'es'} on record',
      chips: [
        _chip('${mailboxes.healthy} healthy', SubstrateChipState.verdant,
            mailboxes.healthy > 0),
        _chip('${mailboxes.degraded} degraded', SubstrateChipState.sun,
            mailboxes.degraded > 0),
        _chip('${mailboxes.critical} critical', SubstrateChipState.rose,
            mailboxes.critical > 0),
        _chip('${mailboxes.requiresReauth} reauth', SubstrateChipState.sun,
            mailboxes.requiresReauth > 0),
      ],
    );
  }
}

class _SendingIdentityLane extends StatelessWidget {
  const _SendingIdentityLane({required this.domains});
  final TruthSendingDomains domains;

  @override
  Widget build(BuildContext context) {
    return _Lane(
      label: 'SENDING IDENTITY',
      caption: domains.total == 0
          ? 'No sending domains attached.'
          : '${domains.total} domain${domains.total == 1 ? '' : 's'} configured',
      chips: [
        _chip('${domains.active} active', SubstrateChipState.verdant,
            domains.active > 0),
        _chip('${domains.pending} pending', SubstrateChipState.sun,
            domains.pending > 0),
        _chip('${domains.paused} paused', SubstrateChipState.mist,
            domains.paused > 0),
        _chip('${domains.blocked} blocked', SubstrateChipState.rose,
            domains.blocked > 0),
      ],
    );
  }
}

Widget _chip(String label, SubstrateChipState state, bool active) =>
    SubstrateChip(label: label, state: state, dimmed: !active);

class _Lane extends StatelessWidget {
  const _Lane({
    required this.label,
    required this.caption,
    required this.chips,
  });

  final String label;
  final String caption;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.subdued,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    );
  }
}

class _LaneEdge extends StatelessWidget {
  const _LaneEdge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 24,
        height: 28,
        child: Center(
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: AppTheme.coTeal.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _VerticalLaneEdge extends StatelessWidget {
  const _VerticalLaneEdge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.arrow_downward_rounded,
            size: 16,
            color: AppTheme.coTeal.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}
