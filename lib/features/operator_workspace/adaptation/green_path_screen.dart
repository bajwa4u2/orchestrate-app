import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../models/convergence_models.dart';
import '../models/runtime_truth_models.dart';
import '../repositories/operator_learning_repository.dart';
import '../widgets/operator_panel.dart';

/// Green Path & Budgets — the canonical runtime-truth economy.
///
/// Answers the operator's question: "is execution becoming
/// deterministic infrastructure behaviour, and is AI authority
/// invoked only at true novelty boundaries?" Shows the
/// deterministic-vs-AI execution share, per-action AI budgets, the
/// stabilization counters, and a canonical-truth blocker-chain
/// inspector. Every number is a real backend read — no fabrication.
class GreenPathScreen extends StatefulWidget {
  const GreenPathScreen({super.key});

  @override
  State<GreenPathScreen> createState() => _GreenPathScreenState();
}

class _GreenPathData {
  const _GreenPathData({required this.convergence, required this.budgets});
  final ConvergenceSnapshot convergence;
  final RuntimeBudgetSnapshot budgets;
}

class _GreenPathScreenState extends State<GreenPathScreen> {
  final OperatorLearningRepository _repo = OperatorLearningRepository();
  Future<_GreenPathData>? _future;

  final TextEditingController _clientCtrl = TextEditingController();
  final TextEditingController _campaignCtrl = TextEditingController();
  GreenPathView? _inspected;
  bool _inspecting = false;
  String? _inspectError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _clientCtrl.dispose();
    _campaignCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<_GreenPathData> _load() async {
    final results = await Future.wait([
      _repo.fetchConvergenceMetrics(windowSeconds: 24 * 60 * 60),
      _repo.fetchRuntimeBudgets(),
    ]);
    return _GreenPathData(
      convergence: results[0] as ConvergenceSnapshot,
      budgets: results[1] as RuntimeBudgetSnapshot,
    );
  }

  Future<void> _inspect() async {
    setState(() {
      _inspecting = true;
      _inspectError = null;
    });
    try {
      final view = await _repo.fetchGreenPath(
        clientId: _clientCtrl.text.trim(),
        campaignId: _campaignCtrl.text.trim(),
        action: 'SOURCE_LEADS',
      );
      if (!mounted) return;
      setState(() {
        _inspected = view;
        _inspecting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _inspectError = '$error';
        _inspecting = false;
      });
    }
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
                  Text('Green Path & Budgets',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'AI authority is invoked only at true novelty boundaries. '
                    'Healthy execution is deterministic infrastructure behaviour — '
                    'short-circuit, durable cache, green-path reuse, promoted hold.',
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
        FutureBuilder<_GreenPathData>(
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
            if (snapshot.hasError) {
              return OperatorErrorState(
                title: 'Runtime-truth economy unavailable',
                detail: '${snapshot.error}',
                onRetry: _refresh,
              );
            }
            final data = snapshot.data!;
            return Column(
              children: [
                _EconomyPanel(economy: data.convergence.greenPath),
                const SizedBox(height: 18),
                _BudgetsPanel(budgets: data.budgets.budgets),
                const SizedBox(height: 18),
                _StabilizationPanel(snapshot: data.budgets),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _InspectorPanel(
          clientCtrl: _clientCtrl,
          campaignCtrl: _campaignCtrl,
          inspecting: _inspecting,
          inspected: _inspected,
          error: _inspectError,
          onInspect: _inspect,
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────

/// Coloured execution-source badge: deterministic / AI / cache.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label, required this.tone});
  final String label;
  final OperatorTone tone;

  @override
  Widget build(BuildContext context) {
    // Canonical substrate-color mapping per
    // `company/visuals/system/topology/topology-grammar.md` §6.
    final color = switch (tone) {
      OperatorTone.positive => AppTheme.coVerdant,
      OperatorTone.caution => AppTheme.coSun,
      OperatorTone.critical => AppTheme.coRose,
      OperatorTone.neutral => AppTheme.coMist,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
          ),
        ],
      ),
    );
  }
}

class _EconomyPanel extends StatelessWidget {
  const _EconomyPanel({required this.economy});
  final GreenPathEconomy economy;

  @override
  Widget build(BuildContext context) {
    final pct = (economy.deterministicBypassRate * 100).clamp(0, 100);
    final tone = pct >= 70
        ? OperatorTone.positive
        : pct >= 40
            ? OperatorTone.caution
            : OperatorTone.critical;
    return OperatorPanel(
      title: 'Deterministic vs AI execution',
      subtitle:
          'Share of adjudicated execution that converged deterministically — '
          'no AI authority invocation — in the last 24h.',
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
                  label: 'Deterministic bypass rate',
                  value: '${pct.toStringAsFixed(1)}%',
                  tone: tone,
                  hint: 'Higher is better — AI reserved for novelty.',
                ),
              ),
              SizedBox(
                width: 200,
                child: OperatorMetricTile(
                  label: 'Deterministic executions',
                  value: '${economy.deterministicExecutions}',
                  tone: OperatorTone.positive,
                ),
              ),
              SizedBox(
                width: 200,
                child: OperatorMetricTile(
                  label: 'AI authority invocations',
                  value: '${economy.aiExecutions}',
                  tone: economy.aiExecutions == 0
                      ? OperatorTone.neutral
                      : OperatorTone.caution,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CountChip(
                badge: const _SourceBadge(
                    label: 'DETERMINISTIC', tone: OperatorTone.positive),
                label: 'Short-circuits',
                value: economy.authorityShortCircuits,
              ),
              _CountChip(
                badge: const _SourceBadge(
                    label: 'CACHE', tone: OperatorTone.neutral),
                label: 'Durable cache hits',
                value: economy.authorityDurableCacheHits,
              ),
              _CountChip(
                badge: const _SourceBadge(
                    label: 'DETERMINISTIC', tone: OperatorTone.positive),
                label: 'Green-path reuse',
                value: economy.continuityGreenPathReuse,
              ),
              _CountChip(
                badge: const _SourceBadge(
                    label: 'DETERMINISTIC', tone: OperatorTone.positive),
                label: 'Convergence promotions',
                value: economy.convergencePromotions,
              ),
              _CountChip(
                badge:
                    const _SourceBadge(label: 'AI', tone: OperatorTone.caution),
                label: 'Continuity AI authority',
                value: economy.continuityAiAuthority,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.badge,
    required this.label,
    required this.value,
  });
  final Widget badge;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          badge,
          const SizedBox(width: 10),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.muted)),
          const SizedBox(width: 8),
          Text('$value',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _BudgetsPanel extends StatelessWidget {
  const _BudgetsPanel({required this.budgets});
  final List<ActionBudgetEntry> budgets;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Per-action AI budgets',
      subtitle:
          'Hourly AI invocation ceiling per action class. At the ceiling the '
          'runtime degrades into a deterministic safe-mode hold — no AI churn.',
      child: budgets.isEmpty
          ? const OperatorEmptyState(
              title: 'No budget data yet',
              body: 'Budgets populate once authority decisions are made.',
            )
          : Column(
              children: [
                for (final b in budgets)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(b.category,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                            ),
                            Text(
                              '${b.hourCount} / ${b.hourCap} per hour'
                              '   ·   ${b.dayCount} / ${b.dayCap} per day',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.muted),
                            ),
                            const SizedBox(width: 8),
                            if (b.hourExceeded || b.dayExceeded)
                              const _SourceBadge(
                                  label: 'SAFE-MODE',
                                  tone: OperatorTone.critical)
                            else
                              const _SourceBadge(
                                  label: 'OK', tone: OperatorTone.positive),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: b.hourRatio.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: AppTheme.panelSoft,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              b.hourExceeded
                                  ? AppTheme.coRose
                                  : b.hourRatio >= 0.75
                                      ? AppTheme.coSun
                                      : AppTheme.coVerdant,
                            ),
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

class _StabilizationPanel extends StatelessWidget {
  const _StabilizationPanel({required this.snapshot});
  final RuntimeBudgetSnapshot snapshot;

  int _stat(String key) {
    final v = snapshot.stabilization[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final e = snapshot.economy;
    return OperatorPanel(
      title: 'Stabilization counters',
      subtitle: 'Cost-containment layer activity since process start.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
              label: 'Deterministic short-circuits',
              value: '${_stat('deterministicHits')}',
              tone: OperatorTone.positive,
            ),
          ),
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
              label: 'In-memory cache hits',
              value: '${_stat('cacheHits')}',
              tone: OperatorTone.neutral,
            ),
          ),
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
              label: 'AI calls',
              value: '${e.aiCalls}',
              tone: e.aiCalls == 0
                  ? OperatorTone.neutral
                  : OperatorTone.caution,
            ),
          ),
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
              label: 'Cooldown bypasses',
              value: '${_stat('cooldownBypasses')}',
              tone: OperatorTone.neutral,
            ),
          ),
          SizedBox(
            width: 200,
            child: OperatorMetricTile(
              label: 'Budget safe-mode holds',
              value: '${e.budgetSafeMode}',
              tone: e.budgetSafeMode == 0
                  ? OperatorTone.positive
                  : OperatorTone.caution,
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.clientCtrl,
    required this.campaignCtrl,
    required this.inspecting,
    required this.inspected,
    required this.error,
    required this.onInspect,
  });

  final TextEditingController clientCtrl;
  final TextEditingController campaignCtrl;
  final bool inspecting;
  final GreenPathView? inspected;
  final String? error;
  final VoidCallback onInspect;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Canonical truth inspector',
      subtitle:
          'Resolve the single runtime-truth object for a client / campaign '
          'and read the exact blocker chain holding execution.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _field(context, clientCtrl, 'Client ID')),
              const SizedBox(width: 10),
              Expanded(child: _field(context, campaignCtrl, 'Campaign ID')),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: inspecting ? null : onInspect,
                child: Text(inspecting ? 'Inspecting…' : 'Inspect'),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text('Inspection failed: $error',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.coRose)),
          ],
          if (inspected != null) ...[
            const SizedBox(height: 14),
            _verdict(context, inspected!),
          ],
        ],
      ),
    );
  }

  Widget _field(
      BuildContext context, TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppTheme.text),
      decoration: InputDecoration(
        labelText: label,
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
    );
  }

  Widget _verdict(BuildContext context, GreenPathView view) {
    final t = view.truth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SourceBadge(
              label: view.greenPath ? 'GREEN PATH' : 'HELD',
              tone: view.greenPath
                  ? OperatorTone.positive
                  : OperatorTone.critical,
            ),
            const SizedBox(width: 10),
            if (!t.dataComplete)
              const _SourceBadge(
                  label: 'PARTIAL TRUTH', tone: OperatorTone.caution),
          ],
        ),
        const SizedBox(height: 8),
        Text(view.reason,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.muted, height: 1.35)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _gate(context, 'Billing', t.billingActive),
            _gate(context, 'Mailbox', t.mailboxAuthorized),
            _gate(context, 'Provider', t.providerHealthy),
            _gate(context, 'OAuth', t.oauthValid),
            _gate(context, 'Domain', t.domainVerified),
            _gate(context, 'SPF', t.spf == 'pass'),
            _gate(context, 'DKIM', t.dkim == 'pass'),
            _gate(context, 'DMARC', t.dmarc == 'pass'),
            _gate(context, 'Pacing', t.pacingAvailable),
            _gate(context, 'Window', t.continuityWindowOpen),
            _gate(context, 'No gov. hold', t.governanceHold == null),
          ],
        ),
        if (view.blockers.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Blocker chain',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final b in view.blockers)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppTheme.panelSoft,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: AppTheme.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${b.layer} · ${b.code}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      _SourceBadge(
                        label: b.ownedBy.toUpperCase(),
                        tone: b.ownedBy == 'client'
                            ? OperatorTone.caution
                            : b.ownedBy == 'operator'
                                ? OperatorTone.critical
                                : OperatorTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(b.message,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.muted, height: 1.3)),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _gate(BuildContext context, String label, bool ok) {
    final color = ok ? AppTheme.coVerdant : AppTheme.coRose;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.text)),
        ],
      ),
    );
  }
}
