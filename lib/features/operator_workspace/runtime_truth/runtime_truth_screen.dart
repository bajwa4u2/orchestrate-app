import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/widgets/substrate_citation.dart';
import 'package:orchestrate_app/features/guidance/guidance_drawer.dart';
import '../models/cognition_models.dart';
import '../repositories/operator_cognition_repository.dart';
import '../widgets/execution_topology_map.dart';
import '../widgets/operator_panel.dart';
import '../widgets/operator_why_affordance.dart';

/// Runtime Truth — observed provider, mailbox, sending identity,
/// deliverability behavior. Reads /operator/runtime-truth/overview.
class RuntimeTruthScreen extends StatefulWidget {
  const RuntimeTruthScreen({super.key});

  @override
  State<RuntimeTruthScreen> createState() => _RuntimeTruthScreenState();
}

class _RuntimeTruthScreenState extends State<RuntimeTruthScreen> {
  final OperatorCognitionRepository _repo = OperatorCognitionRepository();
  Future<TruthHighlights>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _future = _repo.fetchRuntimeTruth());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TruthHighlights>(
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
            title: 'Runtime truth surface unavailable',
            detail: '${snapshot.error}',
            onRetry: _refresh,
          );
        }
        final truth = snapshot.data!;
        return ListView(
          children: [
            _Header(onRefresh: _refresh),
            const SizedBox(height: 18),
            ExecutionTopologyMap(truth: truth),
            const SizedBox(height: 18),
            _ProvidersPanel(rows: truth.providers),
            const SizedBox(height: 18),
            _MailboxesPanel(mailboxes: truth.mailboxes),
            const SizedBox(height: 18),
            _SendingDomainsPanel(domains: truth.sendingDomains),
            const SizedBox(height: 18),
            _DeliverabilityPanel(truth: truth),
            const SizedBox(height: 12),
            const SubstrateDoctrine(
              text:
                  'There must be exactly one operational truth object. '
                  'Deterministic fingerprint. Honest unknowns rendered '
                  'as their own state.',
            ),
            const SizedBox(height: 8),
            const SubstrateCitation(
              paths: [
                'orchestrate_backend/src/runtime-truth/runtime-truth.types.ts',
                'orchestrate_backend/src/runtime-truth/runtime-truth.service.ts',
              ],
            ),
            const SizedBox(height: 28),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
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
              Text('Observed runtime state',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                  'What providers, mailboxes, sending identity, and deliverability are actually doing — independent of what was configured.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.muted, height: 1.35)),
            ],
          ),
        ),
        const OperatorWhyAffordance(
          target: GuidanceTarget.mailboxProviderError,
          surface: 'operator_runtime_truth',
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

class _ProvidersPanel extends StatelessWidget {
  const _ProvidersPanel({required this.rows});
  final List<TruthProviderRow> rows;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Providers',
      subtitle: 'Mailbox provider health rollup.',
      child: rows.isEmpty
          ? const OperatorEmptyState(
              title: 'No providers connected',
              body: 'Nothing to report here yet.')
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final r in rows)
                  SizedBox(
                    width: 240,
                    child: OperatorMetricTile(
                      label: r.name,
                      value: '${r.healthy} / ${r.total}',
                      hint:
                          'degraded ${r.degraded} · critical ${r.critical}',
                      tone: r.critical > 0
                          ? OperatorTone.critical
                          : r.degraded > 0
                              ? OperatorTone.caution
                              : OperatorTone.positive,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MailboxesPanel extends StatelessWidget {
  const _MailboxesPanel({required this.mailboxes});
  final TruthMailboxes mailboxes;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Mailboxes',
      subtitle:
          'Per-mailbox status with OAuth timeline references. Vault never returns raw tokens.',
      child: mailboxes.items.isEmpty
          ? const OperatorEmptyState(
              title: 'No mailboxes',
              body: 'No mailbox records yet.')
          : Column(
              children: [
                _MailboxHeaderRow(),
                for (final m in mailboxes.items) _MailboxRow(item: m),
              ],
            ),
    );
  }
}

class _MailboxHeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppTheme.subdued, fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Mailbox', style: s)),
          Expanded(flex: 2, child: Text('Provider', style: s)),
          Expanded(flex: 2, child: Text('Connection', style: s)),
          Expanded(flex: 2, child: Text('Health', style: s)),
          Expanded(flex: 2, child: Text('Last refresh', style: s)),
        ],
      ),
    );
  }
}

class _MailboxRow extends StatelessWidget {
  const _MailboxRow({required this.item});
  final TruthMailboxItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(item.emailAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium)),
          Expanded(
              flex: 2,
              child: Text(item.provider,
                  style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(
              flex: 2, child: _StateChip(label: item.connectionState)),
          Expanded(flex: 2, child: _StateChip(label: item.healthStatus)),
          Expanded(
              flex: 2,
              child: Text(_short(item.lastRefreshAt ?? item.lastAuthAt),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.subdued))),
        ],
      ),
    );
  }

  static String _short(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'AUTHORIZED' || 'HEALTHY' => AppTheme.coVerdant,
      'PENDING_AUTH' || 'DEGRADED' => AppTheme.coSun,
      'REVOKED' || 'REQUIRES_REAUTH' || 'CRITICAL' => AppTheme.coRose,
      _ => AppTheme.subdued,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _SendingDomainsPanel extends StatelessWidget {
  const _SendingDomainsPanel({required this.domains});
  final TruthSendingDomains domains;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Sending identity',
      subtitle:
          'Per-domain DNS state (SPF / DKIM / DMARC verification). Polled on cadence by the sending-identity worker.',
      child: domains.items.isEmpty
          ? const OperatorEmptyState(
              title: 'No sending domains',
              body: 'No domains attached yet.')
          : Column(
              children: [
                for (final d in domains.items)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: AppTheme.panelSoft,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(d.domain,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        Expanded(flex: 2, child: _StateChip(label: d.status)),
                        Expanded(
                            flex: 3,
                            child: Text(
                              d.failedReason ?? '—',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.muted),
                            )),
                        Expanded(
                          flex: 2,
                          child: Text(
                            _short(d.dnsVerifiedAt ?? d.lastCheckedAt),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.subdued),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  static String _short(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _DeliverabilityPanel extends StatelessWidget {
  const _DeliverabilityPanel({required this.truth});
  final TruthHighlights truth;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      title: 'Deliverability',
      subtitle: 'Bounces / complaints observed in the last 24 hours.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
              width: 220,
              child: OperatorMetricTile(
                  label: 'Bounces / 24h',
                  value: truth.deliverabilityBouncesLast24h?.toString() ?? '—',
                  tone: (truth.deliverabilityBouncesLast24h ?? 0) == 0
                      ? OperatorTone.positive
                      : OperatorTone.caution)),
          SizedBox(
              width: 220,
              child: OperatorMetricTile(
                  label: 'Complaints / 24h',
                  value:
                      truth.deliverabilityComplaintsLast24h?.toString() ?? '—',
                  tone: (truth.deliverabilityComplaintsLast24h ?? 0) == 0
                      ? OperatorTone.positive
                      : OperatorTone.caution)),
        ],
      ),
    );
  }
}
