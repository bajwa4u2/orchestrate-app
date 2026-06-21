import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_charts.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';
import 'package:orchestrate_app/features/guidance/guidance_drawer.dart';
import 'package:orchestrate_app/features/guidance/widgets/why_affordance.dart';

/// Operations — momentum and execution.
///
/// Answers, from the client's view: what has happened (evaluated →
/// dispatched), what is happening now (operating status, queued/sent),
/// what needs attention (governance blocks / review queue), and what
/// happens next (dispatch-ready waiting to go). Every number is a live,
/// client-scoped DB count read from /client/opportunities/summary and
/// /client/outreach — no soft or runtime-diagnostic labels.
class ClientOutreachScreen extends StatefulWidget {
  const ClientOutreachScreen({super.key});

  @override
  State<ClientOutreachScreen> createState() => _ClientOutreachScreenState();
}

class _ClientOutreachScreenState extends State<ClientOutreachScreen> {
  final ClientPortalRepository _repository = ClientPortalRepository();
  late Future<_OperationsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_OperationsData> _load() async {
    final results = await Future.wait([
      _repository.fetchOpportunitySummary(),
      _repository.fetchOutreach(),
    ]);
    return _OperationsData.parse(summary: results[0], outreach: results[1]);
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OperationsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(
            eyebrow: 'Operations',
            label: 'Loading your operation',
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Operations is temporarily unavailable',
            onRetry: _refresh,
          );
        }
        final d = snapshot.data!;
        final status = d.status();

        final funnel = <ClientChartDatum>[
          ClientChartDatum('Evaluated', d.evaluated, tone: ClientBarTone.neutral),
          ClientChartDatum('Qualified', d.qualified),
          ClientChartDatum('Dispatch-ready', d.dispatchReady),
          ClientChartDatum('Dispatched', d.dispatched),
          ClientChartDatum('Replies', d.replies, tone: ClientBarTone.positive),
          ClientChartDatum('Meetings', d.meetings, tone: ClientBarTone.positive),
        ];

        return ClientPage(
          eyebrow: 'Operations',
          title: 'Momentum and execution',
          subtitle:
              'Evaluated, dispatched, and returned. Live execution counts.',
          actions: [
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
            WhyAffordance(
              target: GuidanceTarget.readiness,
              surface: 'client_operations_momentum',
              label: 'Explain this',
            ),
          ],
          banner: ClientStatusBanner(
            tone: status.tone,
            title: status.title,
            message: status.message,
          ),
          children: [
            ClientMetricStrip(metrics: [
              ClientMetric('Evaluated', '${d.evaluated}'),
              ClientMetric('Qualified', '${d.qualified}'),
              ClientMetric('Dispatch-ready', '${d.dispatchReady}'),
              ClientMetric('Dispatched', '${d.dispatched}'),
            ]),
            const SizedBox(height: 12),
            ClientMetricStrip(metrics: [
              ClientMetric('Replies', '${d.replies}'),
              ClientMetric('Meetings', '${d.meetings}'),
              ClientMetric('Queued sends', '${d.queuedSends}'),
              ClientMetric('Sent', '${d.sent}'),
            ]),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Execution funnel',
              subtitle:
                  'Each stage is a live count of your leads and messages moving through the operation.',
              children: [
                if (chartHasSignal(funnel))
                  ClientBarChart(data: funnel)
                else
                  const ClientEmptyState(
                    message:
                        'No execution activity yet. Stages fill in as Orchestrate evaluates and dispatches for your business.',
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _AttentionPanel(data: d),
          ],
        );
      },
    );
  }
}

/// "What needs my attention" — only renders concrete, DB-backed blockers.
class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({required this.data});
  final _OperationsData data;

  @override
  Widget build(BuildContext context) {
    final blocked = data.blockedByGovernance;
    final reviewQueue = data.governanceReviewQueue;
    final nextUp = data.dispatchReady;

    return ClientPanel(
      title: 'Attention and what happens next',
      children: [
        if (blocked > 0)
          ClientInfoRow(
            title: 'Held by governance',
            primary:
                '$blocked ${blocked == 1 ? 'lead is' : 'leads are'} held by a governance rule before outreach.',
            secondary:
                'Orchestrate will not send these until they clear governance.',
          ),
        if (reviewQueue > 0)
          ClientInfoRow(
            title: 'In review queue',
            primary:
                '$reviewQueue outbound ${reviewQueue == 1 ? 'message' : 'messages'} need a retry or review.',
          ),
        if (nextUp > 0)
          ClientInfoRow(
            title: 'Next up',
            primary:
                '$nextUp ${nextUp == 1 ? 'lead is' : 'leads are'} dispatch-ready and queued to go out.',
            trailing: FilledButton.tonal(
              onPressed: () => context.go('/client/opportunities'),
              child: const Text('View'),
            ),
          ),
        if (blocked == 0 && reviewQueue == 0 && nextUp == 0)
          const ClientEmptyState(
            message:
                'Nothing needs your attention right now. Orchestrate is operating and will surface anything that needs you here.',
          ),
      ],
    );
  }
}

class _OperationsStatus {
  const _OperationsStatus(this.tone, this.title, this.message);
  final ClientBannerTone tone;
  final String title;
  final String message;
}

class _OperationsData {
  const _OperationsData({
    required this.evaluated,
    required this.qualified,
    required this.dispatchReady,
    required this.dispatched,
    required this.suppressed,
    required this.replies,
    required this.meetings,
    required this.queuedSends,
    required this.sent,
    required this.blockedByGovernance,
    required this.governanceReviewQueue,
    required this.campaignActive,
    required this.governanceBlocked,
  });

  final int evaluated;
  final int qualified;
  final int dispatchReady;
  final int dispatched;
  final int suppressed;
  final int replies;
  final int meetings;
  final int queuedSends;
  final int sent;
  final int blockedByGovernance;
  final int governanceReviewQueue;
  final bool campaignActive;
  final bool governanceBlocked;

  factory _OperationsData.parse({
    required Map<String, dynamic> summary,
    required Map<String, dynamic> outreach,
  }) {
    final byq = asMap(summary['byQualification']);
    final blocking = asMap(summary['blocking']);
    final runtime = asMap(summary['runtime']);
    final outSummary = asMap(outreach['summary']);
    return _OperationsData(
      evaluated: _int(summary['entitiesEvaluated'] ?? summary['total']),
      qualified: _int(byq['qualified']),
      dispatchReady: _int(byq['dispatchReady']),
      dispatched: _int(byq['dispatched']),
      suppressed: _int(byq['suppressed']),
      replies: _int(outSummary['replies']),
      meetings: _int(outSummary['meetings']),
      queuedSends: _int(outSummary['queuedSends']),
      sent: _int(outSummary['sent']),
      blockedByGovernance: _int(blocking['blockedByGovernance']),
      governanceReviewQueue: _int(blocking['governanceReviewQueue']),
      campaignActive: runtime['campaignActive'] == true,
      governanceBlocked: runtime['governanceBlocked'] == true,
    );
  }

  _OperationsStatus status() {
    if (governanceBlocked || blockedByGovernance > 0 || governanceReviewQueue > 0) {
      return const _OperationsStatus(
        ClientBannerTone.warning,
        'Attention needed',
        'Some leads or messages are held by governance. Orchestrate is working them and will not send anything that is not cleared.',
      );
    }
    if (campaignActive && (sent > 0 || queuedSends > 0)) {
      return _OperationsStatus(
        ClientBannerTone.success,
        'Active',
        'Your operation is live. $sent sent, $queuedSends queued.',
      );
    }
    if (dispatchReady > 0) {
      return _OperationsStatus(
        ClientBannerTone.info,
        'Ready to dispatch',
        '$dispatchReady dispatch-ready ${dispatchReady == 1 ? 'lead is' : 'leads are'} queued to go out.',
      );
    }
    if (evaluated > 0) {
      return const _OperationsStatus(
        ClientBannerTone.info,
        'Evaluating',
        'Orchestrate is evaluating and qualifying leads for your business.',
      );
    }
    return const _OperationsStatus(
      ClientBannerTone.info,
      'Coming online',
      'Your operation is being set up. Momentum will appear here as it starts.',
    );
  }
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}
