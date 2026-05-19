import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../models/convergence_models.dart';
import '../repositories/operator_learning_repository.dart';
import '../widgets/operator_panel.dart';

/// Convergence metrics: tokens saved via reuse, AI calls avoided,
/// escalation rate, playbook hit-rate, recovery success rate.
/// Honest empty / null states — every number names its source.
class ConvergenceScreen extends StatefulWidget {
  const ConvergenceScreen({super.key});

  @override
  State<ConvergenceScreen> createState() => _ConvergenceScreenState();
}

class _ConvergenceScreenState extends State<ConvergenceScreen> {
  final OperatorLearningRepository _repo = OperatorLearningRepository();
  Future<ConvergenceSnapshot>? _future;
  int _window = 24 * 60 * 60;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() =>
        _future = _repo.fetchConvergenceMetrics(windowSeconds: _window));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _Header(
          windowSeconds: _window,
          onWindowChanged: (s) {
            setState(() => _window = s);
            _refresh();
          },
          onRefresh: _refresh,
        ),
        const SizedBox(height: 18),
        FutureBuilder<ConvergenceSnapshot>(
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
                  title: 'Convergence endpoint failed',
                  detail: '${snapshot.error}',
                  onRetry: _refresh);
            }
            final s = snapshot.data!;
            return Column(children: [
              _ReuseSummary(s: s),
              const SizedBox(height: 18),
              _ProcessStatsPanel(stats: s.processStats),
              const SizedBox(height: 18),
              _PatternsHealingPanel(snapshot: s),
              const SizedBox(height: 18),
              _PlaybookAndEscalationBreakdown(snapshot: s),
              const SizedBox(height: 28),
            ]);
          },
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.windowSeconds,
    required this.onWindowChanged,
    required this.onRefresh,
  });

  final int windowSeconds;
  final ValueChanged<int> onWindowChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
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
              Text('Convergence metrics',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                  'Reuse vs escalation, patterns confirmed, recovery success, playbook outcomes. Deterministic counts only — no estimates.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.muted, height: 1.35)),
            ],
          ),
        ),
        DropdownButton<int>(
          value: windowSeconds,
          dropdownColor: AppTheme.panel,
          style: const TextStyle(color: AppTheme.text),
          iconEnabledColor: AppTheme.subdued,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 60 * 60, child: Text('1h window')),
            DropdownMenuItem(value: 6 * 60 * 60, child: Text('6h window')),
            DropdownMenuItem(value: 24 * 60 * 60, child: Text('24h window')),
            DropdownMenuItem(value: 7 * 24 * 60 * 60, child: Text('7d window')),
          ],
          onChanged: (v) {
            if (v != null) onWindowChanged(v);
          },
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh, color: AppTheme.muted),
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

class _ReuseSummary extends StatelessWidget {
  const _ReuseSummary({required this.s});
  final ConvergenceSnapshot s;

  @override
  Widget build(BuildContext context) {
    final reuseRatePct = (s.reuse.reuseRate * 100).toStringAsFixed(1);
    final escalationRatePct =
        (s.reuse.escalationRate * 100).toStringAsFixed(1);
    final totalDecisions =
        s.reuse.reuseEventsInWindow + s.reuse.escalationsInWindow;
    return OperatorPanel(
      title: 'Reuse vs escalation',
      subtitle:
          'Reuse = containment short-circuit. Escalation = AI invocation despite containment.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 220,
                child: OperatorMetricTile(
                  label: 'Reuse rate',
                  value: totalDecisions == 0 ? '—' : '$reuseRatePct%',
                  hint: totalDecisions == 0
                      ? 'No decisions in window'
                      : '${s.reuse.reuseEventsInWindow} reuse / $totalDecisions decisions',
                  tone: s.reuse.reuseRate >= 0.85
                      ? OperatorTone.positive
                      : s.reuse.reuseRate >= 0.5
                          ? OperatorTone.neutral
                          : OperatorTone.caution,
                ),
              ),
              SizedBox(
                width: 220,
                child: OperatorMetricTile(
                  label: 'Escalations / window',
                  value: '${s.reuse.escalationsInWindow}',
                  hint: 'Escalation rate $escalationRatePct%',
                  tone: s.reuse.escalationsInWindow == 0
                      ? OperatorTone.positive
                      : OperatorTone.caution,
                ),
              ),
              SizedBox(
                width: 220,
                child: OperatorMetricTile(
                  label: 'Cache rows',
                  value: '${s.reuse.cacheRows}',
                  hint:
                      'Hits in window: ${s.reuse.cacheHitsInWindow}',
                ),
              ),
              SizedBox(
                width: 220,
                child: OperatorMetricTile(
                  label: 'Cached prompt tokens',
                  value: '${s.reuse.promptTokensInCachedDecisions}',
                  hint:
                      'completion ${s.reuse.completionTokensInCachedDecisions}',
                ),
              ),
              SizedBox(
                width: 220,
                child: OperatorMetricTile(
                  label: 'Escalations resolved',
                  value:
                      '${s.reuse.escalationsResolved} / ${s.reuse.escalationsTotal}',
                  tone: s.reuse.escalationsTotal == 0
                      ? OperatorTone.neutral
                      : (s.reuse.escalationsResolved /
                                  (s.reuse.escalationsTotal == 0
                                      ? 1
                                      : s.reuse.escalationsTotal) >=
                              0.8
                          ? OperatorTone.positive
                          : OperatorTone.caution),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProcessStatsPanel extends StatelessWidget {
  const _ProcessStatsPanel({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Containment pipeline (since boot)',
      subtitle:
          'Process-local counters: each layer that fired short-circuited an AI invocation.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _statTile('Cache hits', stats['cacheHits']),
          _statTile('Cache misses', stats['cacheMisses']),
          _statTile('Playbook matches', stats['playbookMatches']),
          _statTile('Pattern matches', stats['patternMatches']),
          _statTile('Memory matches', stats['memoryMatches']),
          _statTile('Recovery matches', stats['healingMatches']),
          _statTile('Escalations', stats['escalations']),
        ],
      ),
    );
  }

  Widget _statTile(String label, dynamic value) {
    final int v =
        value is int ? value : (value is num ? value.toInt() : 0);
    return SizedBox(
      width: 200,
      child: OperatorMetricTile(label: label, value: '$v'),
    );
  }
}

class _PatternsHealingPanel extends StatelessWidget {
  const _PatternsHealingPanel({required this.snapshot});
  final ConvergenceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final recoveryPct = snapshot.healing.recoverySuccessRate;
    return OperatorPanel(
      title: 'Patterns, suggestions, healing',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
              label: 'Patterns CONFIRMED',
              value: '${snapshot.patterns.confirmed}',
              tone: OperatorTone.positive,
            ),
          ),
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
              label: 'Patterns CANDIDATE',
              value: '${snapshot.patterns.candidate}',
            ),
          ),
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
              label: 'Suggestions pending',
              value: '${snapshot.suggestions.pending}',
              tone: snapshot.suggestions.pending == 0
                  ? OperatorTone.positive
                  : OperatorTone.caution,
            ),
          ),
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
              label: 'Suggestions accepted',
              value: '${snapshot.suggestions.accepted}',
            ),
          ),
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
              label: 'Healing applied / window',
              value: '${snapshot.healing.appliedInWindow}',
            ),
          ),
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
              label: 'Healing reverted / window',
              value: '${snapshot.healing.revertedInWindow}',
              tone: snapshot.healing.revertedInWindow == 0
                  ? OperatorTone.positive
                  : OperatorTone.caution,
            ),
          ),
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
              label: 'Recovery success',
              value: recoveryPct == null
                  ? '—'
                  : '${(recoveryPct * 100).toStringAsFixed(0)}%',
              hint: recoveryPct == null
                  ? 'No healing actions in window'
                  : 'applied vs reverted',
              tone: recoveryPct == null
                  ? OperatorTone.neutral
                  : recoveryPct >= 0.9
                      ? OperatorTone.positive
                      : OperatorTone.caution,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybookAndEscalationBreakdown extends StatelessWidget {
  const _PlaybookAndEscalationBreakdown({required this.snapshot});
  final ConvergenceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final twoCol = c.maxWidth > 760;
        final playbook = OperatorPanel(
          title: 'Playbook outcomes (window)',
          child: snapshot.playbookOutcomes.isEmpty
              ? const OperatorEmptyState(
                  title: 'No playbook executions in this window',
                  body:
                      'Either no events matched ACTIVE playbooks, or no playbooks are ACTIVE yet.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in snapshot.playbookOutcomes.entries)
                      _LineRow(label: e.key, value: '${e.value}'),
                  ],
                ),
        );
        final escal = OperatorPanel(
          title: 'Escalations by reason (window)',
          child: snapshot.escalationsByReason.isEmpty
              ? const OperatorEmptyState(
                  title: 'No escalations in this window',
                  body:
                      'Every AI request that came in was satisfied by the containment pipeline.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in snapshot.escalationsByReason.entries)
                      _LineRow(label: e.key, value: '${e.value}'),
                  ],
                ),
        );
        if (!twoCol) {
          return Column(children: [
            playbook,
            const SizedBox(height: 18),
            escal,
          ]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: playbook),
            const SizedBox(width: 18),
            Expanded(child: escal),
          ],
        );
      },
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.bodyMedium)),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
