import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/guidance/guidance_drawer.dart';
import '../models/cognition_models.dart';
import '../repositories/operator_cognition_repository.dart';
import '../widgets/continuity_flow.dart';
import '../widgets/operator_panel.dart';
import '../widgets/operator_why_affordance.dart';

/// Continuity — supervises governed dispatch flow, recovery, pacing,
/// and blocked work. Queue / worker / job mechanics are reachable
/// here as drill-down detail, not top-level IA.
class ContinuityScreen extends StatefulWidget {
  const ContinuityScreen({super.key, this.initialCategory, this.initialDrill});

  final String? initialCategory;
  final String? initialDrill;

  @override
  State<ContinuityScreen> createState() => _ContinuityScreenState();
}

class _ContinuityScreenState extends State<ContinuityScreen> {
  final OperatorCognitionRepository _repo = OperatorCognitionRepository();
  Future<_ContinuityBundle>? _future;
  String? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = Future.wait([
        _repo.fetchContinuitySummary(),
        _repo.fetchBlockedWork(category: _category, limit: 100),
      ]).then((parts) => _ContinuityBundle(
            summary: parts[0] as ContinuityHealth,
            blocked: parts[1] as List<BlockedWorkRow>,
          ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ContinuityBundle>(
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
            title: 'Continuity surface unavailable',
            detail:
                'The continuity composition endpoint did not return a payload. Detail: ${snapshot.error}',
            onRetry: _refresh,
          );
        }
        final bundle = snapshot.data!;
        return ListView(
          children: [
            _Header(onRefresh: _refresh, drill: widget.initialDrill),
            const SizedBox(height: 18),
            _SummaryPanel(summary: bundle.summary),
            const SizedBox(height: 18),
            ContinuityFlow(summary: bundle.summary),
            const SizedBox(height: 18),
            _BlockedPanel(
              rows: bundle.blocked,
              activeCategory: _category,
              onCategoryChanged: (c) {
                setState(() => _category = c);
                _refresh();
              },
            ),
            const SizedBox(height: 18),
            const _DrillNote(),
            const SizedBox(height: 28),
          ],
        );
      },
    );
  }
}

class _ContinuityBundle {
  _ContinuityBundle({required this.summary, required this.blocked});
  final ContinuityHealth summary;
  final List<BlockedWorkRow> blocked;
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh, this.drill});
  final VoidCallback onRefresh;
  final String? drill;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Continuity',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppTheme.subdued)),
              const SizedBox(height: 4),
              Text(
                  drill == null
                      ? 'Execution continuity'
                      : 'Continuity · drill: ${drill!.toUpperCase()}',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                  'In-flight dispatch, blocked work by category, recovery activity. Queue / worker / job detail is a drill-down — not top-level supervision.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.muted, height: 1.35)),
            ],
          ),
        ),
        const OperatorWhyAffordance(
          target: GuidanceTarget.dispatchGovernance,
          surface: 'operator_continuity',
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

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.summary});
  final ContinuityHealth summary;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Continuity health',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
              width: 200,
              child: OperatorMetricTile(
                  label: 'In flight',
                  value: '${summary.inFlight}',
                  tone: OperatorTone.positive)),
          SizedBox(
              width: 200,
              child: OperatorMetricTile(
                  label: 'Blocked',
                  value: '${summary.blockedTotal}',
                  tone: summary.blockedTotal == 0
                      ? OperatorTone.positive
                      : OperatorTone.caution)),
          SizedBox(
              width: 200,
              child: OperatorMetricTile(
                  label: 'Sent / last hour',
                  value: '${summary.sentLastHour}')),
          SizedBox(
              width: 200,
              child: OperatorMetricTile(
                  label: 'Failed / last hour',
                  value: '${summary.failedLastHour}',
                  tone: summary.failedLastHour == 0
                      ? OperatorTone.positive
                      : OperatorTone.caution)),
          SizedBox(
              width: 200,
              child: OperatorMetricTile(
                  label: 'Jobs queued',
                  value: '${summary.jobsPending}')),
          SizedBox(
              width: 200,
              child: OperatorMetricTile(
                  label: 'Jobs failed',
                  value: '${summary.jobsFailed}',
                  tone: summary.jobsFailed == 0
                      ? OperatorTone.positive
                      : OperatorTone.caution)),
          SizedBox(
              width: 200,
              child: OperatorMetricTile(
                  label: 'Recovery actions / 24h',
                  value: '${summary.recoveringActionsLast24h}')),
        ],
      ),
    );
  }
}

class _BlockedPanel extends StatelessWidget {
  const _BlockedPanel({
    required this.rows,
    required this.activeCategory,
    required this.onCategoryChanged,
  });
  final List<BlockedWorkRow> rows;
  final String? activeCategory;
  final ValueChanged<String?> onCategoryChanged;

  static const _categories = [
    'BOUNCE',
    'RATE_LIMIT',
    'AUTH',
    'TRANSPORT',
    'DNS',
    'GOVERNANCE',
    'OTHER',
    'UNCLASSIFIED',
  ];

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Blocked work',
      subtitle: 'OutreachMessage rows in FAILED or RETRYABLE_FAILED state.',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<String?>(
            value: activeCategory,
            hint: const Text('All categories',
                style: TextStyle(color: AppTheme.subdued)),
            dropdownColor: AppTheme.panel,
            style: const TextStyle(color: AppTheme.text),
            iconEnabledColor: AppTheme.subdued,
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('All categories')),
              for (final c in _categories)
                DropdownMenuItem<String?>(value: c, child: Text(c)),
            ],
            onChanged: onCategoryChanged,
          ),
        ],
      ),
      child: rows.isEmpty
          ? const OperatorEmptyState(
              title: 'No blocked outbound right now',
              body:
                  'Either no dispatch failures in the current scope, or your filter excludes everything pending.',
            )
          : Column(
              children: [
                for (final r in rows.take(50))
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: AppTheme.panelSoft,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: r.status == 'FAILED'
                                ? AppTheme.coRose
                                : AppTheme.coSun,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.subjectLine.isEmpty
                                    ? '(no subject)'
                                    : r.subjectLine,
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${r.status} · ${r.errorCategory}${r.errorMessage == null ? '' : ' · ${r.errorMessage}'}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppTheme.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          r.failedAt ?? r.createdAt,
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
}

class _DrillNote extends StatelessWidget {
  const _DrillNote();

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Engineering drill-downs',
      subtitle:
          'Queue / worker / job mechanics are engineering primitives, not supervision concerns. They appear here, not as top-level IA.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in const [
            ('Queues (legacy)', '/operator/queues'),
            ('Workers (legacy)', '/operator/workers'),
            ('Jobs (legacy)', '/operator/jobs'),
            ('Governance review queue', '/ops/governance'),
          ])
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed(entry.$2),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.muted,
                side: const BorderSide(color: AppTheme.lineSoft),
              ),
              child: Text(entry.$1),
            ),
        ],
      ),
    );
  }
}
