import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'ops_console_repository.dart';
import 'ops_empty_state.dart';

class OpsClientsScreen extends StatefulWidget {
  const OpsClientsScreen({super.key});

  @override
  State<OpsClientsScreen> createState() => _OpsClientsScreenState();
}

class _OpsClientsScreenState extends State<OpsClientsScreen> {
  final _repo = OpsConsoleRepository();

  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  String? _error;

  final Map<String, bool> _expanded = {};
  final Map<String, _Act> _action = {};
  final Map<String, List<Map<String, dynamic>>> _history = {};
  final Map<String, bool> _historyLoading = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _repo.fetchReadinessBoard();
      if (!mounted) return;
      final raw = data['clients'] ?? data['rows'] ?? data['data'];
      setState(() {
        _clients = raw is List
            ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadHistory(String clientId) async {
    if (_history.containsKey(clientId)) return;
    setState(() => _historyLoading[clientId] = true);
    try {
      final data = await _repo.fetchClientAudit(clientId, limit: 5);
      if (!mounted) return;
      final rows = data['rows'] as List? ?? [];
      setState(() {
        _history[clientId] = rows.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _historyLoading.remove(clientId);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _history[clientId] = []; _historyLoading.remove(clientId); });
    }
  }

  Future<void> _runAction(String clientId, String endpoint, String label,
      {bool confirm = false}) async {
    if (confirm) {
      final ok = await _confirmDialog(context, label);
      if (ok != true) return;
    }
    setState(() => _action[clientId] = _Act.working(label));
    try {
      await _repo.rawPost(endpoint);
      if (!mounted) return;
      setState(() => _action[clientId] = _Act.done('$label — triggered'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _action[clientId] = _Act.error(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScreenHeader(
          title: 'Clients',
          subtitle: '${_clients.length} client${_clients.length == 1 ? '' : 's'} in this organisation',
          loading: _loading,
          onRefresh: _loading ? null : _load,
        ),
        const SizedBox(height: 20),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    if (_error != null) return _ErrorPanel(message: _error!, onRetry: _load);
    if (_clients.isEmpty) {
      // "No clients found" reads as an absence of clients. It is not one.
      // This list is scoped to the organisation the session belongs to, and a
      // platform operator's organisation holds no client businesses of its
      // own — the client businesses on the platform each belong to their own.
      // Saying so is the difference between a quiet dead end and a stated
      // boundary somebody can decide about.
      return const OpsEmptyState(
          headline: 'No clients in this organisation.');
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _clients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = _clients[i];
        final id = c['id'] as String? ?? c['clientId'] as String? ?? '$i';
        return _ClientCard(
          client: c,
          action: _action[id],
          expanded: _expanded[id] ?? false,
          history: _history[id],
          historyLoading: _historyLoading[id] ?? false,
          onToggle: () {
            setState(() => _expanded[id] = !(_expanded[id] ?? false));
            if (!(_expanded[id] ?? false) == false) _loadHistory(id);
          },
          onAction: (ep, label, {bool confirm = false}) =>
              _runAction(id, ep, label, confirm: confirm),
        );
      },
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.expanded,
    required this.action,
    required this.history,
    required this.historyLoading,
    required this.onToggle,
    required this.onAction,
  });
  final Map<String, dynamic> client;
  final bool expanded;
  final _Act? action;
  final List<Map<String, dynamic>>? history;
  final bool historyLoading;
  final VoidCallback onToggle;
  final void Function(String ep, String label, {bool confirm}) onAction;

  String get _clientId =>
      client['id'] as String? ?? client['clientId'] as String? ?? '';
  String get _name =>
      (client['displayName'] as String? ?? '').trim().isNotEmpty
          ? client['displayName'] as String
          : client['legalName'] as String? ?? _clientId;
  String? get _executionState =>
      client['executionState'] as String? ?? client['state'] as String?;
  String? get _bucket =>
      client['readinessBucket'] as String? ?? client['bucket'] as String?;

  Color _stateColor(String? s) {
    switch (s?.toUpperCase()) {
      case 'DISPATCHING': return AppTheme.emerald;
      case 'READY_IDLE': return AppTheme.accent;
      case 'GOVERNANCE_BLOCKED': return AppTheme.rose;
      case 'RATE_LIMITED': return AppTheme.amber;
      case 'DEGRADED': return AppTheme.amber;
      case 'BLOCKED': return AppTheme.rose;
      default: return AppTheme.subdued;
    }
  }

  Color get _severity {
    final s = _executionState?.toUpperCase();
    if (s == 'GOVERNANCE_BLOCKED' || s == 'BLOCKED') return AppTheme.rose;
    if (s == 'RATE_LIMITED' || s == 'DEGRADED') return AppTheme.amber;
    return AppTheme.accent;
  }

  List<Map<String, dynamic>> get _evidence {
    return [
      {'label': 'Execution state', 'value': _executionState ?? '—'},
      {'label': 'Readiness bucket', 'value': _bucket ?? '—'},
      if (client['activeCampaignCount'] != null)
        {'label': 'Active campaigns', 'value': client['activeCampaignCount']},
      if (client['authorizedMailboxCount'] != null)
        {'label': 'Authorized mailboxes', 'value': client['authorizedMailboxCount']},
      if (client['verifiedDomainCount'] != null)
        {'label': 'Verified domains', 'value': client['verifiedDomainCount']},
      if (client['readyLeadCount'] != null)
        {'label': 'Ready leads', 'value': client['readyLeadCount']},
    ];
  }

  String get _diagnosis {
    final s = _executionState?.toUpperCase();
    switch (s) {
      case 'DISPATCHING': return 'Client is actively dispatching messages. No intervention required.';
      case 'READY_IDLE': return 'Client is ready to dispatch but no messages are currently due. Normal state between send windows.';
      case 'GOVERNANCE_BLOCKED': return 'Client is blocked by governance. Check mailbox authorization, domain verification, and active campaign state.';
      case 'RATE_LIMITED': return 'Client has hit the configured send rate cap. Dispatch will resume when the window resets.';
      case 'DEGRADED': return 'Partial degradation — some mailboxes or campaigns are blocked. Review transport and campaign state.';
      default: return 'State is unknown or not yet evaluated. Force an adaptation run to re-evaluate.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = _stateColor(_executionState);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: expanded ? _severity.withOpacity(0.35) : AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Container(width: 3, height: 40, margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(color: _severity, borderRadius: BorderRadius.circular(2))),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14)),
                      if (_executionState != null)
                        Text(_executionState!, style: const TextStyle(fontSize: 11, color: AppTheme.subdued)),
                    ],
                  )),
                  if (_bucket != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(_bucket!.toUpperCase(),
                          style: TextStyle(fontSize: 10, color: sc, fontWeight: FontWeight.w600)),
                    ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: AppTheme.subdued),
                ],
              ),
            ),
          ),

          if (expanded) ...[
            Divider(height: 1, color: AppTheme.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RingLabel('Evidence'),
                  const SizedBox(height: 6),
                  _EvidTable(rows: _evidence),
                  const SizedBox(height: 14),

                  _RingLabel('Diagnosis'),
                  const SizedBox(height: 6),
                  Text(_diagnosis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.5)),
                  const SizedBox(height: 14),

                  _RingLabel('Actions'),
                  const SizedBox(height: 8),
                  if (action?.isWorking ?? false)
                    _WorkingRow(action!.message)
                  else
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      _OutcomeBtn(
                        label: 'Force discovery',
                        outcome: 'RESOLVE',
                        onTap: () => onAction(
                          '/signals/discovery/profiles?clientId=$_clientId',
                          'Force discovery',
                        ),
                      ),
                      _OutcomeBtn(
                        label: 'Force adaptation',
                        outcome: 'RESOLVE',
                        onTap: () => onAction(
                          '/adaptation/clients/$_clientId/run',
                          'Force adaptation',
                        ),
                      ),
                    ]),
                  if (action != null && !(action!.isWorking))
                    _ActFeedback(action!),
                  const SizedBox(height: 14),

                  _RingLabel('Verification source'),
                  const SizedBox(height: 6),
                  _VerifSource('clients/$_clientId/audit', 'rows[0].action', null),
                  const SizedBox(height: 14),

                  _RingLabel('History'),
                  const SizedBox(height: 6),
                  if (historyLoading)
                    const SizedBox(height: 20, child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)))
                  else
                    _HistList(rows: history ?? []),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Shared inner widgets (private to this file) ──────────────────────────────

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.title, required this.subtitle, required this.loading, this.onRefresh});
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.muted)),
      ])),
      if (onRefresh != null)
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.muted,
              side: const BorderSide(color: AppTheme.line)),
        ),
    ]);
  }
}

class _RingLabel extends StatelessWidget {
  const _RingLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: const TextStyle(fontSize: 9, color: AppTheme.subdued,
          fontWeight: FontWeight.w700, letterSpacing: 0.8));
}

class _EvidTable extends StatelessWidget {
  const _EvidTable({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('—', style: TextStyle(fontSize: 12, color: AppTheme.subdued));
    return Container(
      decoration: BoxDecoration(color: AppTheme.panelRaised,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.line)),
      child: Column(children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: AppTheme.line.withOpacity(0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              Expanded(flex: 2, child: Text(rows[i]['label']?.toString() ?? '',
                  style: const TextStyle(fontSize: 11, color: AppTheme.subdued))),
              Expanded(flex: 3, child: Text(rows[i]['value']?.toString() ?? '—',
                  style: TextStyle(fontSize: 11,
                      color: _sevColor(rows[i]['severity'] as String?),
                      fontWeight: rows[i]['severity'] != null ? FontWeight.w600 : FontWeight.normal))),
            ]),
          ),
        ],
      ]),
    );
  }

  static Color _sevColor(String? s) {
    switch (s) {
      case 'critical': return AppTheme.rose;
      case 'warning': return AppTheme.amber;
      default: return AppTheme.muted;
    }
  }
}

class _HistList extends StatelessWidget {
  const _HistList({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('No audit history.', style: TextStyle(fontSize: 11, color: AppTheme.subdued));
    return Column(children: rows.take(5).map((r) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 4, height: 4, margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.line)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r['action']?.toString() ?? '—',
              style: const TextStyle(fontSize: 11, color: AppTheme.muted, fontFamily: 'monospace')),
          if (r['createdAt'] != null)
            Text(_ts(r['createdAt'].toString()),
                style: const TextStyle(fontSize: 10, color: AppTheme.subdued)),
        ])),
      ]),
    )).toList());
  }

  static String _ts(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${_p(dt.month)}-${_p(dt.day)} ${_p(dt.hour)}:${_p(dt.minute)}';
    } catch (_) { return iso; }
  }
  static String _p(int n) => n.toString().padLeft(2, '0');
}

class _VerifSource extends StatelessWidget {
  const _VerifSource(this.endpoint, this.field, this.value);
  final String endpoint;
  final String field;
  final String? value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: AppTheme.panelRaised,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line)),
    child: Row(children: [
      const Icon(Icons.verified_outlined, size: 13, color: AppTheme.accent),
      const SizedBox(width: 8),
      Expanded(child: Text(
        'GET /operator/$endpoint — $field${value != null ? ' = $value' : ''}',
        style: const TextStyle(fontSize: 11, color: AppTheme.subdued, fontFamily: 'monospace'),
      )),
    ]),
  );
}

class _OutcomeBtn extends StatelessWidget {
  const _OutcomeBtn({required this.label, required this.outcome, required this.onTap});
  final String label;
  final String outcome;
  final VoidCallback onTap;

  Color _color() {
    switch (outcome) {
      case 'RESOLVE': return AppTheme.emerald;
      case 'INTERRUPT': return AppTheme.rose;
      case 'FORWARD': return AppTheme.accent;
      case 'DISMISS': return AppTheme.subdued;
      default: return AppTheme.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: c,
        side: BorderSide(color: c.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(outcome, style: TextStyle(fontSize: 8, color: c.withOpacity(0.7), letterSpacing: 0.3)),
      ]),
    );
  }
}

class _WorkingRow extends StatelessWidget {
  const _WorkingRow(this.message);
  final String? message;
  @override
  Widget build(BuildContext context) => Row(children: [
    const SizedBox(width: 14, height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
    const SizedBox(width: 8),
    Text(message ?? 'Running…', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
  ]);
}

class _ActFeedback extends StatelessWidget {
  const _ActFeedback(this.act);
  final _Act act;
  @override
  Widget build(BuildContext context) {
    final color = act.isDone ? AppTheme.emerald : AppTheme.rose;
    final icon = act.isDone ? Icons.check_circle_outline : Icons.error_outline;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(act.message ?? '', style: TextStyle(fontSize: 11, color: color))),
      ]),
    );
  }
}


class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.warning_amber_outlined, size: 40, color: AppTheme.amber),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.muted)),
      const SizedBox(height: 20),
      FilledButton(onPressed: onRetry,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
          child: const Text('Retry', style: TextStyle(color: AppTheme.background))),
    ]),
  ));
}

Future<bool?> _confirmDialog(BuildContext context, String label) =>
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.panelRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Text(label, style: const TextStyle(fontSize: 15, color: AppTheme.text)),
        content: const Text('Confirm this action?',
            style: TextStyle(fontSize: 13, color: AppTheme.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.subdued))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
              child: const Text('Confirm', style: TextStyle(color: AppTheme.background, fontSize: 13))),
        ],
      ),
    );

class _Act {
  _Act.working(this.message) : _k = _K.working;
  _Act.done(this.message) : _k = _K.done;
  _Act.error(this.message) : _k = _K.error;
  final _K _k;
  final String? message;
  bool get isWorking => _k == _K.working;
  bool get isDone => _k == _K.done;
}

enum _K { working, done, error }
