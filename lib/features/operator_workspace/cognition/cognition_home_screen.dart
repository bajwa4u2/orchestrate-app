import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/guidance/guidance_drawer.dart';
import '../models/cognition_models.dart';
import '../repositories/operator_cognition_repository.dart';
import '../widgets/operator_panel.dart';
import '../widgets/operator_why_affordance.dart';

/// Cognition Home — the operator landing surface. Replaces the
/// metric-wall command center. Composed from
/// /operator/cognition/home; reads only; ordering is rule-based and
/// deterministic. OPERATOR_WORKSPACE_SPECIFICATION.md §5, §6.
class CognitionHomeScreen extends StatefulWidget {
  const CognitionHomeScreen({super.key});

  @override
  State<CognitionHomeScreen> createState() => _CognitionHomeScreenState();
}

class _CognitionHomeScreenState extends State<CognitionHomeScreen> {
  final OperatorCognitionRepository _repo = OperatorCognitionRepository();
  Future<CognitionHome>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _future = _repo.fetchHome());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CognitionHome>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingBody();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return OperatorErrorState(
            title: 'Cognition Home is temporarily unavailable',
            detail:
                'The composition endpoint did not return a payload. Cognition feed, attention queue, and trust posture are not being rendered. Detail: ${snapshot.error}',
            onRetry: _refresh,
          );
        }
        return _Body(home: snapshot.data!, onRefresh: _refresh);
      },
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.home, required this.onRefresh});

  final CognitionHome home;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.accent,
      backgroundColor: AppTheme.panel,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          _Header(home: home, onRefresh: onRefresh),
          const SizedBox(height: 18),
          _CognitionFeedPanel(items: home.feed),
          const SizedBox(height: 18),
          _AttentionAndReadiness(home: home),
          const SizedBox(height: 18),
          _ContinuityAndTruth(home: home),
          const SizedBox(height: 18),
          _AdaptationAndActivity(home: home),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.home, required this.onRefresh});

  final CognitionHome home;
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
              Text(
                'Cognition',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppTheme.subdued),
              ),
              const SizedBox(height: 4),
              Text('Operational cognition center',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'What the system is observing, learning, and deferring to you right now. Composed from real backend state; ordered deterministically.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.muted, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const OperatorWhyAffordance(
          target: GuidanceTarget.readiness,
          surface: 'operator_cognition_home',
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

class _CognitionFeedPanel extends StatelessWidget {
  const _CognitionFeedPanel({required this.items});

  final List<CognitionFeedItem> items;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Cognition feed',
      subtitle:
          'Ordered: cost guardrail breaches → suggestions → confirmed patterns → self-healing → playbook executions. Last 24h.',
      child: items.isEmpty
          ? const OperatorEmptyState(
              title: 'Nothing requires attention',
              body:
                  'The cognition layer has not surfaced anything in the last 24 hours.',
            )
          : Column(
              children: [
                for (final item in items) _FeedRow(item: item),
              ],
            ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.item});

  final CognitionFeedItem item;

  Color get _severityColor =>
      item.severity == 'attention' ? AppTheme.coSun : AppTheme.coMist;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppTheme.panelSoft,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: _severityColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _ago(item.observedAt),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.subdued),
                      ),
                    ],
                  ),
                  if (item.summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.summary,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.muted, height: 1.35),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _KindChip(label: item.kind),
                      const SizedBox(width: 8),
                      _KindChip(label: item.faculty, subdued: true),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go(item.facultyRoute),
                        child: Text(item.actionLabel ?? 'Open'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.label, this.subdued = false});
  final String label;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.panelRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.lineSoft),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: subdued ? AppTheme.subdued : AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _AttentionAndReadiness extends StatelessWidget {
  const _AttentionAndReadiness({required this.home});
  final CognitionHome home;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final twoCol = c.maxWidth > 980;
        final attention = _AttentionPanel(
          totalCount: home.attentionTotal,
          byFaculty: home.attentionByFaculty,
        );
        final readiness = _ReadinessTotalsPanel(totals: home.readinessTotals);
        if (!twoCol) {
          return Column(children: [
            attention,
            const SizedBox(height: 18),
            readiness,
          ]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: attention),
            const SizedBox(width: 18),
            Expanded(child: readiness),
          ],
        );
      },
    );
  }
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel(
      {required this.totalCount, required this.byFaculty});
  final int totalCount;
  final Map<String, int> byFaculty;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Attention',
      subtitle: 'What the system has deferred to operators right now.',
      trailing: Text('$totalCount',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: AppTheme.coSun)),
      child: byFaculty.isEmpty || totalCount == 0
          ? const OperatorEmptyState(
              title: 'Nothing deferred to operator',
              body:
                  'The system is operating without requiring human intervention right now.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in byFaculty.entries.where((e) => e.value > 0))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.coSun,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_facultyLabel(entry.key),
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        Text('${entry.value}',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  static String _facultyLabel(String key) {
    switch (key) {
      case 'cognition':
        return 'Cognition (composed)';
      case 'trustReadiness':
        return 'Trust & Readiness (client-required)';
      case 'continuity':
        return 'Continuity (blocked work)';
      case 'runtimeTruth':
        return 'Runtime Truth (degraded providers)';
      case 'adaptation':
        return 'Adaptation (suggestions + breached guardrails)';
      case 'governance':
        return 'Governance (pending approvals)';
      case 'platformSupervision':
        return 'Platform Supervision (cross-tenant)';
      default:
        return key;
    }
  }
}

class _ReadinessTotalsPanel extends StatelessWidget {
  const _ReadinessTotalsPanel({required this.totals});
  final Map<String, int> totals;

  @override
  Widget build(BuildContext context) {
    final entries = const [
      ('executing', 'Executing', OperatorTone.positive),
      ('orchestrate_working', 'Working', OperatorTone.neutral),
      ('ready_to_execute', 'Ready to execute', OperatorTone.neutral),
      ('recovering', 'Recovering', OperatorTone.caution),
      ('degraded', 'Degraded', OperatorTone.caution),
      ('client_action_required',
          'Client action required', OperatorTone.caution),
      ('orchestrate_blocked_internal',
          'Blocked (internal)', OperatorTone.critical),
    ];
    return OperatorPanel(
      title: 'Readiness rollup',
      subtitle:
          'Seven canonical buckets (OperationalReadinessService). Mirrors per-client classifications.',
      trailing: TextButton(
        onPressed: () => context.go('/ops/trust-readiness'),
        child: const Text('Open board'),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final e in entries)
            SizedBox(
              width: 200,
              child: OperatorMetricTile(
                label: e.$2,
                value: '${totals[e.$1] ?? 0}',
                tone: e.$3,
              ),
            ),
        ],
      ),
    );
  }
}

class _ContinuityAndTruth extends StatelessWidget {
  const _ContinuityAndTruth({required this.home});
  final CognitionHome home;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final twoCol = c.maxWidth > 980;
        final continuity = _ContinuityHealthPanel(health: home.continuityHealth);
        final truth = _TruthHighlightsPanel(truth: home.truthHighlights);
        if (!twoCol) {
          return Column(children: [
            continuity,
            const SizedBox(height: 18),
            truth,
          ]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: continuity),
            const SizedBox(width: 18),
            Expanded(child: truth),
          ],
        );
      },
    );
  }
}

class _ContinuityHealthPanel extends StatelessWidget {
  const _ContinuityHealthPanel({required this.health});
  final ContinuityHealth health;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Continuity health',
      subtitle:
          'In-flight dispatch, blocked work, recovery activity, job pressure.',
      trailing: TextButton(
        onPressed: () => context.go('/ops/continuity'),
        child: const Text('Open'),
      ),
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
                      label: 'In flight',
                      value: '${health.inFlight}',
                      tone: OperatorTone.positive)),
              SizedBox(
                  width: 200,
                  child: OperatorMetricTile(
                      label: 'Blocked',
                      value: '${health.blockedTotal}',
                      tone: health.blockedTotal == 0
                          ? OperatorTone.positive
                          : OperatorTone.caution)),
              SizedBox(
                  width: 200,
                  child: OperatorMetricTile(
                      label: 'Sent / last hour',
                      value: '${health.sentLastHour}')),
              SizedBox(
                  width: 200,
                  child: OperatorMetricTile(
                      label: 'Failed / last hour',
                      value: '${health.failedLastHour}',
                      tone: health.failedLastHour == 0
                          ? OperatorTone.positive
                          : OperatorTone.caution)),
              SizedBox(
                  width: 200,
                  child: OperatorMetricTile(
                      label: 'Jobs queued',
                      value: '${health.jobsPending}')),
              SizedBox(
                  width: 200,
                  child: OperatorMetricTile(
                      label: 'Recovery actions / 24h',
                      value: '${health.recoveringActionsLast24h}')),
            ],
          ),
          if (health.blockedByReason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Blocked by category',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppTheme.subdued)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final e in health.blockedByReason.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.panelRaised,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.lineSoft),
                    ),
                    child: Text('${e.key} · ${e.value}',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TruthHighlightsPanel extends StatelessWidget {
  const _TruthHighlightsPanel({required this.truth});
  final TruthHighlights truth;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Runtime truth',
      subtitle:
          'Observed health of providers, mailboxes, and sending identity.',
      trailing: TextButton(
        onPressed: () => context.go('/ops/runtime-truth'),
        child: const Text('Open'),
      ),
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
                      label: 'Mailboxes healthy',
                      value:
                          '${truth.mailboxes.healthy} / ${truth.mailboxes.total}',
                      tone: truth.mailboxes.healthy == truth.mailboxes.total
                          ? OperatorTone.positive
                          : OperatorTone.caution)),
              SizedBox(
                  width: 200,
                  child: OperatorMetricTile(
                      label: 'Mailboxes degraded',
                      value: '${truth.mailboxes.degraded}',
                      tone: truth.mailboxes.degraded == 0
                          ? OperatorTone.positive
                          : OperatorTone.caution)),
              SizedBox(
                  width: 200,
                  child: OperatorMetricTile(
                      label: 'Mailboxes critical',
                      value: '${truth.mailboxes.critical}',
                      tone: truth.mailboxes.critical == 0
                          ? OperatorTone.positive
                          : OperatorTone.critical)),
              SizedBox(
                  width: 200,
                  child: OperatorMetricTile(
                      label: 'Requires reauth',
                      value: '${truth.mailboxes.requiresReauth}',
                      tone: truth.mailboxes.requiresReauth == 0
                          ? OperatorTone.positive
                          : OperatorTone.caution)),
              SizedBox(
                  width: 200,
                  child: OperatorMetricTile(
                      label: 'Sending domains active',
                      value:
                          '${truth.sendingDomains.active} / ${truth.sendingDomains.total}')),
              SizedBox(
                  width: 200,
                  child: OperatorMetricTile(
                      label: 'Bounces / 24h',
                      value: truth.deliverabilityBouncesLast24h?.toString() ??
                          '—')),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdaptationAndActivity extends StatelessWidget {
  const _AdaptationAndActivity({required this.home});
  final CognitionHome home;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final twoCol = c.maxWidth > 980;
        final adaptation = _ActiveAdaptationsPanel(items: home.activeAdaptations);
        final activity = _RecentActivityPanel(items: home.recentOperatorActivity);
        if (!twoCol) {
          return Column(children: [
            adaptation,
            const SizedBox(height: 18),
            activity,
          ]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: adaptation),
            const SizedBox(width: 18),
            Expanded(child: activity),
          ],
        );
      },
    );
  }
}

class _ActiveAdaptationsPanel extends StatelessWidget {
  const _ActiveAdaptationsPanel({required this.items});
  final ActiveAdaptations items;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Active adaptations',
      subtitle: 'Self-AI substrate posture in the last 24 hours.',
      trailing: TextButton(
        onPressed: () => context.go('/ops/adaptation'),
        child: const Text('Open'),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
              width: 200,
              child: OperatorMetricTile(
                  label: 'Playbooks fired',
                  value: '${items.playbooksFiredToday}')),
          SizedBox(
              width: 200,
              child: OperatorMetricTile(
                  label: 'Suggestions pending',
                  value: '${items.suggestionsPending}',
                  tone: items.suggestionsPending == 0
                      ? OperatorTone.positive
                      : OperatorTone.caution)),
          SizedBox(
              width: 200,
              child: OperatorMetricTile(
                  label: 'Guardrails armed',
                  value: '${items.guardrailsArmed}')),
          SizedBox(
              width: 200,
              child: OperatorMetricTile(
                  label: 'Self-healing / 24h',
                  value: '${items.healingToday}')),
        ],
      ),
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel({required this.items});
  final List<OperatorActivityEntry> items;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Recent operator activity',
      subtitle: 'Last 24h of attributed operator actions (AuditLog).',
      trailing: TextButton(
        onPressed: () => context.go('/ops/governance/audit'),
        child: const Text('Open audit timeline'),
      ),
      child: items.isEmpty
          ? const OperatorEmptyState(
              title: 'No operator activity in the last 24h',
              body:
                  'Either nothing happened, or no operator action was attributed in the audit log.',
              icon: Icons.history,
            )
          : Column(
              children: [
                for (final item in items.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.action,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                              Text(
                                  '${item.entityType} · ${item.actorDisplayName ?? "system"}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppTheme.subdued)),
                            ],
                          ),
                        ),
                        Text(
                          _ago(item.createdAt),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.subdued),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  static String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
