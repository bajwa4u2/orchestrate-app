import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/widgets/substrate_chip.dart';

/// Intervention Authority Ribbon — names the four canonical
/// governance authority modes in order, so an operator landing on a
/// governance surface sees *what authority a given action sits
/// under* before they see any actions:
///
///   AUTONOMOUS   →  the substrate may act without operator approval
///   SUPERVISED   →  substrate acts; operator can intervene mid-flight
///   APPROVAL_REQUIRED → substrate proposes; operator authorizes
///   REFUSED      →  substrate refuses; no operator override
///
/// This is intentionally static — it is the authority canon
/// rendered visibly. Per OPERATIONAL_FULFILLMENT_DIRECTIVE the
/// approval queue itself ships later; this ribbon ensures the
/// authority register is visible even before the queue exists.
///
/// Doctrine mirror — OR-02 §4 (Operational Enforcement Pipeline).
class InterventionAuthorityRibbon extends StatelessWidget {
  const InterventionAuthorityRibbon({super.key});

  static const _modes = [
    _AuthorityMode(
      label: 'AUTONOMOUS',
      caption: 'Substrate acts within bounded policy; no operator hand-off.',
      state: SubstrateChipState.teal,
    ),
    _AuthorityMode(
      label: 'SUPERVISED',
      caption:
          'Substrate acts; operator retains a stop-the-line intervention.',
      state: SubstrateChipState.teal,
    ),
    _AuthorityMode(
      label: 'APPROVAL_REQUIRED',
      caption:
          'Substrate proposes; an operator-authorized decision is required.',
      state: SubstrateChipState.sun,
    ),
    _AuthorityMode(
      label: 'REFUSED',
      caption:
          'Substrate refuses. Floor-level refusal — no operator override.',
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
            'Intervention authority',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            'Every governed action sits under one of four authority modes. Refused is floor-level — no operator override exists.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _modes.length; i++) ...[
            _ModeRow(mode: _modes[i]),
            if (i < _modes.length - 1)
              Divider(
                color: AppTheme.lineSoft.withValues(alpha: 0.6),
                height: 18,
              ),
          ],
        ],
      ),
    );
  }
}

class _AuthorityMode {
  const _AuthorityMode({
    required this.label,
    required this.caption,
    required this.state,
  });

  final String label;
  final String caption;
  final SubstrateChipState state;
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.mode});
  final _AuthorityMode mode;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: SubstrateChip(label: mode.label, state: mode.state),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              mode.caption,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}
