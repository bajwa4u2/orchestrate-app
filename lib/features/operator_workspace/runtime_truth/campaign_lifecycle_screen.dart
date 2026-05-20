import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../models/campaign_lifecycle_models.dart';
import '../repositories/operator_learning_repository.dart';
import '../widgets/operator_panel.dart';

/// Campaign lifecycle — the canonical, runtime-backed operator view
/// of every real campaign.
///
/// Replaces the legacy operator "Campaigns" / "Clients" panels,
/// which were disconnected from runtime truth (they could show
/// "Campaigns = 0" while the client workspace ran a live Primary
/// Automation). This screen reads the SAME Campaign source the
/// client workspace and the discovery sweep read.
class CampaignLifecycleScreen extends StatefulWidget {
  const CampaignLifecycleScreen({super.key});

  @override
  State<CampaignLifecycleScreen> createState() =>
      _CampaignLifecycleScreenState();
}

class _CampaignLifecycleScreenState extends State<CampaignLifecycleScreen> {
  final OperatorLearningRepository _repo = OperatorLearningRepository();
  Future<OperatorCampaignLifecycleView>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _future = _repo.fetchCampaignLifecycle());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<OperatorCampaignLifecycleView>(
      future: _future,
      builder: (context, snapshot) {
        return ListView(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Continuity',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: AppTheme.subdued)),
                      const SizedBox(height: 4),
                      Text('Campaign lifecycle',
                          style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Every real campaign with its canonical lifecycle, '
                        'discovery and continuity state — the same source the '
                        'client workspace reads.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppTheme.muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, color: AppTheme.muted),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (snapshot.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError || snapshot.data == null)
              OperatorErrorState(
                title: 'Campaign lifecycle is unavailable',
                detail: '${snapshot.error ?? 'No data returned.'}',
              )
            else
              ..._content(context, snapshot.data!),
          ],
        );
      },
    );
  }

  List<Widget> _content(
      BuildContext context, OperatorCampaignLifecycleView data) {
    return [
      Row(
        children: [
          Expanded(
            child: OperatorMetricTile(
              label: 'Campaigns',
              value: '${data.total}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OperatorMetricTile(
              label: 'Active',
              value: '${data.active}',
              tone: data.active > 0
                  ? OperatorTone.positive
                  : OperatorTone.caution,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OperatorMetricTile(
              label: 'Awaiting activation',
              value: '${data.byState['awaiting_activation'] ?? 0}',
              tone: OperatorTone.neutral,
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      OperatorPanel(
        title: 'Campaigns',
        subtitle: data.campaigns.isEmpty
            ? null
            : 'Lifecycle, discovery and the exact blocker for each campaign.',
        child: data.campaigns.isEmpty
            ? const OperatorEmptyState(
                title: 'No campaigns yet',
                body:
                    'No campaigns exist for this organization. A campaign '
                    'appears here the moment a client operation is created.',
              )
            : Column(
                children: [
                  for (int i = 0; i < data.campaigns.length; i++) ...[
                    _CampaignRowTile(row: data.campaigns[i]),
                    if (i != data.campaigns.length - 1)
                      const Divider(height: 22, color: AppTheme.line),
                  ],
                ],
              ),
      ),
      const SizedBox(height: 28),
    ];
  }
}

class _CampaignRowTile extends StatelessWidget {
  const _CampaignRowTile({required this.row});

  final OperatorCampaignRow row;

  OperatorTone get _tone {
    switch (row.lifecycleState) {
      case 'active':
        return OperatorTone.positive;
      case 'paused':
      case 'governance_hold':
      case 'generation_failed':
        return OperatorTone.caution;
      case 'onboarding_incomplete':
        return OperatorTone.critical;
      default:
        return OperatorTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              row.campaignName,
              style: theme.textTheme.titleLarge,
            ),
            if (row.isPrimaryAutomation)
              const _Tag(label: 'PRIMARY AUTOMATION', tone: OperatorTone.neutral),
            _Tag(label: row.lifecycleState.toUpperCase().replaceAll('_', ' '),
                tone: _tone),
          ],
        ),
        const SizedBox(height: 4),
        Text('Client · ${row.clientName}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppTheme.subdued)),
        const SizedBox(height: 6),
        Text(
          row.lifecycleDetail,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: AppTheme.muted, height: 1.35),
        ),
        const SizedBox(height: 6),
        Text(
          'Discovery · ${row.discoveryLabel}'
          '${row.continuityStatus != null ? '   ·   Continuity · ${row.continuityStatus}' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.subdued),
        ),
        const SizedBox(height: 4),
        Text(
          'Opportunities · ${row.leads} found · ${row.opportunities} ready'
          '   ·   Outreach · ${row.outreachSent} sent, ${row.outreachQueued} queued',
          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.subdued),
        ),
        if (row.shouldActivate) ...[
          const SizedBox(height: 6),
          Text(
            'Operationally ready — activating automatically on the next sweep.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppTheme.emerald),
          ),
        ],
        if (row.blockerReason != null &&
            row.blockerReason!.isNotEmpty &&
            !row.isActive &&
            !row.shouldActivate) ...[
          const SizedBox(height: 6),
          Text(
            'Blocked · ${row.blockerReason}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.orange.shade700),
          ),
        ],
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.tone});

  final String label;
  final OperatorTone tone;

  Color get _color {
    switch (tone) {
      case OperatorTone.positive:
        return AppTheme.emerald;
      case OperatorTone.caution:
        return AppTheme.amber;
      case OperatorTone.critical:
        return AppTheme.rose;
      case OperatorTone.neutral:
        return AppTheme.subdued;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}
