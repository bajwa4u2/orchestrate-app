import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../models/convergence_models.dart';
import '../repositories/operator_learning_repository.dart';
import '../widgets/operator_panel.dart';

/// AI economy: cache rows by source / model, guardrail posture,
/// breaches in window. Token + cost attribution.
class AiEconomyScreen extends StatefulWidget {
  const AiEconomyScreen({super.key});

  @override
  State<AiEconomyScreen> createState() => _AiEconomyScreenState();
}

class _AiEconomyScreenState extends State<AiEconomyScreen> {
  final OperatorLearningRepository _repo = OperatorLearningRepository();
  Future<AiEconomy>? _future;
  int _window = 24 * 60 * 60;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _future = _repo.fetchAiEconomy(windowSeconds: _window));
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
                  Text('AI economy',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                      'Token + cost attribution from the durable reasoning cache. Guardrail posture and breaches in window.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.muted, height: 1.35)),
                ],
              ),
            ),
            DropdownButton<int>(
              value: _window,
              dropdownColor: AppTheme.panel,
              style: const TextStyle(color: AppTheme.text),
              iconEnabledColor: AppTheme.subdued,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 60 * 60, child: Text('1h window')),
                DropdownMenuItem(value: 24 * 60 * 60, child: Text('24h window')),
                DropdownMenuItem(
                    value: 7 * 24 * 60 * 60, child: Text('7d window')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _window = v);
                  _refresh();
                }
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
        FutureBuilder<AiEconomy>(
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
                  title: 'AI economy endpoint failed',
                  detail: '${snapshot.error}',
                  onRetry: _refresh);
            }
            final e = snapshot.data!;
            return Column(children: [
              _OverviewPanel(e: e),
              const SizedBox(height: 18),
              _CacheBreakdownPanel(
                  title: 'Cache rows by source', rows: e.cacheBySource),
              const SizedBox(height: 18),
              _CacheBreakdownPanel(
                  title: 'Cache rows by model', rows: e.cacheByModel),
              const SizedBox(height: 18),
              _GuardrailsPanel(rows: e.guardrails),
              const SizedBox(height: 28),
            ]);
          },
        ),
      ],
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.e});
  final AiEconomy e;

  @override
  Widget build(BuildContext context) {
    final totalRows =
        e.cacheBySource.fold<int>(0, (acc, r) => acc + r.rows);
    final totalHits = e.cacheBySource.fold<int>(0, (acc, r) => acc + r.hits);
    final totalPrompt =
        e.cacheBySource.fold<int>(0, (acc, r) => acc + r.promptTokens);
    final totalCompletion =
        e.cacheBySource.fold<int>(0, (acc, r) => acc + r.completionTokens);
    return OperatorPanel(
      title: 'Overview',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 200,
            child:
                OperatorMetricTile(label: 'Cache rows', value: '$totalRows'),
          ),
          SizedBox(
            width: 200,
            child: OperatorMetricTile(label: 'Hits', value: '$totalHits'),
          ),
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
                label: 'Prompt tokens (stored)', value: '$totalPrompt'),
          ),
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
                label: 'Completion tokens (stored)',
                value: '$totalCompletion'),
          ),
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
              label: 'Guardrail breaches / window',
              value: '${e.breachesInWindow}',
              tone: e.breachesInWindow == 0
                  ? OperatorTone.positive
                  : OperatorTone.caution,
            ),
          ),
        ],
      ),
    );
  }
}

class _CacheBreakdownPanel extends StatelessWidget {
  const _CacheBreakdownPanel({required this.title, required this.rows});
  final String title;
  final List<AiEconomyRow> rows;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: title,
      child: rows.isEmpty
          ? const OperatorEmptyState(
              title: 'No cache rows in this slice',
              body: 'Either no AI calls hit cache yet, or no rows survived TTL.',
            )
          : Column(
              children: [
                _RowHeader(),
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                            flex: 3,
                            child: Text(r.label,
                                style:
                                    Theme.of(context).textTheme.titleMedium)),
                        Expanded(
                            flex: 1,
                            child: Text('${r.rows}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppTheme.muted))),
                        Expanded(
                            flex: 1,
                            child: Text('${r.hits}',
                                style: Theme.of(context).textTheme.bodyMedium)),
                        Expanded(
                            flex: 2,
                            child: Text(
                                '${r.promptTokens} / ${r.completionTokens}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.subdued))),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RowHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppTheme.subdued, fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Label', style: s)),
          Expanded(flex: 1, child: Text('Rows', style: s)),
          Expanded(flex: 1, child: Text('Hits', style: s)),
          Expanded(flex: 2, child: Text('Prompt / Completion', style: s)),
        ],
      ),
    );
  }
}

class _GuardrailsPanel extends StatelessWidget {
  const _GuardrailsPanel({required this.rows});
  final List<AiEconomyGuardrail> rows;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Active cost guardrails',
      subtitle: 'Deterministic ceilings (token / USD / decision / retry).',
      child: rows.isEmpty
          ? const OperatorEmptyState(
              title: 'No guardrails configured',
              body:
                  'Create one in the Cost guardrails screen to enforce ceilings deterministically.',
            )
          : Column(
              children: [
                for (final g in rows)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: AppTheme.panelSoft,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radius),
                      border: Border.all(
                          color: g.breachCount > 0
                              ? AppTheme.coRose.withValues(alpha: 0.55)
                              : AppTheme.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: g.breachCount > 0
                                  ? AppTheme.coRose
                                  : AppTheme.coVerdant,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${g.scope} · ${g.kind}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(
                                  'threshold ${g.threshold.toStringAsFixed(2)} per ${g.windowSeconds}s',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppTheme.muted)),
                              if (g.breachCount > 0)
                                Text(
                                    'breached ${g.breachCount}× · last ${g.lastBreachAt?.toIso8601String() ?? "—"}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppTheme.coRose)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
