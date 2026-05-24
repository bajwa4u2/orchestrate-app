import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/widgets/substrate_chip.dart';
import 'package:orchestrate_app/core/widgets/substrate_citation.dart';
import 'package:orchestrate_app/features/guidance/guidance_drawer.dart';
import '../models/cognition_models.dart';
import '../repositories/operator_cognition_repository.dart';
import '../widgets/operator_panel.dart';
import '../widgets/operator_why_affordance.dart';

/// Trust & Readiness — the canonical seven-bucket readiness board.
/// Reads /operator/readiness/board.
class TrustReadinessScreen extends StatefulWidget {
  const TrustReadinessScreen({super.key});

  @override
  State<TrustReadinessScreen> createState() => _TrustReadinessScreenState();
}

class _TrustReadinessScreenState extends State<TrustReadinessScreen> {
  final OperatorCognitionRepository _repo = OperatorCognitionRepository();
  Future<ReadinessBoard>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _future = _repo.fetchReadinessBoard());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReadinessBoard>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return OperatorErrorState(
            title: 'Readiness board unavailable',
            detail:
                'The readiness composition endpoint did not return a payload. Detail: ${snapshot.error}',
            onRetry: _refresh,
          );
        }
        return ListView(
          children: [
            _Header(asOf: snapshot.data!.asOf, onRefresh: _refresh),
            const SizedBox(height: 18),
            _BucketTotals(totals: snapshot.data!.totals),
            const SizedBox(height: 18),
            _BoardTable(rows: snapshot.data!.rows),
            const SizedBox(height: 12),
            const SubstrateCitation(
              paths: [
                'orchestrate_backend/src/operational-readiness/operational-readiness.types.ts',
                'orchestrate_backend/src/runtime-truth/runtime-truth.types.ts',
              ],
            ),
            const SizedBox(height: 28),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.asOf, required this.onRefresh});
  final DateTime asOf;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trust & Readiness',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppTheme.subdued)),
              const SizedBox(height: 4),
              Text('Readiness state board',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                  'Canonical seven-bucket readiness machine. Every client classified deterministically via OperationalReadinessService → ExecutionState → ReadinessBucket.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.muted, height: 1.35)),
              const SizedBox(height: 4),
              Text('As of ${asOf.toIso8601String()}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.subdued)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const OperatorWhyAffordance(
          target: GuidanceTarget.readiness,
          surface: 'operator_trust_readiness',
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh, color: AppTheme.muted),
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

class _BucketTotals extends StatelessWidget {
  const _BucketTotals({required this.totals});
  final Map<String, int> totals;

  static const _buckets = [
    ('executing', 'Executing', OperatorTone.positive),
    ('orchestrate_working', 'Working', OperatorTone.neutral),
    ('ready_to_execute', 'Ready to execute', OperatorTone.neutral),
    ('recovering', 'Recovering', OperatorTone.caution),
    ('degraded', 'Degraded', OperatorTone.caution),
    ('client_action_required', 'Client action required', OperatorTone.caution),
    ('orchestrate_blocked_internal',
        'Blocked (internal)', OperatorTone.critical),
  ];

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Bucket totals',
      subtitle:
          'Seven canonical buckets from operational-readiness.types.ts.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final b in _buckets)
            SizedBox(
              width: 200,
              child: OperatorMetricTile(
                label: b.$2,
                value: '${totals[b.$1] ?? 0}',
                tone: b.$3,
              ),
            ),
        ],
      ),
    );
  }
}

class _BoardTable extends StatelessWidget {
  const _BoardTable({required this.rows});
  final List<ReadinessBoardRow> rows;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Per-client classification',
      subtitle:
          'Each row is one client. The bucket is canonical; the execution state is the deterministic runtime classifier underneath it.',
      child: rows.isEmpty
          ? const OperatorEmptyState(
              title: 'No clients to classify',
              body:
                  'The organization has no client records yet — there is nothing to render here.',
            )
          : Column(
              children: [
                _RowHeader(),
                const SizedBox(height: 4),
                for (final row in rows) _Row(row: row),
              ],
            ),
    );
  }
}

class _RowHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppTheme.subdued, fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Client', style: style)),
          Expanded(flex: 2, child: Text('Readiness bucket', style: style)),
          Expanded(flex: 2, child: Text('Execution state', style: style)),
          Expanded(flex: 4, child: Text('Detail / next action', style: style)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final ReadinessBoardRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 3,
              child: Text(row.displayName,
                  style: Theme.of(context).textTheme.titleMedium)),
          Expanded(
              flex: 2,
              child: _BucketChip(bucket: row.readinessBucket)),
          Expanded(
              flex: 2,
              child: Text(row.executionState,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.muted))),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.title,
                    style: Theme.of(context).textTheme.bodyMedium),
                if (row.nextAction != null) ...[
                  const SizedBox(height: 4),
                  Text('Next: ${row.nextAction!}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.subdued)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a `CanonicalReadinessBucket` value as a canonical
/// `SubstrateChip`. Color mapping per
/// `company/visuals/system/diagnostics/diagnostics-grammar.md` §3.1.
class _BucketChip extends StatelessWidget {
  const _BucketChip({required this.bucket});
  final String bucket;

  @override
  Widget build(BuildContext context) {
    final SubstrateChipState state;
    switch (bucket) {
      case 'ready_to_execute':
        state = SubstrateChipState.verdant;
        break;
      case 'executing':
      case 'orchestrate_working':
        state = SubstrateChipState.teal;
        break;
      case 'recovering':
      case 'degraded':
        state = SubstrateChipState.sun;
        break;
      case 'client_action_required':
      case 'orchestrate_blocked_internal':
        state = SubstrateChipState.rose;
        break;
      default:
        state = SubstrateChipState.mist;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: SubstrateChip(label: bucket, state: state),
    );
  }
}
