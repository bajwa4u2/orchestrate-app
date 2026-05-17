import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/system/widgets/governance_primitives.dart';

/// Runtime-authoritative execution state card.
///
/// Doctrine
/// --------
/// The OperationalContinuityStrip describes readiness *bucket* state
/// (campaign-ACTIVE level claims). This card consumes the new
/// /client/runtime-state endpoint which derives a closed-enum state
/// from REAL signals (queue depth, recent sends, recent failures,
/// workload count). It is the difference between "the campaign row
/// says ACTIVE" and "messages are actually flowing right now."
///
/// When the runtime cannot assert activity, the card says so
/// honestly. No optimistic latches. No placeholder copy.
class RuntimeStateCard extends StatefulWidget {
  const RuntimeStateCard({super.key, this.repository});

  final ClientPortalRepository? repository;

  @override
  State<RuntimeStateCard> createState() => _RuntimeStateCardState();
}

class _RuntimeStateCardState extends State<RuntimeStateCard> {
  late final ClientPortalRepository _repository =
      widget.repository ?? ClientPortalRepository();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  bool _showAdvanced = false;

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
      _data = await _repository.fetchRuntimeState();
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
              Icon(Icons.bolt_outlined,
                  size: 16, color: AppTheme.publicMuted),
              const SizedBox(width: 8),
              Text(
                'Runtime execution state',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.publicMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Re-read runtime',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _errorRow(context)
          else if (_data != null)
            _renderState(context, _data!),
        ],
      ),
    );
  }

  Widget _renderState(BuildContext context, Map<String, dynamic> d) {
    final state = (d['state'] ?? 'UNKNOWN').toString();
    final title = (d['title'] ?? '').toString();
    final detail = (d['detail'] ?? '').toString();
    final nextAction = (d['nextAction'] ?? '').toString();
    final signals = (d['signals'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            GovernanceBadge(
              label: 'state',
              value: state,
              tone: _toneForState(state),
              monospace: true,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.publicText,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          detail,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.publicMuted,
                height: 1.5,
              ),
        ),
        if (nextAction.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.publicSurfaceSoft,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Row(
              children: [
                Icon(Icons.east,
                    size: 14, color: AppTheme.publicAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nextAction,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.publicText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        InkWell(
          onTap: () => setState(() => _showAdvanced = !_showAdvanced),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Icon(
                  _showAdvanced ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: AppTheme.publicMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  _showAdvanced ? 'Hide signal trace' : 'Show signal trace',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.publicMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
        if (_showAdvanced) _renderSignals(context, signals),
      ],
    );
  }

  Widget _renderSignals(BuildContext context, Map<String, dynamic> s) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('readinessReady', s['readinessReady']?.toString()),
          _kv('campaignActive', s['campaignActive']?.toString()),
          _kv('subscriptionDegraded', s['subscriptionDegraded']?.toString()),
          _kv('mailboxBlocked', s['mailboxBlocked']?.toString()),
          _kv('workloadCount', s['workloadCount']?.toString()),
          _kv('queueDepth', s['queueDepth']?.toString()),
          _kv('recentSentCount', s['recentSentCount']?.toString()),
          _kv('recentFailedCount', s['recentFailedCount']?.toString()),
          _kv('lastSentAt', s['lastSentAt']?.toString() ?? 'null'),
          _kv('lastFailedAt', s['lastFailedAt']?.toString() ?? 'null'),
          _kv('windowSeconds', s['windowSeconds']?.toString()),
        ],
      ),
    );
  }

  Widget _kv(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.publicMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value ?? '?',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppTheme.publicText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    );
  }

  GovernanceTone _toneForState(String state) {
    switch (state) {
      case 'DISPATCHING':
        return GovernanceTone.positive;
      case 'READY_IDLE':
      case 'READY_AWAITING_WORKLOAD':
      case 'READY_AWAITING_APPROVAL':
        return GovernanceTone.neutral;
      case 'RECOVERING':
      case 'RATE_LIMITED':
      case 'PAUSED':
      case 'GOVERNANCE_BLOCKED':
      case 'PROVIDER_BLOCKED':
        return GovernanceTone.cautious;
      case 'DEGRADED':
      case 'ERROR':
      case 'NOT_READY':
        return GovernanceTone.critical;
      case 'COMPLETED':
        return GovernanceTone.positive;
      default:
        return GovernanceTone.neutral;
    }
  }
}
