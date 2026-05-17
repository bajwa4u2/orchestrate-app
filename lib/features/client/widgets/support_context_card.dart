import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/system/widgets/governance_primitives.dart';

/// Runtime-aware support context card.
///
/// Doctrine
/// --------
/// Support surfaces should never ask the client to explain what
/// failed. This card reads /client/support/context which composes
/// subscription / mailbox / sending-domain / recent-governance into
/// one payload, names the operational blockers honestly (each
/// derived from a persisted state field — never inferred or
/// fabricated), and offers governed-recovery CTAs that route to the
/// right workspace surface.
///
/// What it never does:
///   - Claim "the system has resolved your issue" when the persisted
///     state has not actually changed.
///   - Show fake AI diagnosis. The blocker list is a deterministic
///     read of state, not an inference.
///   - Surface blockers Orchestrate itself owns (provider outages,
///     readiness recovery) as the client's problem. Each blocker
///     carries an explicit `owner` field surfaced in the strip.
class SupportContextCard extends StatefulWidget {
  const SupportContextCard({super.key, this.repository});

  final ClientPortalRepository? repository;

  @override
  State<SupportContextCard> createState() => _SupportContextCardState();
}

class _SupportContextCardState extends State<SupportContextCard> {
  late final ClientPortalRepository _repository =
      widget.repository ?? ClientPortalRepository();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _context;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _context = await _repository.fetchSupportContext();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent_outlined,
                  size: 16, color: AppTheme.publicMuted),
              const SizedBox(width: 8),
              Text(
                'Operational support context',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.publicMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Re-read state',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Orchestrate already knows your subscription, mailbox, sending domain, and recent dispatch state. The named blockers below come from persisted runtime state — nothing is inferred or guessed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _errorRow(context)
          else if (_context != null)
            _renderContext(context, _context!),
        ],
      ),
    );
  }

  Widget _renderContext(BuildContext context, Map<String, dynamic> data) {
    final blockers = (data['blockers'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => SupportDiagnosticEntry(
              code: m['code']?.toString() ?? 'UNKNOWN',
              message: m['message']?.toString() ?? '',
              owner: m['owner']?.toString() ?? 'client',
            ))
        .toList();

    final subscription =
        (data['subscription'] as Map?)?.cast<String, dynamic>();
    final mailbox = (data['mailbox'] as Map?)?.cast<String, dynamic>();
    final sendingDomain =
        (data['sendingDomain'] as Map?)?.cast<String, dynamic>();
    final recent = (data['recentGovernance'] as List? ?? const [])
        .whereType<Map>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SupportDiagnosticStrip(entries: blockers),
        const SizedBox(height: 18),
        _section(context, 'Workspace state'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (subscription != null) ...[
              GovernanceBadge(
                label: 'subscription',
                value: subscription['status']?.toString().toLowerCase() ??
                    'unknown',
                tone: _statusTone(subscription['status']),
              ),
              if (subscription['lane'] != null)
                GovernanceBadge(
                  label: 'lane',
                  value: subscription['lane'].toString(),
                ),
              if (subscription['tier'] != null)
                GovernanceBadge(
                  label: 'tier',
                  value: subscription['tier'].toString(),
                ),
            ],
            if (mailbox != null) ...[
              GovernanceBadge(
                label: 'mailbox',
                value: mailbox['connectionState']
                        ?.toString()
                        .toLowerCase() ??
                    'unknown',
                tone: _mailboxTone(mailbox['connectionState']),
              ),
              if (mailbox['provider'] != null)
                GovernanceBadge(
                  label: 'provider',
                  value: mailbox['provider'].toString().toLowerCase(),
                ),
            ],
            if (sendingDomain != null) ...[
              GovernanceBadge(
                label: 'sending domain',
                value: sendingDomain['status']?.toString().toLowerCase() ??
                    'unknown',
                tone: _domainTone(sendingDomain['status']),
              ),
              if (sendingDomain['domain'] != null)
                GovernanceBadge(
                  label: 'domain',
                  value: sendingDomain['domain'].toString(),
                  monospace: true,
                ),
            ],
          ],
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 18),
          _section(context, 'Recent dispatch (last ${recent.length})'),
          const SizedBox(height: 8),
          for (final m in recent) _recentRow(context, m.cast<String, dynamic>()),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go('/client/infrastructure'),
              icon: const Icon(Icons.dns_outlined, size: 16),
              label: const Text('Open infrastructure'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/client/billing'),
              icon: const Icon(Icons.receipt_long_outlined, size: 16),
              label: const Text('Open billing'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/client/activity'),
              icon: const Icon(Icons.history_outlined, size: 16),
              label: const Text('Open governance trace'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _recentRow(BuildContext context, Map<String, dynamic> m) {
    final subject = m['subject']?.toString() ?? '(no subject)';
    final status = m['status']?.toString().toLowerCase();
    final bodySource = m['bodySource']?.toString();
    final governance = (m['governance'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.publicText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          BodySourcePill(
            bodySource: bodySource,
            templateKey: governance['templateKey']?.toString(),
          ),
          if (status != null) ...[
            const SizedBox(width: 6),
            GovernanceBadge(label: 'status', value: status),
          ],
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppTheme.publicMuted,
            fontWeight: FontWeight.w700,
          ),
    );
  }

  GovernanceTone _statusTone(dynamic value) {
    final v = value?.toString();
    switch (v) {
      case 'ACTIVE':
      case 'TRIALING':
        return GovernanceTone.positive;
      case 'PAUSED':
      case 'CANCELED':
        return GovernanceTone.cautious;
      case 'PAST_DUE':
      case 'INCOMPLETE':
      case 'EXPIRED':
        return GovernanceTone.critical;
      default:
        return GovernanceTone.neutral;
    }
  }

  GovernanceTone _mailboxTone(dynamic value) {
    final v = value?.toString();
    switch (v) {
      case 'AUTHORIZED':
      case 'BOOTSTRAPPED':
        return GovernanceTone.positive;
      case 'PENDING_AUTH':
        return GovernanceTone.cautious;
      case 'REQUIRES_REAUTH':
      case 'REVOKED':
        return GovernanceTone.critical;
      default:
        return GovernanceTone.neutral;
    }
  }

  GovernanceTone _domainTone(dynamic value) {
    final v = value?.toString();
    switch (v) {
      case 'ACTIVE':
        return GovernanceTone.positive;
      case 'PENDING':
      case 'PAUSED':
        return GovernanceTone.cautious;
      case 'BLOCKED':
        return GovernanceTone.critical;
      default:
        return GovernanceTone.neutral;
    }
  }

  Widget _errorRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _error!,
            style:
                TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    );
  }
}
