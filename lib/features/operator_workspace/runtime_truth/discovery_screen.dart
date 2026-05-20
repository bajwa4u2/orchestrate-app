import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../models/discovery_models.dart';
import '../repositories/operator_learning_repository.dart';
import '../widgets/operator_panel.dart';

/// Signal sources — market-intelligence acquisition visibility.
///
/// Operator-only. Surfaces source coverage, per-source health and
/// acquisition rates, and executable-inventory quality. Clients
/// never see this — they see outcome momentum, not crawler
/// internals.
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryData {
  const _DiscoveryData({required this.sources, required this.inventory});
  final DiscoverySourcesView sources;
  final DiscoveryInventoryView inventory;
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final OperatorLearningRepository _repo = OperatorLearningRepository();
  Future<_DiscoveryData>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  Future<_DiscoveryData> _load() async {
    final results = await Future.wait([
      _repo.fetchDiscoverySources(),
      _repo.fetchDiscoveryInventory(),
    ]);
    return _DiscoveryData(
      sources: results[0] as DiscoverySourcesView,
      inventory: results[1] as DiscoveryInventoryView,
    );
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
                  Text('Runtime Truth',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppTheme.subdued)),
                  const SizedBox(height: 4),
                  Text('Signal sources',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Continuous market-intelligence acquisition — source '
                    'coverage, health, and executable-inventory quality.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.muted, height: 1.35),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, color: AppTheme.muted),
              onPressed: _refresh,
            ),
          ],
        ),
        const SizedBox(height: 18),
        FutureBuilder<_DiscoveryData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return OperatorErrorState(
                title: 'Discovery surface unavailable',
                detail: '${snapshot.error}',
                onRetry: _refresh,
              );
            }
            final data = snapshot.data!;
            return Column(
              children: [
                _InventoryPanel(inventory: data.inventory),
                const SizedBox(height: 18),
                _SourcesPanel(sources: data.sources),
                const SizedBox(height: 28),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({required this.inventory});
  final DiscoveryInventoryView inventory;

  @override
  Widget build(BuildContext context) {
    final state = inventory.byState;
    return OperatorPanel(
      title: 'Executable inventory',
      subtitle:
          'Opportunity inventory the discovery engine keeps replenished.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 200,
                child: OperatorMetricTile(
                  label: 'Executable inventory',
                  value: '${inventory.executableInventory}',
                  tone: inventory.executableInventory > 0
                      ? OperatorTone.positive
                      : OperatorTone.caution,
                ),
              ),
              SizedBox(
                width: 200,
                child: OperatorMetricTile(
                  label: 'Total opportunities',
                  value: '${inventory.total}',
                ),
              ),
              SizedBox(
                width: 200,
                child: OperatorMetricTile(
                  label: 'Fresh',
                  value: '${inventory.fresh}',
                  tone: OperatorTone.positive,
                ),
              ),
              SizedBox(
                width: 200,
                child: OperatorMetricTile(
                  label: 'Aging',
                  value: '${inventory.aging}',
                  tone: OperatorTone.caution,
                ),
              ),
              SizedBox(
                width: 200,
                child: OperatorMetricTile(
                  label: 'Stale (decayed)',
                  value: '${inventory.stale}',
                  tone: OperatorTone.neutral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in state.entries)
                _StateChip(label: entry.key, value: entry.value),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(
        '$label · $value',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppTheme.muted, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SourcesPanel extends StatelessWidget {
  const _SourcesPanel({required this.sources});
  final DiscoverySourcesView sources;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Source coverage',
      subtitle:
          '${sources.configuredCount} of ${sources.totalCount} connectors configured. '
          'Public / open sources need no key; the engine runs without the paid source.',
      child: sources.sources.isEmpty
          ? const OperatorEmptyState(
              title: 'No connectors registered',
              body: 'The discovery engine has no signal connectors.',
            )
          : Column(
              children: [
                for (var i = 0; i < sources.sources.length; i++) ...[
                  _SourceRow(
                    source: sources.sources[i],
                    stat: sources.statFor(sources.sources[i].kind),
                  ),
                  if (i != sources.sources.length - 1)
                    const Divider(height: 18),
                ],
              ],
            ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.stat});
  final DiscoverySourceRow source;
  final DiscoverySourceStat? stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = stat;
    final detail = s == null
        ? 'No runs yet this process.'
        : '${s.runs} run(s) · ${s.candidatesAcquired} acquired · '
            '${s.cacheHits} cache hit(s) · ${s.errors} error(s)';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(source.displayName,
                    style: theme.textTheme.titleMedium),
              ),
              _Tag(
                label: source.paid ? 'PAID' : 'PUBLIC',
                tone: source.paid
                    ? OperatorTone.caution
                    : OperatorTone.positive,
              ),
              const SizedBox(width: 6),
              _Tag(label: source.role.toUpperCase(), tone: OperatorTone.neutral),
              const SizedBox(width: 6),
              _Tag(
                label: source.configured ? 'CONFIGURED' : 'NOT CONFIGURED',
                tone: source.configured
                    ? OperatorTone.positive
                    : OperatorTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
              )),
          if (!source.configured && source.requiresConfig.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text('Needs: ${source.requiresConfig.join(', ')}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.subdued)),
          ],
          if (s?.lastError != null) ...[
            const SizedBox(height: 3),
            Text('Last error: ${s!.lastError}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.rose)),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.tone});
  final String label;
  final OperatorTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      OperatorTone.positive => AppTheme.emerald,
      OperatorTone.caution => AppTheme.amber,
      OperatorTone.critical => AppTheme.rose,
      OperatorTone.neutral => AppTheme.subdued,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}
