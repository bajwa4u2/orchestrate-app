import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final TextEditingController _suppressionEmailController =
      TextEditingController();
  final TextEditingController _suppressionDomainController =
      TextEditingController();
  final TextEditingController _suppressionReasonController =
      TextEditingController();

  Timer? _refreshTimer;
  bool _autoRefresh = true;
  bool _actionBusy = false;
  String _suppressionType = 'MANUAL_BLOCK';
  String? _actionMessage;
  DateTime? _lastLoadedAt;

  @override
  void initState() {
    super.initState();
    _repo = OperatorRepository();
    _future = _load();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _suppressionEmailController.dispose();
    _suppressionDomainController.dispose();
    _suppressionReasonController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    if (!_autoRefresh) return;
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_actionBusy) {
        _refresh(silent: true);
      }
    });
  }

  Future<_DebugViewData> _load() async {
    final results = await Future.wait<dynamic>([
      _repo.fetchAuthContext(),
      _repo.fetchCommandOverview(),
      _repo.fetchCommandWorkspace(),
      _repo.fetchDeliverabilityOverview(),
    ]);

    _lastLoadedAt = DateTime.now();
    return _DebugViewData(
      context: _asMap(results[0]),
      command: _asMap(results[1]),
      workspace: _asMap(results[2]),
      deliverability: _asMap(results[3]),
      loadedAt: _lastLoadedAt!,
    );
  }

  Future<void> _refresh({bool silent = false}) async {
    final next = _load();
    setState(() {
      _future = next;
      if (!silent) _actionMessage = null;
    });
    await next;
  }

  Future<void> _runAction(
    String successMessage,
    Future<void> Function() action,
  ) async {
    if (_actionBusy) return;
    setState(() {
      _actionBusy = true;
      _actionMessage = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _actionMessage = successMessage;
      });
      await _refresh(silent: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionMessage = _displayError(error,
            fallback: 'The operation could not be completed.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _dispatchDueJobs() {
    return _runAction('Due jobs dispatched.', () async {
      await _repo.dispatchDueJobs(limit: 25);
    });
  }

  Future<void> _runJob(String jobId) {
    return _runAction('Job run requested.', () async {
      await _repo.runJob(jobId: jobId, force: true);
    });
  }

  Future<void> _activateCampaign(String campaignId) {
    return _runAction('Campaign recovery requested.', () async {
      await _repo.activateCampaign(campaignId);
    });
  }

  Future<void> _resolveAlert(String alertId) {
    return _runAction('Alert resolved.', () async {
      await _repo.resolveAlert(alertId);
    });
  }

  Future<void> _refreshMailbox(String mailboxId) {
    return _runAction('Mailbox health refresh requested.', () async {
      await _repo.refreshMailboxHealth(mailboxId);
    });
  }

  Future<void> _reconnectMailbox(String mailboxId) {
    return _runAction('Mailbox reconnect flow prepared.', () async {
      await _repo.reconnectMailbox(mailboxId);
    });
  }

  Future<void> _createSuppression() {
    final email = _suppressionEmailController.text.trim();
    final domain = _suppressionDomainController.text.trim();
    if (email.isEmpty && domain.isEmpty) {
      setState(() {
        _actionMessage = 'Enter an email address or domain to suppress.';
      });
      return Future.value();
    }
    return _runAction('Suppression entry created.', () async {
      await _repo.createSuppression(
        emailAddress: email.isEmpty ? null : email,
        domain: domain.isEmpty ? null : domain,
        type: _suppressionType,
        reason: _suppressionReasonController.text.trim(),
      );
      _suppressionEmailController.clear();
      _suppressionDomainController.clear();
      _suppressionReasonController.clear();
    });
  }

  Future<void> _copyReport(_DebugViewData data) async {
    final report = const JsonEncoder.withIndent('  ').convert(data.reportJson);
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    setState(() {
      _actionMessage = 'Live ops report copied to clipboard.';
    });
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
        final workspace = data.workspace;
        final mailboxes = _asMap(command['mailboxes']);
        final execution = _asMap(command['execution']);
        final executionCounts = _asMap(execution['counts']);
        final aggregate = _asMap(execution['aggregate']);
        final suppressionAudit = _asMap(command['suppressionAudit']);
        final suppressionCauses = _asMap(suppressionAudit['causes']);
        final permissionSummary = _asMap(command['permissionSummary']);
        final permissions = _asList(command['permissions']);
        final deliverabilityMailboxes =
            _asList(data.deliverability['mailboxes']);
        final alerts = _asList(_asMap(workspace['health'])['alerts']);
        final attention = _asList(workspace['attention']);
        final failedJobs = _asList(_asMap(workspace['execution'])['failedJobs']);
        final campaigns = _asList(_asMap(workspace['outreach'])['campaigns']);
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
                _Hero(
                  autoRefresh: _autoRefresh,
                  actionBusy: _actionBusy,
                  actionMessage: _actionMessage,
                  lastLoadedAt: data.loadedAt,
                  warnings: warnings,
                  onRefresh: _refresh,
                  onDispatchDueJobs: _dispatchDueJobs,
                  onCopyReport: () => _copyReport(data),
                  onAutoRefreshChanged: (value) {
                    setState(() {
                      _autoRefresh = value;
                    });
                    _startAutoRefresh();
                  },
                ),
                const SizedBox(height: 18),
                _DebugSection(
                  title: 'Mailbox operations',
                  subtitle:
                      'Connection state, provider auth, health, and reconnect controls.',
                  rows: [
                    _DebugRow('Total', _read(mailboxes, 'total', '0')),
                    _DebugRow('Send capable',
                        _read(mailboxes, 'sendCapable', '0')),
                    _DebugRow('Connected',
                        '${_read(mailboxes, 'connected', '0')} authorized/bootstrap'),
                    _DebugRow('Pending auth',
                        _read(mailboxes, 'pendingAuth', '0')),
                    _DebugRow('Reconnect',
                        '${_read(mailboxes, 'requiresReauth', '0')} reauth / ${_read(mailboxes, 'revoked', '0')} revoked'),
                    _DebugRow('Health',
                        '${_read(mailboxes, 'degraded', '0')} degraded / ${_read(mailboxes, 'critical', '0')} critical'),
                    _DebugRow('Status',
                        _statusLabel(_read(mailboxes, 'status', 'UNKNOWN'))),
                  ],
                  child: _MailboxDrilldown(
                    items: deliverabilityMailboxes,
                    actionBusy: _actionBusy,
                    onRefreshMailbox: _refreshMailbox,
                    onReconnectMailbox: _reconnectMailbox,
                  ),
                ),
                const SizedBox(height: 18),
                _DebugSection(
                  title: 'Queue and lifecycle controls',
                  subtitle:
                      'Mixed state is expected when imports, queued sends, sent messages, and suppressions coexist.',
                  rows: [
                    _DebugRow('Displayed state',
                        _statusLabel(_read(aggregate, 'displayStage', _read(execution, 'stage', 'UNKNOWN')))),
                    _DebugRow('Backend stage',
                        _statusLabel(_read(execution, 'stage', 'UNKNOWN'))),
                    _DebugRow('Queued imports',
                        _read(executionCounts, 'waitingOnImport', '0')),
                    _DebugRow('Queued sends',
                        _read(executionCounts, 'queuedForSend', '0')),
                    _DebugRow('Sent', _read(executionCounts, 'sent', '0')),
                    _DebugRow('Suppressed',
                        _read(executionCounts, 'blockedAtSuppression', '0')),
                    _DebugRow('Replies / meetings',
                        '${_read(executionCounts, 'replies', '0')} / ${_read(executionCounts, 'meetings', '0')}'),
                  ],
                  child: _QueueControls(
                    failedJobs: failedJobs,
                    actionBusy: _actionBusy,
                    onDispatchDueJobs: _dispatchDueJobs,
                    onRunJob: _runJob,
                    summary: _read(aggregate, 'summary',
                        _read(execution, 'summary', 'No execution summary returned.')),
                  ),
                ),
                const SizedBox(height: 18),
                _DebugSection(
                  title: 'Alert severities',
                  subtitle:
                      'Open alerts and attention items with severity and timestamps.',
                  rows: [
                    _DebugRow('Open alerts', '${alerts.length}'),
                    _DebugRow('Attention items', '${attention.length}'),
                  ],
                  child: _AlertDrilldown(
                    alerts: alerts,
                    attention: attention,
                    actionBusy: _actionBusy,
                    onResolveAlert: _resolveAlert,
                  ),
                ),
                const SizedBox(height: 18),
                _DebugSection(
                  title: 'Suppression management',
                  subtitle:
                      'Classify causes and add emergency suppressions without leaving ops.',
                  rows: [
                    _DebugRow('Suppressed leads',
                        _read(suppressionAudit, 'totalSuppressedLeads', '0')),
                    _DebugRow('Unsubscribed',
                        _read(suppressionCauses, 'unsubscribed', '0')),
                    _DebugRow('Bounced',
                        _read(suppressionCauses, 'bounced', '0')),
                    _DebugRow('Duplicate rows',
                        _read(suppressionCauses, 'duplicate', '0')),
                    _DebugRow('Invalid',
                        _read(suppressionCauses, 'invalid', '0')),
                    _DebugRow('Consent',
                        _read(suppressionCauses, 'consent', '0')),
                    _DebugRow('Policy/manual',
                        _read(suppressionCauses, 'policy', '0')),
                  ],
                  child: _SuppressionForm(
                    emailController: _suppressionEmailController,
                    domainController: _suppressionDomainController,
                    reasonController: _suppressionReasonController,
                    type: _suppressionType,
                    actionBusy: _actionBusy,
                    onTypeChanged: (value) {
                      if (value == null) return;
                      setState(() => _suppressionType = value);
                    },
                    onCreate: _createSuppression,
                  ),
                ),
                const SizedBox(height: 18),
                _DebugSection(
                  title: 'Campaign recovery',
                  subtitle:
                      'Recover inactive or stalled campaigns using the same activation path as command.',
                  rows: [
                    _DebugRow('Campaigns visible', '${campaigns.length}'),
                    _DebugRow(
                      'Recoverable',
                      '${campaigns.where((item) => _read(item, 'status', '') != 'ACTIVE').length}',
                    ),
                  ],
                  child: _CampaignRecovery(
                    campaigns: campaigns,
                    actionBusy: _actionBusy,
                    onActivateCampaign: _activateCampaign,
                  ),
                ),
                const SizedBox(height: 18),
                _DebugSection(
                  title: 'Permissions mapping',
                  subtitle:
                      'Consent records by communication and status. Empty is treated as no records for this scope.',
                  rows: [
                    _DebugRow('Status',
                        _statusLabel(_read(permissionSummary, 'status', 'UNKNOWN'))),
                    _DebugRow('Consent records',
                        _read(permissionSummary, 'total', '0')),
                    _DebugRow('Allowed',
                        _read(permissionSummary, 'allowed', '0')),
                    _DebugRow('Blocked',
                        _read(permissionSummary, 'blocked', '0')),
                  ],
                  child: _SimpleList(
                    emptyText:
                        'No contact consent records are loaded for this operator scope.',
                    items: permissions
                        .map((item) =>
                            '${_read(item, 'communication', 'UNKNOWN')} ${_read(item, 'status', 'UNKNOWN')}: ${_read(item, 'total', '0')}')
                        .toList(),
                  ),
                ),
                const SizedBox(height: 18),
                _DebugSection(
                  title: 'Reports and raw drilldowns',
                  subtitle:
                      'Copy the current ops report or inspect source payloads used by this screen.',
                  rows: [
                    _DebugRow('Loaded at', _formatDateTime(data.loadedAt)),
                    _DebugRow('Operator fields', '${data.context.length}'),
                    _DebugRow('Command fields', '${command.length}'),
                    _DebugRow('Workspace fields', '${workspace.length}'),
                  ],
                  child: _RawDrilldowns(data: data),
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
    required this.workspace,
    required this.deliverability,
    required this.loadedAt,
  });

  final Map<String, dynamic> context;
  final Map<String, dynamic> command;
  final Map<String, dynamic> workspace;
  final Map<String, dynamic> deliverability;
  final DateTime loadedAt;

  Map<String, dynamic> get reportJson => <String, dynamic>{
        'generatedAt': loadedAt.toIso8601String(),
        'context': context,
        'command': command,
        'workspace': workspace,
        'deliverability': deliverability,
      };
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.autoRefresh,
    required this.actionBusy,
    required this.actionMessage,
    required this.lastLoadedAt,
    required this.warnings,
    required this.onRefresh,
    required this.onDispatchDueJobs,
    required this.onCopyReport,
    required this.onAutoRefreshChanged,
  });

  final bool autoRefresh;
  final bool actionBusy;
  final String? actionMessage;
  final DateTime lastLoadedAt;
  final List<String> warnings;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onDispatchDueJobs;
  final Future<void> Function() onCopyReport;
  final ValueChanged<bool> onAutoRefreshChanged;

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 420,
                child: Text(
                  'Live operations control center',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    selected: autoRefresh,
                    onSelected: onAutoRefreshChanged,
                    avatar: const Icon(Icons.sync, size: 18),
                    label: Text(autoRefresh ? 'Auto-refresh on' : 'Auto-refresh off'),
                  ),
                  OutlinedButton.icon(
                    onPressed: actionBusy ? null : onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                  FilledButton.icon(
                    onPressed: actionBusy ? null : onDispatchDueJobs,
                    icon: const Icon(Icons.play_arrow_outlined),
                    label: const Text('Dispatch due'),
                  ),
                  OutlinedButton.icon(
                    onPressed: actionBusy ? null : onCopyReport,
                    icon: const Icon(Icons.file_copy_outlined),
                    label: const Text('Copy report'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Actions, drilldowns, alerts, queues, mailbox recovery, suppression controls, campaign recovery, and reporting in one operator surface.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text('Last loaded: ${_formatDateTime(lastLoadedAt)}'),
          if (actionMessage != null) ...[
            const SizedBox(height: 12),
            _NoticeLine(message: actionMessage!),
          ],
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final warning in warnings.take(5)) ...[
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
    final message = _displayError(error,
        fallback: 'System checks could not load at the moment.');
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
    required this.child,
  });

  final String title;
  final String subtitle;
  final List<_DebugRow> rows;
  final Widget child;

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
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _MailboxDrilldown extends StatelessWidget {
  const _MailboxDrilldown({
    required this.items,
    required this.actionBusy,
    required this.onRefreshMailbox,
    required this.onReconnectMailbox,
  });

  final List<Map<String, dynamic>> items;
  final bool actionBusy;
  final Future<void> Function(String mailboxId) onRefreshMailbox;
  final Future<void> Function(String mailboxId) onReconnectMailbox;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _SimpleList(
        emptyText: 'No mailbox records returned by deliverability overview.',
        items: [],
      );
    }
    return Column(
      children: items.take(8).map((item) {
        final id = _read(item, 'id', '');
        return _ActionRow(
          title: _firstText(item, ['emailAddress', 'email', 'label'], 'Mailbox'),
          severity: _read(item, 'healthStatus', 'UNKNOWN'),
          subtitle:
              '${_read(item, 'status', 'unknown')} / ${_read(item, 'connectionState', 'unknown')} / ${_read(item, 'provider', 'provider')}',
          timestamp: _firstText(item, ['updatedAt', 'lastAuthAt', 'createdAt'], ''),
          actions: [
            TextButton.icon(
              onPressed:
                  actionBusy || id.isEmpty ? null : () => onRefreshMailbox(id),
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('Refresh health'),
            ),
            TextButton.icon(
              onPressed:
                  actionBusy || id.isEmpty ? null : () => onReconnectMailbox(id),
              icon: const Icon(Icons.link_outlined),
              label: const Text('Reconnect'),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _QueueControls extends StatelessWidget {
  const _QueueControls({
    required this.failedJobs,
    required this.actionBusy,
    required this.onDispatchDueJobs,
    required this.onRunJob,
    required this.summary,
  });

  final List<Map<String, dynamic>> failedJobs;
  final bool actionBusy;
  final Future<void> Function() onDispatchDueJobs;
  final Future<void> Function(String jobId) onRunJob;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: actionBusy ? null : onDispatchDueJobs,
          icon: const Icon(Icons.play_arrow_outlined),
          label: const Text('Dispatch due jobs'),
        ),
        const SizedBox(height: 14),
        if (failedJobs.isEmpty)
          const Text('No failed jobs are visible in the command workspace.')
        else
          ...failedJobs.take(8).map((job) {
            final id = _read(job, 'id', '');
            return _ActionRow(
              title: _read(job, 'type', 'Failed job'),
              severity: _read(job, 'status', 'FAILED'),
              subtitle:
                  '${_read(job, 'campaignName', 'Campaign unknown')} - ${_read(job, 'error', 'No error message')}',
              timestamp: _read(job, 'updatedAt', ''),
              actions: [
                TextButton.icon(
                  onPressed: actionBusy || id.isEmpty ? null : () => onRunJob(id),
                  icon: const Icon(Icons.replay_outlined),
                  label: const Text('Run job'),
                ),
              ],
            );
          }),
      ],
    );
  }
}

class _AlertDrilldown extends StatelessWidget {
  const _AlertDrilldown({
    required this.alerts,
    required this.attention,
    required this.actionBusy,
    required this.onResolveAlert,
  });

  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> attention;
  final bool actionBusy;
  final Future<void> Function(String alertId) onResolveAlert;

  @override
  Widget build(BuildContext context) {
    final items = alerts.isNotEmpty ? alerts : attention;
    if (items.isEmpty) {
      return const Text('No open alerts or attention items are visible.');
    }
    return Column(
      children: items.take(10).map((item) {
        final id = _read(item, 'id', '');
        final isAlert = _read(item, 'kind', 'alert') == 'alert' ||
            _read(item, 'status', '').isNotEmpty;
        return _ActionRow(
          title: _firstText(item, ['title', 'label', 'type', 'summary'], 'Alert'),
          severity: _firstText(item, ['severity', 'status'], 'INFO'),
          subtitle: _firstText(item, ['source', 'message', 'description'], ''),
          timestamp: _firstText(item, ['createdAt', 'updatedAt'], ''),
          actions: [
            if (isAlert && id.isNotEmpty)
              TextButton.icon(
                onPressed:
                    actionBusy ? null : () => onResolveAlert(id),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Resolve'),
              ),
          ],
        );
      }).toList(),
    );
  }
}

class _SuppressionForm extends StatelessWidget {
  const _SuppressionForm({
    required this.emailController,
    required this.domainController,
    required this.reasonController,
    required this.type,
    required this.actionBusy,
    required this.onTypeChanged,
    required this.onCreate,
  });

  final TextEditingController emailController;
  final TextEditingController domainController;
  final TextEditingController reasonController;
  final String type;
  final bool actionBusy;
  final ValueChanged<String?> onTypeChanged;
  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
        ),
        SizedBox(
          width: 220,
          child: TextField(
            controller: domainController,
            decoration: const InputDecoration(labelText: 'Domain'),
          ),
        ),
        SizedBox(
          width: 210,
          child: DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(labelText: 'Suppression type'),
            items: const [
              DropdownMenuItem(value: 'MANUAL_BLOCK', child: Text('Manual block')),
              DropdownMenuItem(value: 'UNSUBSCRIBE', child: Text('Unsubscribe')),
              DropdownMenuItem(value: 'HARD_BOUNCE', child: Text('Hard bounce')),
              DropdownMenuItem(value: 'COMPLAINT', child: Text('Complaint')),
            ],
            onChanged: actionBusy ? null : onTypeChanged,
          ),
        ),
        SizedBox(
          width: 320,
          child: TextField(
            controller: reasonController,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
        ),
        FilledButton.icon(
          onPressed: actionBusy ? null : onCreate,
          icon: const Icon(Icons.block_outlined),
          label: const Text('Add suppression'),
        ),
      ],
    );
  }
}

class _CampaignRecovery extends StatelessWidget {
  const _CampaignRecovery({
    required this.campaigns,
    required this.actionBusy,
    required this.onActivateCampaign,
  });

  final List<Map<String, dynamic>> campaigns;
  final bool actionBusy;
  final Future<void> Function(String campaignId) onActivateCampaign;

  @override
  Widget build(BuildContext context) {
    if (campaigns.isEmpty) {
      return const Text('No campaigns are visible in command workspace.');
    }
    return Column(
      children: campaigns.take(10).map((campaign) {
        final id = _read(campaign, 'id', '');
        final status = _read(campaign, 'status', 'UNKNOWN');
        final operational = _asMap(campaign['operational']);
        return _ActionRow(
          title: _read(campaign, 'name', 'Campaign'),
          severity: status,
          subtitle:
              '${_statusLabel(status)} - ${_read(operational, 'campaignStatus', _read(campaign, 'channel', ''))}',
          timestamp: _firstText(campaign, ['updatedAt', 'createdAt'], ''),
          actions: [
            if (id.isNotEmpty && status != 'ACTIVE')
              TextButton.icon(
                onPressed:
                    actionBusy ? null : () => onActivateCampaign(id),
                icon: const Icon(Icons.restart_alt_outlined),
                label: const Text('Recover'),
              ),
          ],
        );
      }).toList(),
    );
  }
}

class _RawDrilldowns extends StatelessWidget {
  const _RawDrilldowns({required this.data});

  final _DebugViewData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RawTile(title: 'Operator context', value: data.context),
        _RawTile(title: 'Command overview', value: data.command),
        _RawTile(title: 'Command workspace', value: data.workspace),
        _RawTile(title: 'Deliverability overview', value: data.deliverability),
      ],
    );
  }
}

class _RawTile extends StatelessWidget {
  const _RawTile({required this.title, required this.value});

  final String title;
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(const JsonEncoder.withIndent('  ').convert(value)),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.severity,
    required this.subtitle,
    required this.timestamp,
    required this.actions,
  });

  final String title;
  final String severity;
  final String subtitle;
  final String timestamp;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.28),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 12,
        children: [
          SizedBox(
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    _SeverityChip(value: severity),
                  ],
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
                if (timestamp.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Updated: ${_formatTimestamp(timestamp)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
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

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final normalized = value.toUpperCase();
    final theme = Theme.of(context);
    final color = normalized.contains('CRITICAL') ||
            normalized.contains('FAILED') ||
            normalized.contains('ERROR')
        ? theme.colorScheme.error
        : normalized.contains('WARN') ||
                normalized.contains('WATCH') ||
                normalized.contains('DEGRADED') ||
                normalized.contains('PAUSED')
            ? Colors.amber.shade700
            : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(_statusLabel(value), style: theme.textTheme.bodySmall),
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

class _NoticeLine extends StatelessWidget {
  const _NoticeLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline,
            size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    );
  }
}

class _SimpleList extends StatelessWidget {
  const _SimpleList({required this.emptyText, required this.items});

  final String emptyText;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Text(emptyText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) ...[
          Text(item),
          const SizedBox(height: 8),
        ],
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
        'Execution has mixed lifecycle signals; use the aggregate counts before taking recovery action.');
  }
  if (_intValue(suppressionAudit['totalSuppressedLeads']) > 0) {
    warnings.add(
        '${_intValue(suppressionAudit['totalSuppressedLeads'])} leads are suppressed or blocked from outreach.');
  }
  if (_read(permissionSummary, 'status', '') == 'NO_CONSENT_RECORDS') {
    warnings.add(
        'Permissions are empty because no consent records are loaded for this scope.');
  }
  if (warnings.isEmpty) warnings.add('No immediate control warnings are visible.');
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

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
}

String _formatTimestamp(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return _formatDateTime(parsed);
}

String _displayError(Object? error, {required String fallback}) {
  if (error is ApiException) return error.displayMessage;
  return fallback;
}
