import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/widgets/substrate_chip.dart';

/// Dispatch Decision Strip — names the seven canonical dispatch
/// decisions that every governed action resolves into, per the
/// OR-02 Operational Enforcement Pipeline §3:
///
///   AUTONOMOUS_SEND     →  substrate dispatches without operator hand-off
///   SUPERVISED_HOLD     →  substrate proposes; operator can intervene
///   APPROVAL_REQUIRED   →  substrate proposes; operator must authorize
///   DEFER               →  substrate parks the action for a later window
///   RETRY               →  substrate re-attempts under recovery policy
///   REFUSE              →  substrate refuses (floor-level, no override)
///   ABORT               →  substrate halts and surfaces the trace
///
/// This is a canonical legend, intentionally static: it makes the
/// decision vocabulary visible to the operator even on surfaces
/// that don't (yet) carry per-action decision counts. When the
/// underlying decision-counter endpoint ships, the strip's chips
/// gain counts inline without changing the canon order.
///
/// Doctrine mirror — OR-02 §3 (dispatch decisions); the
/// risk-escalates-only doctrine in
/// `company/visuals/system/enforcement/enforcement-grammar.md` §4.
class DispatchDecisionStrip extends StatelessWidget {
  const DispatchDecisionStrip({super.key});

  static const _decisions = [
    _Decision(
      label: 'AUTONOMOUS_SEND',
      caption: 'Bounded-policy dispatch; no operator step.',
      state: SubstrateChipState.teal,
    ),
    _Decision(
      label: 'SUPERVISED_HOLD',
      caption: 'Substrate proposes; operator retains stop-the-line.',
      state: SubstrateChipState.teal,
    ),
    _Decision(
      label: 'APPROVAL_REQUIRED',
      caption: 'Operator authorization required before dispatch.',
      state: SubstrateChipState.sun,
    ),
    _Decision(
      label: 'DEFER',
      caption: 'Parked for a later policy-eligible window.',
      state: SubstrateChipState.mist,
    ),
    _Decision(
      label: 'RETRY',
      caption: 'Re-attempted under recovery policy.',
      state: SubstrateChipState.sun,
    ),
    _Decision(
      label: 'REFUSE',
      caption: 'Substrate-level refusal — no operator override.',
      state: SubstrateChipState.rose,
    ),
    _Decision(
      label: 'ABORT',
      caption: 'Halted; trace surfaced for review.',
      state: SubstrateChipState.rose,
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
            'Dispatch decisions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            'Every governed dispatch resolves into one of seven typed decisions. The canon is hardest-first; risk escalates only — never silently downgrades.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _decisions.length; i++) ...[
            _DecisionRow(decision: _decisions[i]),
            if (i < _decisions.length - 1)
              Divider(
                color: AppTheme.lineSoft.withValues(alpha: 0.5),
                height: 14,
              ),
          ],
        ],
      ),
    );
  }
}

class _Decision {
  const _Decision({
    required this.label,
    required this.caption,
    required this.state,
  });

  final String label;
  final String caption;
  final SubstrateChipState state;
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({required this.decision});
  final _Decision decision;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 200,
          child: SubstrateChip(label: decision.label, state: decision.state),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              decision.caption,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}
