import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/widgets/substrate_chip.dart';

/// Readiness Path — renders the canonical seven-bucket readiness
/// machine as the directed path it actually is in substrate:
///
///   READY_TO_EXECUTE → EXECUTING → ORCHESTRATE_WORKING
///                       ↘ DEGRADED ↘ RECOVERING ↘ (loop back)
///                       ↘ CLIENT_ACTION_REQUIRED
///                       ↘ ORCHESTRATE_BLOCKED_INTERNAL
///
/// Each bucket carries the deterministic-classifier count from
/// `ReadinessBoard.totals`. Inactive buckets dim to 30% so the
/// "what's actually happening right now" silhouette is legible at
/// a glance. The widget composes data already loaded by
/// `OperatorCognitionRepository.fetchReadinessBoard()`; it makes
/// no new requests and invents no state.
///
/// Doctrine mirror — OR-01 §3 (Diagnostics & Readiness Topology).
/// Each transition is a deterministic classifier call, never a
/// model guess. Per the runtime-truth doctrine, an unevaluated
/// client classifies into a substrate state, never a synthesized
/// "OK".
class ReadinessPath extends StatelessWidget {
  const ReadinessPath({super.key, required this.totals});

  final Map<String, int> totals;

  static const _greenPath = [
    _Bucket('ready_to_execute', 'Ready to execute', SubstrateChipState.verdant),
    _Bucket('executing', 'Executing', SubstrateChipState.teal),
    _Bucket('orchestrate_working', 'Working', SubstrateChipState.teal),
  ];

  static const _recoveryPath = [
    _Bucket('degraded', 'Degraded', SubstrateChipState.sun),
    _Bucket('recovering', 'Recovering', SubstrateChipState.sun),
  ];

  static const _blockedPath = [
    _Bucket('client_action_required', 'Client action required',
        SubstrateChipState.rose),
    _Bucket('orchestrate_blocked_internal', 'Blocked (internal)',
        SubstrateChipState.rose),
  ];

  int _count(String key) => totals[key] ?? 0;

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
          Text('Readiness path', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            'Deterministic classifier path. Green path runs left to right; degraded states loop back through recovery; blocked states peel off to dedicated lanes.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          _PathRow(label: 'GREEN PATH', buckets: _greenPath, count: _count),
          const SizedBox(height: 10),
          _PathRow(label: 'RECOVERY', buckets: _recoveryPath, count: _count),
          const SizedBox(height: 10),
          _PathRow(label: 'BLOCKED', buckets: _blockedPath, count: _count),
        ],
      ),
    );
  }
}

class _Bucket {
  const _Bucket(this.key, this.label, this.state);
  final String key;
  final String label;
  final SubstrateChipState state;
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.label,
    required this.buckets,
    required this.count,
  });

  final String label;
  final List<_Bucket> buckets;
  final int Function(String key) count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.subdued,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 8,
            children: [
              for (var i = 0; i < buckets.length; i++) ...[
                _BucketNode(bucket: buckets[i], count: count(buckets[i].key)),
                if (i < buckets.length - 1)
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppTheme.coTeal.withValues(alpha: 0.55),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BucketNode extends StatelessWidget {
  const _BucketNode({required this.bucket, required this.count});

  final _Bucket bucket;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SubstrateChip(
      label: '${bucket.label} · $count',
      state: bucket.state,
      dimmed: count == 0,
    );
  }
}
