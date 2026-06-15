import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_workspace_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_charts.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

class LeadsScreen extends StatelessWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LeadViewData>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(
            eyebrow: 'Opportunities',
            label: 'Loading commercial-intelligence outcomes',
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Opportunities are temporarily unavailable',
          );
        }
        final data = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12, bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(summary: data.summary),
              const SizedBox(height: 18),
              _SummaryGrid(summary: data.summary),
              const SizedBox(height: 18),
              _QualificationDistribution(summary: data.summary),
              const SizedBox(height: 18),
              if (data.summary.governanceReviewQueue > 0)
                _GovernanceQueueCallout(
                  count: data.summary.governanceReviewQueue,
                ),
              if (data.summary.governanceReviewQueue > 0)
                const SizedBox(height: 18),
              if (data.summary.blockedByGovernance > 0) ...[
                _ExplanationPanel(
                  title: 'Why some opportunities are held',
                  summary:
                      _buildClientBlockingSummary(data.blockedReasonCounts),
                ),
                const SizedBox(height: 18),
              ],
              if (data.intelligenceCampaigns.isNotEmpty) ...[
                _IntelligencePanel(campaigns: data.intelligenceCampaigns),
                const SizedBox(height: 18),
              ],
              _Panel(
                title: 'Opportunities visible to your workspace',
                emptyLabel:
                    'Signal discovery is watching for ICP-aligned opportunities. None have reached the client surface yet — refine the representation scope or wait for the next discovery pass.',
                items: data.rows,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_LeadViewData> _load() async {
    final workspaceRepo = ClientWorkspaceRepository();
    final portalRepo = ClientPortalRepository();
    final summaryFuture = portalRepo.fetchOpportunitySummary();
    final leads = await workspaceRepo.fetchLeads();
    final intelligence = await workspaceRepo.fetchIntelligenceCampaigns();
    final summaryJson = await summaryFuture;

    final rows = <_LeadRow>[];
    final blockedReasonCounts = <String, int>{};

    for (final item in leads) {
      final map = _asMap(item);
      final campaign = _read(map, 'campaign');
      final phone = _read(map, 'phone');

      final blockReasons = _extractBlockReasons(map);
      for (final reason in blockReasons) {
        blockedReasonCounts.update(reason, (value) => value + 1,
            ifAbsent: () => 1);
      }

      rows.add(
        _LeadRow(
          name: _firstNonEmpty([_read(map, 'name'), 'Unnamed lead']),
          company: _read(map, 'company'),
          title: _read(map, 'title'),
          email: _read(map, 'email'),
          phone: phone,
          location: _read(map, 'location'),
          campaign: campaign,
          status: _title(_read(map, 'status')),
          source: _title(_read(map, 'source')),
          createdDate: _formatDate(_read(map, 'createdAt')),
          blockReasons: blockReasons,
          intelligence: _readIntelligence(map['intelligence']),
        ),
      );
    }

    final intelligenceCampaigns = _readIntelligenceCampaigns(intelligence);

    return _LeadViewData(
      summary: _OpportunitySummary.fromJson(summaryJson),
      blockedReasonCounts: blockedReasonCounts,
      rows: rows,
      intelligenceCampaigns: intelligenceCampaigns,
    );
  }
}

class _LeadViewData {
  const _LeadViewData({
    required this.summary,
    required this.blockedReasonCounts,
    required this.rows,
    required this.intelligenceCampaigns,
  });

  final _OpportunitySummary summary;
  final Map<String, int> blockedReasonCounts;
  final List<_LeadRow> rows;
  final List<_IntelligenceCampaign> intelligenceCampaigns;
}

/// Authoritative opportunity summary mirroring the
/// /client/opportunities/summary response shape. Every field is
/// read deterministically from persisted rows on the backend — no
/// inferred or seeded numbers.
class _OpportunitySummary {
  const _OpportunitySummary({
    required this.total,
    required this.underQualification,
    required this.qualified,
    required this.dispatchReady,
    required this.dispatched,
    required this.suppressed,
    required this.blockedByGovernance,
    required this.governanceReviewQueue,
    required this.runtime,
  });

  factory _OpportunitySummary.fromJson(Map<String, dynamic> json) {
    final byQualification = _asMap(json['byQualification']);
    final blocking = _asMap(json['blocking']);
    return _OpportunitySummary(
      total: _countValue(json['total']),
      underQualification: _countValue(byQualification['underQualification']),
      qualified: _countValue(byQualification['qualified']),
      dispatchReady: _countValue(byQualification['dispatchReady']),
      dispatched: _countValue(byQualification['dispatched']),
      suppressed: _countValue(byQualification['suppressed']),
      blockedByGovernance:
          _countValue(blocking['blockedByGovernance']),
      governanceReviewQueue:
          _countValue(blocking['governanceReviewQueue']),
      runtime: _OpportunityRuntime.fromJson(_asMap(json['runtime'])),
    );
  }

  final int total;
  final int underQualification;
  final int qualified;
  final int dispatchReady;
  final int dispatched;
  final int suppressed;
  final int blockedByGovernance;
  final int governanceReviewQueue;
  final _OpportunityRuntime runtime;
}

class _OpportunityRuntime {
  const _OpportunityRuntime({
    required this.campaignActive,
    required this.readinessReady,
    required this.rateLimited,
    required this.governanceBlocked,
    required this.workloadCount,
  });

  factory _OpportunityRuntime.fromJson(Map<String, dynamic> json) {
    return _OpportunityRuntime(
      campaignActive: json['campaignActive'] == true,
      readinessReady: json['readinessReady'] == true,
      rateLimited: json['rateLimited'] == true,
      governanceBlocked: json['governanceBlocked'] == true,
      workloadCount: _countValue(json['workloadCount']),
    );
  }

  final bool campaignActive;
  final bool readinessReady;
  final bool rateLimited;
  final bool governanceBlocked;
  final int workloadCount;
}

class _IntelligenceCampaign {
  const _IntelligenceCampaign({
    required this.name,
    required this.lifecycleLabel,
    required this.lifecycleDetail,
    required this.lifecyclePaused,
    required this.lifecycleListening,
    required this.lastRunAt,
    required this.nextRunAt,
    required this.signalsRecent,
    required this.qualificationsRecent,
    required this.qualificationBreakdown,
  });

  final String name;

  /// Client-safe lifecycle truth, derived by the backend. The
  /// Opportunities page renders these — never the raw enabled/status
  /// flags — so a freshly-activated profile is never shown "paused".
  final String lifecycleLabel;
  final String lifecycleDetail;
  final bool lifecyclePaused;
  final bool lifecycleListening;

  final String? lastRunAt;
  final String? nextRunAt;
  final int signalsRecent;
  final int qualificationsRecent;
  final Map<String, int> qualificationBreakdown;
}

class _LeadRow {
  const _LeadRow({
    required this.name,
    required this.company,
    required this.title,
    required this.email,
    required this.phone,
    required this.location,
    required this.campaign,
    required this.status,
    required this.source,
    required this.createdDate,
    required this.blockReasons,
    required this.intelligence,
  });

  final String name;
  final String company;
  final String title;
  final String email;
  final String phone;
  final String location;
  final String campaign;
  final String status;
  final String source;
  final String createdDate;
  final List<String> blockReasons;
  final _LeadIntelligence? intelligence;
}

class _LeadIntelligence {
  const _LeadIntelligence({
    this.signalType,
    this.signalSource,
    this.signalHeadline,
    this.signalConfidence,
    this.signalDetectedAt,
    this.qualificationDecision,
    this.qualificationScore,
    this.qualificationReasons,
  });

  final String? signalType;
  final String? signalSource;
  final String? signalHeadline;
  final double? signalConfidence;
  final String? signalDetectedAt;
  final String? qualificationDecision;
  final double? qualificationScore;
  final List<String>? qualificationReasons;

  bool get hasContent =>
      (signalType?.isNotEmpty ?? false) ||
      (signalHeadline?.isNotEmpty ?? false) ||
      (qualificationDecision?.isNotEmpty ?? false);
}

class _Hero extends StatelessWidget {
  const _Hero({required this.summary});

  final _OpportunitySummary summary;

  @override
  Widget build(BuildContext context) {
    final headline = _buildHeadline(summary);
    final detail = _buildDetail(summary);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Opportunities',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            detail,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.publicMuted),
          ),
        ],
      ),
    );
  }

  String _buildHeadline(_OpportunitySummary s) {
    if (s.total == 0) {
      return 'Signal discovery is watching — no opportunities surfaced yet';
    }
    final parts = <String>[];
    if (s.underQualification > 0) {
      parts.add('${s.underQualification} under qualification');
    }
    if (s.qualified > 0) parts.add('${s.qualified} qualified');
    if (s.dispatchReady > 0) parts.add('${s.dispatchReady} dispatch-ready');
    if (parts.isEmpty) {
      return '${s.total} opportunit${s.total == 1 ? 'y' : 'ies'} in workspace';
    }
    return parts.join(' · ');
  }

  String _buildDetail(_OpportunitySummary s) {
    // Doctrine: dispatch-ready DOES NOT mean dispatching. The runtime
    // line on the home screen is the only thing that can claim
    // dispatch is in flight. Here we describe the bucket state, then
    // defer to the runtime line.
    if (s.dispatchReady == 0 && s.qualified == 0) {
      if (s.suppressed > 0) {
        return 'No qualified opportunities right now. ${s.suppressed} suppressed lead${s.suppressed == 1 ? '' : 's'} not in scope. Qualification continues — dispatch waits until a lead is dispatch-ready.';
      }
      return 'No qualified opportunities right now. The qualification engine validates business-fit, timing, and contact readiness before any lead becomes dispatch-ready.';
    }
    if (s.dispatchReady == 0) {
      return '${s.qualified} qualified lead${s.qualified == 1 ? '' : 's'} await dispatch-readiness — outreach only proceeds after a lead clears qualification and has a verified contact path.';
    }
    if (!s.runtime.campaignActive) {
      return '${s.dispatchReady} dispatch-ready lead${s.dispatchReady == 1 ? '' : 's'}, but no campaign is currently ACTIVE. Dispatch will not move until a campaign is activated — readiness alone does not start outreach.';
    }
    if (s.runtime.governanceBlocked) {
      return '${s.dispatchReady} dispatch-ready lead${s.dispatchReady == 1 ? '' : 's'} in scope. Governance is currently holding dispatch — see the runtime line on Home for the named gate.';
    }
    if (s.runtime.rateLimited) {
      return '${s.dispatchReady} dispatch-ready lead${s.dispatchReady == 1 ? '' : 's'} in scope. Send policy pacing is currently active — dispatch resumes automatically when the window opens.';
    }
    if (!s.runtime.readinessReady) {
      return '${s.dispatchReady} dispatch-ready lead${s.dispatchReady == 1 ? '' : 's'} in scope. Readiness gates have not passed — dispatch is not yet eligible. Open the home runtime line for the named blocker.';
    }
    return '${s.dispatchReady} dispatch-ready lead${s.dispatchReady == 1 ? '' : 's'} in scope. Readiness gates passed and a campaign is active. Whether messages are in flight right now is named on the runtime line on Home.';
  }
}

/// Qualification distribution — a single visual of how this client's
/// opportunities split across the disjoint qualification states. Every
/// bar is a live count from /client/opportunities/summary; an all-zero
/// set renders a truthful empty state instead of a chart.
class _QualificationDistribution extends StatelessWidget {
  const _QualificationDistribution({required this.summary});

  final _OpportunitySummary summary;

  @override
  Widget build(BuildContext context) {
    final data = <ClientChartDatum>[
      ClientChartDatum('Under qualification', summary.underQualification,
          tone: ClientBarTone.neutral),
      ClientChartDatum('Qualified', summary.qualified),
      ClientChartDatum('Dispatch-ready', summary.dispatchReady),
      ClientChartDatum('Dispatched', summary.dispatched,
          tone: ClientBarTone.positive),
      ClientChartDatum('Suppressed', summary.suppressed,
          tone: ClientBarTone.negative),
      ClientChartDatum('Blocked by governance', summary.blockedByGovernance,
          tone: ClientBarTone.attention),
    ];
    return ClientPanel(
      title: 'Qualification distribution',
      subtitle:
          'Where your opportunities sit across qualification — each a live, disjoint count.',
      children: [
        if (chartHasSignal(data))
          ClientBarChart(data: data)
        else
          const ClientEmptyState(
            message:
                'No opportunities have entered qualification yet. This distribution fills in as discovery surfaces ICP-aligned businesses.',
          ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final _OpportunitySummary summary;

  @override
  Widget build(BuildContext context) {
    // Card definitions distinguish "under qualification" / "qualified"
    // / "dispatch-ready" / "dispatched" / "suppressed" — each name
    // means a specific persisted row state. No "sendable" or "ready"
    // labels that conflate these.
    final cards = <_SummaryCard>[
      _SummaryCard(
        label: 'Under qualification',
        value: '${summary.underQualification}',
        hint: 'Discovered, not yet decided',
      ),
      _SummaryCard(
        label: 'Qualified',
        value: '${summary.qualified}',
        hint: 'Passed qualification, not yet dispatch-ready',
      ),
      _SummaryCard(
        label: 'Dispatch-ready',
        value: '${summary.dispatchReady}',
        hint: 'Eligible for outreach when runtime allows',
      ),
      _SummaryCard(
        label: 'Dispatched',
        value: '${summary.dispatched}',
        hint: 'Has at least one sent message',
      ),
      _SummaryCard(
        label: 'Suppressed',
        value: '${summary.suppressed}',
        hint: 'Out of scope; not retried',
      ),
      _SummaryCard(
        label: 'Blocked by governance',
        value: '${summary.blockedByGovernance}',
        hint: 'Hold from qualification or message-generation rules',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 720
            ? 1
            : (constraints.maxWidth < 1080 ? 2 : 3);
        return _grid(cards, columns);
      },
    );
  }

  Widget _grid(List<_SummaryCard> cards, int columns) {
    final rows = <Widget>[];
    for (int i = 0; i < cards.length; i += columns) {
      final rowChildren = <Widget>[];
      for (int c = 0; c < columns; c++) {
        if (i + c >= cards.length) {
          rowChildren.add(const Expanded(child: SizedBox.shrink()));
        } else {
          rowChildren.add(Expanded(child: _SummaryTile(card: cards[i + c])));
        }
        if (c != columns - 1) rowChildren.add(const SizedBox(width: 12));
      }
      rows.add(Row(children: rowChildren));
      if (i + columns < cards.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

class _SummaryCard {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.card});

  final _SummaryCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            card.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            card.hint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _GovernanceQueueCallout extends StatelessWidget {
  const _GovernanceQueueCallout({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E6),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: const Color(0xFFE7C97A)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade800, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count failed dispatch attempt${count == 1 ? '' : 's'} are queued for operator review. New dispatch may be held by governance until they clear.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.brown.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.emptyLabel,
    required this.items,
  });

  final String title;
  final String emptyLabel;
  final List<_LeadRow> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(emptyLabel, style: Theme.of(context).textTheme.bodyMedium)
          else
            for (int i = 0; i < items.length; i++) ...[
              _LeadTile(item: items[i]),
              if (i != items.length - 1) const Divider(height: 22),
            ],
        ],
      ),
    );
  }
}

class _LeadTile extends StatelessWidget {
  const _LeadTile({required this.item});

  final _LeadRow item;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      _join([item.company, item.title]),
      _join([item.email, item.phone]),
      _join([item.location, item.campaign]),
      _join([item.status, item.source, item.createdDate]),
      if (item.blockReasons.isNotEmpty)
        item.blockReasons.map(_translateBlockReason).join(' · '),
    ].where((line) => line.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.name, style: Theme.of(context).textTheme.titleLarge),
        for (int i = 0; i < lines.length; i++) ...[
          const SizedBox(height: 6),
          Text(
            lines[i],
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: item.blockReasons.isNotEmpty && i == lines.length - 1
                      ? Colors.orange.shade700
                      : (i == lines.length - 1
                          ? AppTheme.publicMuted
                          : AppTheme.publicText),
                ),
          ),
        ],
        if (item.intelligence != null && item.intelligence!.hasContent) ...[
          const SizedBox(height: 10),
          _LeadIntelligenceStrip(intel: item.intelligence!),
        ],
      ],
    );
  }
}

class _LeadIntelligenceStrip extends StatelessWidget {
  const _LeadIntelligenceStrip({required this.intel});

  final _LeadIntelligence intel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = <String>[];

    final signalLabel = _formatSignalLabel(intel);
    if (signalLabel.isNotEmpty) summary.add(signalLabel);

    final qualification = _formatQualificationLabel(intel);
    if (qualification.isNotEmpty) summary.add(qualification);

    final headline = intel.signalHeadline?.trim();
    if (headline != null && headline.isNotEmpty) summary.add(headline);

    final reasons = intel.qualificationReasons ?? const <String>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.publicLine.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why we surfaced this',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.publicMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          for (final line in summary) ...[
            const SizedBox(height: 4),
            Text(
              line,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.publicText),
            ),
          ],
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reasons.join(' · '),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.publicMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _IntelligencePanel extends StatelessWidget {
  const _IntelligencePanel({required this.campaigns});

  final List<_IntelligenceCampaign> campaigns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Intelligence activity (last 7 days)',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'What discovery saw, what qualification decided, and whether the system is actively listening for each campaign.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < campaigns.length; i++) ...[
            _IntelligenceCampaignTile(campaign: campaigns[i]),
            if (i != campaigns.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _IntelligenceCampaignTile extends StatelessWidget {
  const _IntelligenceCampaignTile({required this.campaign});

  final _IntelligenceCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qualifyParts = <String>[];
    for (final entry in campaign.qualificationBreakdown.entries) {
      qualifyParts.add('${entry.value} ${entry.key.toLowerCase()}');
    }
    final qualifyLabel =
        qualifyParts.isEmpty ? 'No qualification activity yet' : qualifyParts.join(' · ');
    final lastRun = campaign.lastRunAt;
    final nextRun = campaign.nextRunAt;
    final scheduleLine = <String>[
      if (lastRun != null && lastRun.isNotEmpty)
        'Last run ${_formatDate(lastRun)}',
      if (nextRun != null && nextRun.isNotEmpty && campaign.lifecycleListening)
        'Next scheduled ${_formatDate(nextRun)}',
    ].join(' · ');
    final signalsLine = campaign.signalsRecent == 0
        ? '0 signals detected yet · $qualifyLabel'
        : '${campaign.signalsRecent} signals detected · $qualifyLabel';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(campaign.name.isEmpty ? 'Untitled campaign' : campaign.name,
            style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        // Backend-derived lifecycle truth. "Paused" styling appears
        // ONLY for an explicit operator / governance pause.
        Text(
          campaign.lifecycleLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: campaign.lifecyclePaused
                ? Colors.orange.shade700
                : AppTheme.publicText,
          ),
        ),
        if (campaign.lifecycleDetail.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(campaign.lifecycleDetail,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.publicMuted)),
        ],
        if (scheduleLine.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(scheduleLine,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.publicMuted)),
        ],
        const SizedBox(height: 6),
        Text(
          signalsLine,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: AppTheme.publicText),
        ),
      ],
    );
  }
}

class _ExplanationPanel extends StatelessWidget {
  const _ExplanationPanel({required this.title, required this.summary});

  final String title;
  final List<String> summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          for (final line in summary) ...[
            Text(
              line,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

List<String> _buildClientBlockingSummary(Map<String, int> counts) {
  if (counts.isEmpty) {
    return const <String>[];
  }
  final ordered = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return ordered
      .take(3)
      .map((entry) =>
          '${entry.value} lead${entry.value == 1 ? '' : 's'} ${_translateBlockReason(entry.key).toLowerCase()}')
      .toList();
}

List<String> _extractBlockReasons(Map<String, dynamic> lead) {
  final metadata = _asMap(lead['metadataJson']);
  final rootReasons = _asStringList(metadata['blockReasons']);
  if (rootReasons.isNotEmpty) return rootReasons;
  final messageGeneration = _asMap(metadata['messageGeneration']);
  return _asStringList(messageGeneration['reasons']);
}

List<String> _asStringList(dynamic value) {
  return (value as List? ?? const [])
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _translateBlockReason(String code) {
  switch (code) {
    case 'NO_SIGNAL':
      return 'Waiting for stronger timing signals';
    case 'NO_OPPORTUNITY':
      return 'No clear opportunity has formed yet';
    case 'NO_QUALIFICATION':
      return 'Still validating relevance before outreach';
    case 'NO_EMAIL':
      return 'Missing a contact path for outreach';
    case 'NO_REAL_CONTEXT':
      return 'Do not yet have enough business context to reach out';
    case 'GENERATION_FAILED':
      return 'Message could not be prepared cleanly yet';
    default:
      return 'Still evaluating whether outreach should proceed';
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return const {};
}

String _read(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return '';
  return value.toString().trim();
}

int _countValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _join(List<String> values) =>
    values.where((value) => value.trim().isNotEmpty).join(' · ');

String _title(String value) {
  if (value.trim().isEmpty) return '';
  return value
      .split(RegExp(r'[_\s-]+'))
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _formatDate(String value) {
  if (value.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final month = _monthName(local.month);
  return '$month ${local.day}, ${local.year}';
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}

List<_IntelligenceCampaign> _readIntelligenceCampaigns(
    Map<String, dynamic> payload) {
  final raw = payload['campaigns'];
  if (raw is! List) return const <_IntelligenceCampaign>[];
  final list = <_IntelligenceCampaign>[];
  for (final entry in raw) {
    final map = _asMap(entry);
    if (map.isEmpty) continue;
    final discovery = _asMap(map['discovery']);
    final signals = _asMap(map['signals']);
    final qualifications = _asMap(map['qualifications']);
    final breakdown = _asMap(qualifications['byDecision']);
    final breakdownInts = <String, int>{};
    breakdown.forEach((key, value) {
      final count = _countValue(value);
      if (count > 0) breakdownInts[key] = count;
    });

    final lifecycle = _asMap(discovery['lifecycle']);
    list.add(
      _IntelligenceCampaign(
        name: _read(map, 'name'),
        // Render the backend-derived lifecycle truth. Fall back to a
        // neutral active-preparing label — NEVER "paused" — when the
        // lifecycle block is absent (older payload).
        lifecycleLabel: _read(lifecycle, 'clientLabel').isEmpty
            ? 'Preparing market coverage'
            : _read(lifecycle, 'clientLabel'),
        lifecycleDetail: _read(lifecycle, 'detail'),
        lifecyclePaused: lifecycle['paused'] == true,
        lifecycleListening: lifecycle['listening'] == true,
        lastRunAt:
            _read(discovery, 'lastRunAt').isEmpty ? null : _read(discovery, 'lastRunAt'),
        nextRunAt:
            _read(discovery, 'nextRunAt').isEmpty ? null : _read(discovery, 'nextRunAt'),
        signalsRecent: _countValue(signals['recent']),
        qualificationsRecent: _countValue(qualifications['recent']),
        qualificationBreakdown: breakdownInts,
      ),
    );
  }
  return list;
}

_LeadIntelligence? _readIntelligence(dynamic value) {
  final map = _asMap(value);
  if (map.isEmpty) return null;
  final signal = _asMap(map['signal']);
  final qualification = _asMap(map['qualification']);
  final reasonMap = _asMap(qualification['reason']);

  final reasons = <String>[];
  if (reasonMap.isNotEmpty) {
    final policy = _asMap(reasonMap['executionPolicy']);
    final policyStatus = _read(policy, 'status');
    if (policyStatus.isNotEmpty && policyStatus.toUpperCase() != 'OK') {
      reasons.add('Execution policy: ${_title(policyStatus)}');
    }
    final bonus = _readDouble(reasonMap['signalEvidenceBonus']);
    if (bonus != null && bonus > 0) {
      reasons.add('Signal evidence boost +${bonus.toStringAsFixed(0)}');
    }
    if (_readBool(reasonMap['hasEmailCandidate']) == false) {
      reasons.add('No verified email candidate yet');
    }
    final inferredRole = _read(reasonMap, 'inferredRole');
    if (inferredRole.isNotEmpty) reasons.add('Role: $inferredRole');
  }

  final intel = _LeadIntelligence(
    signalType: _readOptional(signal, 'type'),
    signalSource: _readOptional(signal, 'sourceType'),
    signalHeadline: _readOptional(signal, 'headline'),
    signalConfidence: _readDouble(signal['confidence']),
    signalDetectedAt: _readOptional(signal, 'detectedAt'),
    qualificationDecision: _readOptional(qualification, 'decision'),
    qualificationScore: _readDouble(qualification['finalScore']),
    qualificationReasons: reasons.isEmpty ? null : reasons,
  );

  return intel.hasContent || intel.qualificationReasons != null ? intel : null;
}

String _formatSignalLabel(_LeadIntelligence intel) {
  final parts = <String>[];
  final type = intel.signalType?.trim();
  if (type != null && type.isNotEmpty) {
    parts.add('Signal: ${_title(type)}');
  }
  final source = intel.signalSource?.trim();
  if (source != null && source.isNotEmpty) {
    parts.add('Source: ${_title(source)}');
  }
  final confidence = intel.signalConfidence;
  if (confidence != null) {
    parts.add('Confidence ${confidence.toStringAsFixed(0)}');
  }
  return parts.join(' · ');
}

String _formatQualificationLabel(_LeadIntelligence intel) {
  final decision = intel.qualificationDecision?.trim();
  if (decision == null || decision.isEmpty) return '';
  final score = intel.qualificationScore;
  if (score == null) return 'Qualification: ${_title(decision)}';
  return 'Qualification: ${_title(decision)} · Score ${score.toStringAsFixed(0)}';
}

String? _readOptional(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

bool? _readBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;
  }
  return null;
}
