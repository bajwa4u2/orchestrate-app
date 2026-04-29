import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/operator_repository.dart';

class OperatorDebugScreen extends StatefulWidget {
  const OperatorDebugScreen({super.key});

  @override
  State<OperatorDebugScreen> createState() => _OperatorDebugScreenState();
}

class _OperatorDebugScreenState extends State<OperatorDebugScreen> {
  late final OperatorRepository _repo;
  late Future<_DebugViewData> _future;

  @override
  void initState() {
    super.initState();
    _repo = OperatorRepository();
    _future = _load();
  }

  Future<_DebugViewData> _load() async {
    final results = await Future.wait<dynamic>([
      _repo.fetchAuthContext(),
      _repo.fetchCommandOverview(),
      _repo.fetchDeliverabilityOverview(),
    ]);

    return _DebugViewData(
      context: _asMap(results[0]),
      command: _asMap(results[1]),
      deliverability: _asMap(results[2]),
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DebugViewData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _DebugLoadError(error: snapshot.error, onRetry: _refresh);
        }

        final data = snapshot.data!;
        final command = data.command;
        final mailboxes = _asMap(command['mailboxes']);
        final execution = _asMap(command['execution']);
        final executionCounts = _asMap(execution['counts']);
        final aggregate = _asMap(execution['aggregate']);
        final suppressionAudit = _asMap(command['suppressionAudit']);
        final suppressionCauses = _asMap(suppressionAudit['causes']);
        final permissionSummary = _asMap(command['permissionSummary']);
        final permissions = _asList(command['permissions']);
        final deliverabilityMailboxes = _asList(data.deliverability['mailboxes']);

        final warnings = _buildWarnings(
          mailboxes: mailboxes,
          aggregate: aggregate,
          suppressionAudit: suppressionAudit,
          permissionSummary: permissionSummary,
        );

        return RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Hero(onRefresh: _refresh, warnings: warnings),
                const SizedBox(height: 18),
                _DebugSection(
                  title: 'Mailbox connection truth',
                  subtitle:
                      'Separates provider authorization from health and send readiness.',
                  rows: [
                    _DebugRow('Total mailboxes', _read(mailboxes, 'total', '0')),
                    _DebugRow('Send capable',
                        _read(mailboxes, 'sendCapable', '0')),
                    _DebugRow('Connected for sending',
                        '${_read(mailboxes, 'connected', '0')} authorized or bootstrapped'),
                    _DebugRow('Pending provider auth',
                        _read(mailboxes, 'pendingAuth', '0')),
                    _DebugRow('Reconnect required',
                        '${_read(mailboxes, 'requiresReauth', '0')} reauth / ${_read(mailboxes, 'revoked', '0')} revoked'),
                    _DebugRow('Health attention',
                        '${_read(mailboxes, 'degraded', '0')} degraded / ${_read(mailboxes, 'critical', '0')} critical'),
                    _DebugRow('Operational status',
                        _statusLabel(_read(mailboxes, 'status', 'UNKNOWN'))),
                  ],
                  details: deliverabilityMailboxes.isEmpty
                      ? const ['No mailbox records returned by deliverability overview.']
                      : deliverabilityMailboxes
                          .take(4)
                          .map((item) =>
                              '${_firstText(item, ['emailAddress', 'email', 'label'], 'Mailbox')} - ${_read(item, 'status', 'unknown')} / ${_read(item, 'connectionState', 'unknown')} / ${_read(item, 'healthStatus', 'unknown')}')
                          .toList(),
                ),
                const SizedBox(height: 18),
                _DebugSection(
                  title: 'Workflow lifecycle truth',
                  subtitle:
                      'When multiple signals are present, the aggregate state is more truthful than one dominant stage.',
                  rows: [
                    _DebugRow('Displayed state',
                        _statusLabel(_read(aggregate, 'displayStage', _read(execution, 'stage', 'UNKNOWN')))),
                    _DebugRow('Backend stage',
                        _statusLabel(_read(execution, 'stage', 'UNKNOWN'))),
                    _DebugRow('Queued imports',
                        _read(executionCounts, 'waitingOnImport', '0')),
                    _DebugRow('Queued sends',
                        _read(executionCounts, 'queuedForSend', '0')),
                    _DebugRow('Sent messages', _read(executionCounts, 'sent', '0')),
                    _DebugRow('Suppressed leads',
                        _read(executionCounts, 'blockedAtSuppression', '0')),
                    _DebugRow('Replies / meetings',
                        '${_read(executionCounts, 'replies', '0')} / ${_read(executionCounts, 'meetings', '0')}'),
                  ],
                  details: [
                    _read(aggregate, 'summary',
                        _read(execution, 'summary', 'No execution summary returned.')),
                  ],
                ),
                const SizedBox(height: 18),
                _DebugSection(
                  title: 'Suppression audit',
                  subtitle:
                      'Classifies blocked/suppressed records by the stored source of the block.',
                  rows: [
                    _DebugRow('Suppressed lead total',
                        _read(suppressionAudit, 'totalSuppressedLeads', '0')),
                    _DebugRow('Unsubscribed',
                        _read(suppressionCauses, 'unsubscribed', '0')),
                    _DebugRow('Bounced',
                        _read(suppressionCauses, 'bounced', '0')),
                    _DebugRow('Duplicate import rows',
                        _read(suppressionCauses, 'duplicate', '0')),
                    _DebugRow('Invalid contacts/import rows',
                        _read(suppressionCauses, 'invalid', '0')),
                    _DebugRow('Consent blocks',
                        _read(suppressionCauses, 'consent', '0')),
                    _DebugRow('Policy/manual/complaint',
                        _read(suppressionCauses, 'policy', '0')),
                  ],
                ),
                const SizedBox(height: 18),
                _DebugSection(
                  title: 'Permissions mapping',
                  subtitle:
                      'Shows contact consent records when they exist. Empty no longer looks like a failed load.',
                  rows: [
                    _DebugRow('Permission status',
                        _statusLabel(_read(permissionSummary, 'status', 'UNKNOWN'))),
                    _DebugRow('Consent records',
                        _read(permissionSummary, 'total', '0')),
                    _DebugRow('Allowed',
                        _read(permissionSummary, 'allowed', '0')),
                    _DebugRow('Blocked',
                        _read(permissionSummary, 'blocked', '0')),
                  ],
                  details: permissions.isEmpty
                      ? const [
                          'No contact consent records are loaded for this operator scope.'
                        ]
                      : permissions
                          .map((item) =>
                              '${_read(item, 'communication', 'UNKNOWN')} ${_read(item, 'status', 'UNKNOWN')}: ${_read(item, 'total', '0')}')
                          .toList(),
                ),
                const SizedBox(height: 18),
                _DebugSection(
                  title: 'Resolved operator context',
                  subtitle: 'Signed operator session context used for these reads.',
                  rows: data.context.entries
                      .map((entry) => _DebugRow(_label(entry.key), '${entry.value}'))
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DebugViewData {
  const _DebugViewData({
    required this.context,
    required this.command,
    required this.deliverability,
  });

  final Map<String, dynamic> context;
  final Map<String, dynamic> command;
  final Map<String, dynamic> deliverability;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onRefresh, required this.warnings});

  final Future<void> Function() onRefresh;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Live ops debug',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Mailbox, lifecycle, suppression, and permissions truth from the same backend sources used by command.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final warning in warnings.take(4)) ...[
              _WarningLine(message: warning),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _DebugLoadError extends StatelessWidget {
  const _DebugLoadError({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).displayMessage
        : 'System checks could not load at the moment.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugSection extends StatelessWidget {
  const _DebugSection({
    required this.title,
    required this.subtitle,
    required this.rows,
    this.details = const [],
  });

  final String title;
  final String subtitle;
  final List<_DebugRow> rows;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: rows.map((row) => _MetricTile(row: row)).toList(),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 18),
            for (final detail in details) ...[
              Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.row});

  final _DebugRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.36),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            row.value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _WarningLine extends StatelessWidget {
  const _WarningLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_outlined,
            size: 18, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    );
  }
}

class _DebugRow {
  const _DebugRow(this.label, this.value);

  final String label;
  final String value;
}

List<String> _buildWarnings({
  required Map<String, dynamic> mailboxes,
  required Map<String, dynamic> aggregate,
  required Map<String, dynamic> suppressionAudit,
  required Map<String, dynamic> permissionSummary,
}) {
  final warnings = <String>[];
  if (_intValue(mailboxes['total']) == 0) {
    warnings.add('No mailbox exists for this operator scope.');
  } else if (_intValue(mailboxes['sendCapable']) == 0) {
    warnings.add(
        'Mailbox exists but is not currently send-capable. Check provider auth, connection state, and health.');
  }
  if (aggregate['mixed'] == true) {
    warnings.add(
        'Execution has mixed lifecycle signals; the aggregate counts are more truthful than the single backend stage.');
  }
  if (_intValue(suppressionAudit['totalSuppressedLeads']) > 0) {
    warnings.add(
        '${_intValue(suppressionAudit['totalSuppressedLeads'])} leads are suppressed or blocked from outreach.');
  }
  if (_read(permissionSummary, 'status', '') == 'NO_CONSENT_RECORDS') {
    warnings.add(
        'Permissions are empty because no consent records are loaded for this scope.');
  }
  if (warnings.isEmpty) {
    warnings.add('No immediate debug warnings are visible.');
  }
  return warnings;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asList(dynamic value) {
  return (value as List? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _read(Map<String, dynamic> map, String key, String fallback) {
  final value = map[key];
  if (value == null) return fallback;
  final text = '$value'.trim();
  return text.isEmpty ? fallback : text;
}

String _firstText(
  Map<String, dynamic> map,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = _read(map, key, '');
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value') ?? 0;
}

String _statusLabel(String value) {
  final normalized = value.trim().replaceAll('_', ' ').toLowerCase();
  if (normalized.isEmpty) return 'Unknown';
  return normalized
      .split(' ')
      .map((part) => part.isEmpty
          ? part
          : '${part.substring(0, 1).toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _label(String key) {
  return key
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAll('_', ' ')
      .toLowerCase();
}
