import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/widgets/substrate_chip.dart';
import '../models/learning_models.dart';
import '../repositories/operator_learning_repository.dart';
import '../widgets/operator_panel.dart';

/// Runtime patterns. Read-only — status (CANDIDATE / CONFIRMED) is
/// automatic at threshold; this surface lets operators inspect.
class PatternsScreen extends StatefulWidget {
  const PatternsScreen({super.key});

  @override
  State<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends State<PatternsScreen> {
  final OperatorLearningRepository _repo = OperatorLearningRepository();
  Future<List<RuntimePatternEntry>>? _future;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() =>
        _future = _repo.listPatterns(status: _statusFilter, limit: 100));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adaptation',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppTheme.subdued)),
                  const SizedBox(height: 4),
                  Text('Runtime patterns',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                      'Aggregated, deterministic patterns derived from LearningEvents. CANDIDATE promotes to CONFIRMED at threshold automatically — operators read, not edit.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.muted, height: 1.35)),
                ],
              ),
            ),
            DropdownButton<String?>(
              value: _statusFilter,
              dropdownColor: AppTheme.panel,
              style: const TextStyle(color: AppTheme.text),
              iconEnabledColor: AppTheme.subdued,
              underline: const SizedBox.shrink(),
              hint: const Text('All statuses',
                  style: TextStyle(color: AppTheme.subdued)),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('All')),
                DropdownMenuItem<String?>(
                    value: 'CANDIDATE', child: Text('CANDIDATE')),
                DropdownMenuItem<String?>(
                    value: 'CONFIRMED', child: Text('CONFIRMED')),
                DropdownMenuItem<String?>(
                    value: 'EXPIRED', child: Text('EXPIRED')),
              ],
              onChanged: (v) {
                setState(() => _statusFilter = v);
                _refresh();
              },
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, color: AppTheme.muted),
              onPressed: _refresh,
            ),
          ],
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<RuntimePatternEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))));
            }
            if (snapshot.hasError) {
              return OperatorErrorState(
                  title: 'Patterns endpoint failed',
                  detail: '${snapshot.error}',
                  onRetry: _refresh);
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const OperatorEmptyState(
                title: 'No runtime patterns detected',
                body:
                    'The aggregator has not produced rows for this filter. CANDIDATEs accumulate; CONFIRMEDs appear at threshold.',
              );
            }
            return Column(
              children: [for (final p in items) _PatternCard(item: p)],
            );
          },
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.item});
  final RuntimePatternEntry item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.label,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              _StatusChip(status: item.status),
              const SizedBox(width: 6),
              _SentimentChip(sentiment: item.sentiment),
            ],
          ),
          const SizedBox(height: 6),
          Text(
              'Signal: ${item.signal} · scope ${item.scope} · ${item.occurrences} observations in ${item.windowSeconds}s window',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.muted)),
          const SizedBox(height: 6),
          Text(
              'First observed ${item.firstObservedAt.toIso8601String()} · last ${item.lastObservedAt.toIso8601String()}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.subdued)),
        ],
      ),
    );
  }
}

/// Pattern lifecycle status rendered as a canonical SubstrateChip.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final state = switch (status) {
      'CONFIRMED' => SubstrateChipState.verdant,
      'EXPIRED' => SubstrateChipState.mist,
      _ => SubstrateChipState.sun,
    };
    return SubstrateChip(label: status, state: state);
  }
}

/// Reply-sentiment typed enum rendered as a canonical SubstrateChip.
class _SentimentChip extends StatelessWidget {
  const _SentimentChip({required this.sentiment});
  final String sentiment;

  @override
  Widget build(BuildContext context) {
    final state = switch (sentiment) {
      'POSITIVE' => SubstrateChipState.verdant,
      'NEGATIVE' => SubstrateChipState.rose,
      _ => SubstrateChipState.mist,
    };
    return SubstrateChip(label: sentiment, state: state);
  }
}
