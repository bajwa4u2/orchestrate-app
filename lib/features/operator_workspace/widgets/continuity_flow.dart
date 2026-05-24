import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/widgets/substrate_chip.dart';
import '../models/cognition_models.dart';

/// Continuity Flow — renders the dispatch flow as the directed
/// stage sequence it actually is in substrate:
///
///   IN_FLIGHT  →  SENT (last hour)
///                ↘ FAILED (last hour)
///                ↘ BLOCKED (by reason)
///                ↘ JOBS_QUEUED → JOBS_FAILED → RECOVERING
///
/// Each stage carries a deterministic count from
/// `ContinuityHealth`; blocked work breaks out by the canonical
/// error-category set the backend reports (BOUNCE / RATE_LIMIT /
/// AUTH / TRANSPORT / DNS / GOVERNANCE / OTHER / UNCLASSIFIED).
/// The widget composes data already loaded by
/// `OperatorCognitionRepository.fetchContinuitySummary()` and the
/// blocked-work map; it makes no new requests and invents no state.
///
/// Doctrine mirror — OR-01 §6 (Continuity flow) + the recovery
/// loop in the readiness machine. Blocked work is always typed by
/// the categorizer; an unknown category surfaces as
/// `UNCLASSIFIED`, never coerced.
class ContinuityFlow extends StatelessWidget {
  const ContinuityFlow({super.key, required this.summary});

  final ContinuityHealth summary;

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
          Text(
            'Continuity flow',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            'Where dispatch is, by stage. Recovery activity loops back into in-flight; blocked work is broken out by the canonical error categories.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          _StageRow(
            stages: [
              _Stage('IN FLIGHT', summary.inFlight, SubstrateChipState.teal),
              _Stage(
                'SENT · LAST HOUR',
                summary.sentLastHour,
                SubstrateChipState.verdant,
              ),
              _Stage(
                'FAILED · LAST HOUR',
                summary.failedLastHour,
                summary.failedLastHour == 0
                    ? SubstrateChipState.mist
                    : SubstrateChipState.sun,
              ),
              _Stage(
                'JOBS QUEUED',
                summary.jobsPending,
                SubstrateChipState.teal,
              ),
              _Stage(
                'JOBS FAILED',
                summary.jobsFailed,
                summary.jobsFailed == 0
                    ? SubstrateChipState.mist
                    : SubstrateChipState.rose,
              ),
              _Stage(
                'RECOVERY · 24H',
                summary.recoveringActionsLast24h,
                SubstrateChipState.sun,
              ),
            ],
          ),
          if (summary.blockedTotal > 0) ...[
            const SizedBox(height: 14),
            _BlockedBreakdown(reasons: summary.blockedByReason),
          ],
        ],
      ),
    );
  }
}

class _Stage {
  const _Stage(this.label, this.count, this.state);
  final String label;
  final int count;
  final SubstrateChipState state;
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stages});
  final List<_Stage> stages;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 8,
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          SubstrateChip(
            label: '${stages[i].label} · ${stages[i].count}',
            state: stages[i].state,
            dimmed: stages[i].count == 0,
          ),
          if (i < stages.length - 1)
            Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: AppTheme.coTeal.withValues(alpha: 0.55),
            ),
        ],
      ],
    );
  }
}

class _BlockedBreakdown extends StatelessWidget {
  const _BlockedBreakdown({required this.reasons});

  final Map<String, int> reasons;

  static const _orderedCategories = [
    'BOUNCE',
    'RATE_LIMIT',
    'AUTH',
    'TRANSPORT',
    'DNS',
    'GOVERNANCE',
    'OTHER',
    'UNCLASSIFIED',
  ];

  SubstrateChipState _stateFor(String category) {
    switch (category) {
      case 'GOVERNANCE':
        return SubstrateChipState.teal;
      case 'UNCLASSIFIED':
        return SubstrateChipState.mist;
      default:
        return SubstrateChipState.rose;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _orderedCategories
        .map((c) => MapEntry(c, reasons[c] ?? 0))
        .where((e) => e.value > 0)
        .toList(growable: false);
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BLOCKED BY CATEGORY',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.subdued,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in entries)
              SubstrateChip(
                label: '${e.key} · ${e.value}',
                state: _stateFor(e.key),
              ),
          ],
        ),
      ],
    );
  }
}
