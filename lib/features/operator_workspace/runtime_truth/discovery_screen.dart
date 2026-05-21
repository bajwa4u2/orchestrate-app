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
  final TextEditingController _campaignCtl = TextEditingController();
  Future<_DiscoveryData>? _future;
  // When set, source coverage is fetched for this campaign and carries
  // its reply-learning source down-rank.
  String _scopedCampaignId = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _campaignCtl.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  void _applyCampaignScope() {
    setState(() {
      _scopedCampaignId = _campaignCtl.text.trim();
      _future = _load();
    });
  }

  Future<_DiscoveryData> _load() async {
    final cid = _scopedCampaignId;
    final results = await Future.wait([
      _repo.fetchDiscoverySources(campaignId: cid.isEmpty ? null : cid),
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
        const SizedBox(height: 14),
        Row(
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                controller: _campaignCtl,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Campaign scope (optional)',
                  hintText: 'Campaign ID — reveals reply-learning down-rank',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _applyCampaignScope(),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _applyCampaignScope,
              child: Text(_scopedCampaignId.isEmpty ? 'Apply scope' : 'Update'),
            ),
            if (_scopedCampaignId.isNotEmpty) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  _campaignCtl.clear();
                  _applyCampaignScope();
                },
                child: const Text('Clear'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
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
                const SizedBox(height: 18),
                const _RefillInspectorPanel(),
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
          'Public / open sources need no key; the engine runs without the paid source.'
          '${sources.campaignScoped ? ' Campaign-scoped — reply-learning source down-rank shown below.' : ' Enter a campaign scope above to see reply-learning source down-rank.'}',
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
              if (source.sourceLearning?.downRanked == true) ...[
                const SizedBox(width: 6),
                _Tag(
                  label:
                      'DOWN-RANKED ×${source.sourceLearning!.multiplier.toStringAsFixed(2)}',
                  tone: OperatorTone.caution,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
              )),
          if (source.sourceLearning != null) ...[
            const SizedBox(height: 3),
            Text(
              source.sourceLearning!.downRanked
                  ? 'Reply learning: '
                      '${(source.sourceLearning!.negativeRate * 100).round()}% negative '
                      'across ${source.sourceLearning!.observations} '
                      'repl${source.sourceLearning!.observations == 1 ? 'y' : 'ies'} — '
                      'acquisition share reduced to '
                      '×${source.sourceLearning!.multiplier.toStringAsFixed(2)}.'
                  : 'Reply learning: no down-rank — '
                      '${source.sourceLearning!.observations} '
                      'repl${source.sourceLearning!.observations == 1 ? 'y' : 'ies'} observed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: source.sourceLearning!.downRanked
                    ? AppTheme.amber
                    : AppTheme.muted,
              ),
            ),
          ],
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

/// Per-campaign autonomous refill runtime truth — the governor
/// decision (why discovery did / did not activate) and the
/// stage-by-stage trace of the last real run.
class _RefillInspectorPanel extends StatefulWidget {
  const _RefillInspectorPanel();

  @override
  State<_RefillInspectorPanel> createState() => _RefillInspectorPanelState();
}

class _RefillInspectorPanelState extends State<_RefillInspectorPanel> {
  final OperatorLearningRepository _repo = OperatorLearningRepository();
  final TextEditingController _campaignCtrl = TextEditingController();
  DiscoveryRefillView? _result;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _campaignCtrl.dispose();
    super.dispose();
  }

  Future<void> _inspect() async {
    final id = _campaignCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final view = await _repo.fetchDiscoveryRefill(campaignId: id);
      if (!mounted) return;
      setState(() {
        _result = view;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    return OperatorPanel(
      title: 'Refill activation truth',
      subtitle:
          'Why discovery did or did not activate for a campaign — '
          'governor decision + the last run trace.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _campaignCtrl,
                  style: const TextStyle(color: AppTheme.text),
                  decoration: InputDecoration(
                    labelText: 'Campaign ID',
                    labelStyle: const TextStyle(color: AppTheme.muted),
                    filled: true,
                    fillColor: AppTheme.panelSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      borderSide: const BorderSide(color: AppTheme.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      borderSide: const BorderSide(color: AppTheme.line),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _loading ? null : _inspect,
                child: Text(_loading ? 'Inspecting…' : 'Inspect'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text('Inspection failed: $_error',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.rose)),
          ],
          if (result != null) ...[
            const SizedBox(height: 14),
            _decision(context, result),
            if (result.profile != null) ...[
              const SizedBox(height: 10),
              _profile(context, result.profile!),
            ],
            if (result.trace != null) ...[
              const SizedBox(height: 14),
              _trace(context, result.trace!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _decision(BuildContext context, DiscoveryRefillView view) {
    final d = view.decision;
    if (d == null) {
      return const OperatorEmptyState(
        title: 'No refill decision recorded yet',
        body: 'This campaign has not been evaluated for refill.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Tag(
              label: d.activate ? 'ACTIVATED' : 'SUPPRESSED',
              tone: d.activate ? OperatorTone.positive : OperatorTone.caution,
            ),
            _Tag(label: d.reason.toUpperCase(), tone: OperatorTone.neutral),
            // Discovery refill is never AI-WAIT governed — the
            // decision is always deterministic.
            _Tag(
              label: d.decisionMode.toUpperCase(),
              tone: OperatorTone.neutral,
            ),
            if (d.minimumRefillGuarantee)
              const _Tag(
                label: 'MINIMUM REFILL GUARANTEE',
                tone: OperatorTone.positive,
              ),
            if (d.overrodeAdvisoryHold)
              const _Tag(
                label: 'OVERRODE ADVISORY HOLD',
                tone: OperatorTone.positive,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(d.detail,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.muted, height: 1.35)),
        const SizedBox(height: 6),
        Text(
          'Executable inventory ${d.executableInventory} · threshold ${d.threshold}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.subdued),
        ),
      ],
    );
  }

  Widget _profile(BuildContext context, DiscoveryProfileStateView p) {
    final theme = Theme.of(context);
    final active = p.enabled && p.status.toUpperCase() == 'ACTIVE';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Tag(
          label: 'PROFILE ${p.status.toUpperCase()}',
          tone: active ? OperatorTone.positive : OperatorTone.caution,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            active
                ? 'Discovery profile is active — sourcing runs automatically.'
                : 'Discovery profile is paused; sourcing will not run until it is active.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.subdued),
          ),
        ),
      ],
    );
  }

  Widget _trace(BuildContext context, DiscoveryRefillTraceView t) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last run trace', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Acquired ${t.acquired} → after dedupe ${t.afterDedupe} '
            '(suppressed ${t.suppressed}) → eligible ${t.eligible} → '
            'promoted ${t.promotedToInventory}',
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 8),
          for (final c in t.connectors)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${c.kind} · ${c.configured ? "configured" : "not configured"} · '
                '${c.candidates} candidate(s)'
                '${c.throttled ? " · throttled" : ""}'
                '${c.error != null ? " · error: ${c.error}" : ""}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.subdued),
              ),
            ),
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
