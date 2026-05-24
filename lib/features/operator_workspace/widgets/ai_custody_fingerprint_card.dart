import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/widgets/substrate_chip.dart';

/// AI Custody Fingerprint Card — renders the canonical CG-03
/// AI custody flow as the five named gates it actually is in
/// substrate:
///
///   [SINGLE SEAM]
///        ↓
///   [PRE-CALL GATES]       (identity / policy / consent / budget)
///        ↓
///   [ENFORCEMENT]          (deterministic + AI-bounded action)
///        ↓
///   [POST-CALL GATES]      (provenance / refusal-record / audit)
///        ↓
///   [AUDIT]                (immutable trace; system-doctor reachable)
///
/// The card is intentionally a fingerprint, not a dashboard: it
/// makes the custody shape visible at a glance so the operator
/// can reason about defense-in-depth without drilling. The five
/// chips are canon and stable; counts can attach when the
/// per-gate evaluation endpoint ships.
///
/// Doctrine mirror — CG-03 §4 (single-seam doctrine), §5 (pre +
/// post-call gates), §7 (bounded self-correction).
class AICustodyFingerprintCard extends StatelessWidget {
  const AICustodyFingerprintCard({super.key});

  static const _stages = [
    _Stage(
      label: 'SINGLE SEAM',
      caption:
          'One canonical seam for every AI call — no shadow paths, no out-of-band invocations.',
      state: SubstrateChipState.teal,
    ),
    _Stage(
      label: 'PRE-CALL GATES',
      caption:
          'Identity, policy, consent, and budget evaluated before any model is invoked.',
      state: SubstrateChipState.teal,
    ),
    _Stage(
      label: 'ENFORCEMENT',
      caption:
          'Deterministic policy runs alongside the AI action; refusals are typed, not silent.',
      state: SubstrateChipState.sun,
    ),
    _Stage(
      label: 'POST-CALL GATES',
      caption:
          'Provenance attached, refusal records emitted, audit chain extended.',
      state: SubstrateChipState.teal,
    ),
    _Stage(
      label: 'AUDIT',
      caption:
          'Immutable trace; the system doctor is reachable from every recorded action.',
      state: SubstrateChipState.verdant,
    ),
  ];

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
            'AI custody fingerprint',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            'Defense-in-depth canon. Every AI call enters one seam, passes pre-call gates, runs alongside enforcement, exits through post-call gates, and lands in audit.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _stages.length; i++) ...[
            _StageRow(stage: _stages[i]),
            if (i < _stages.length - 1) const _StageEdge(),
          ],
        ],
      ),
    );
  }
}

class _Stage {
  const _Stage({
    required this.label,
    required this.caption,
    required this.state,
  });

  final String label;
  final String caption;
  final SubstrateChipState state;
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage});
  final _Stage stage;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: SubstrateChip(label: stage.label, state: stage.state),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              stage.caption,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}

class _StageEdge extends StatelessWidget {
  const _StageEdge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 86),
          Icon(
            Icons.arrow_downward_rounded,
            size: 14,
            color: AppTheme.coTeal.withValues(alpha: 0.55),
          ),
        ],
      ),
    );
  }
}
