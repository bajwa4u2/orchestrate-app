import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/widgets/substrate_chip.dart';

/// Enforcement Cascade Lane — renders the canonical ten-gate
/// hardest-first enforcement cascade per OR-02 §5. Every governed
/// action must pass each gate in order; the first refusal wins
/// and downstream gates are not evaluated.
///
///   01  REFUSAL_FLOOR        →  governance hard-floor (no AI override)
///   02  IDENTITY_VERIFIED    →  caller identity / role verified
///   03  AUTHORITY_SCOPED     →  action sits within delegated authority
///   04  POLICY_ELIGIBLE      →  policy admits the action class
///   05  RECIPIENT_OPT_IN     →  recipient consent / opt-in present
///   06  RATE_BUDGETED        →  rate / cadence budget unspent
///   07  CONTENT_REVIEWED     →  content passed review gates
///   08  PROVENANCE_INTACT    →  provenance + audit chain attached
///   09  DELIVERY_HEALTHY     →  transport / DNS / mailbox healthy
///   10  RECOVERY_RESERVED    →  recovery capacity reserved if needed
///
/// The lane visualizes the cascade as a numbered, hardest-first
/// ordered list. Each gate is a `SubstrateChip` in teal — the canon
/// is the canon. When per-gate evaluation counts ship, the chips
/// can carry pass/refuse counts without changing the order.
///
/// Doctrine mirror — OR-02 §5 (10-gate cascade) +
/// `system/enforcement/enforcement-grammar.md` §3 (hardest-first
/// + first-refusal-wins).
class EnforcementCascadeLane extends StatelessWidget {
  const EnforcementCascadeLane({super.key});

  static const _gates = [
    'REFUSAL_FLOOR',
    'IDENTITY_VERIFIED',
    'AUTHORITY_SCOPED',
    'POLICY_ELIGIBLE',
    'RECIPIENT_OPT_IN',
    'RATE_BUDGETED',
    'CONTENT_REVIEWED',
    'PROVENANCE_INTACT',
    'DELIVERY_HEALTHY',
    'RECOVERY_RESERVED',
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
            'Enforcement cascade',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            'Ten gates, hardest-first. First refusal wins; downstream gates are not evaluated. Risk escalates only — no silent downgrade.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _gates.length; i++) ...[
            _GateRow(index: i + 1, gate: _gates[i]),
            if (i < _gates.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _GateRow extends StatelessWidget {
  const _GateRow({required this.index, required this.gate});

  final int index;
  final String gate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 28,
          child: Text(
            index.toString().padLeft(2, '0'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.subdued,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  fontFamily: 'monospace',
                ),
          ),
        ),
        const SizedBox(width: 8),
        SubstrateChip(label: gate, state: SubstrateChipState.teal),
      ],
    );
  }
}
