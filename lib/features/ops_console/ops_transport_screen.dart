import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'ops_console_repository.dart';

class OpsTransportScreen extends StatefulWidget {
  const OpsTransportScreen({super.key});

  @override
  State<OpsTransportScreen> createState() => _OpsTransportScreenState();
}

class _OpsTransportScreenState extends State<OpsTransportScreen> {
  final _repo = OpsConsoleRepository();

  List<Map<String, dynamic>> _mailboxes = [];
  List<Map<String, dynamic>> _domains = [];
  bool _loading = true;
  String? _error;
  String _tab = 'mailboxes';

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
      final data = await _repo.fetchDeliverabilityOverview();
      if (!mounted) return;
      setState(() {
        final rawM = data['mailboxes'];
        _mailboxes = rawM is List
            ? rawM.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
            : [];
        final rawD = data['domains'];
        _domains = rawD is List
            ? rawD.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadHistory(String id, String entityType) async {
    if (_history.containsKey(id)) return;
    setState(() => _historyLoading[id] = true);
    try {
      final endpoint = entityType == 'Mailbox'
          ? '/operator/mailboxes/$id/audit'
          : '/operator/domains/$id/audit';
      final data = await _repo.rawGet(endpoint, query: {'limit': '5'});
      if (!mounted) return;
      final rows = data['rows'] as List? ?? [];
      setState(() {
        _history[id] = rows.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _historyLoading.remove(id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _history[id] = []; _historyLoading.remove(id); });
    }
  }

  Future<void> _runAction(String id, String endpoint, String label,
      {bool confirm = false, _ProofData? proofData}) async {
    if (proofData != null) {
      final result = await _proofDialog(context, id);
      if (result == null) return;
      setState(() => _action[id] = _Act.working('Sending proof…'));
      try {
        await _repo.proofOutbound(mailboxId: id, to: result.to, subject: result.subject);
        if (!mounted) return;
        setState(() => _action[id] = _Act.done('Proof sent to ${result.to}'));
      } catch (e) {
        if (!mounted) return;
        setState(() => _action[id] = _Act.error(e.toString()));
      }
      return;
    }
    if (confirm) {
      final ok = await _confirmDialog(context, label);
      if (ok != true) return;
    }
    setState(() => _action[id] = _Act.working(label));
    try {
      await _repo.rawPost(endpoint);
      if (!mounted) return;
      setState(() => _action[id] = _Act.done('$label — done'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _action[id] = _Act.error(e.toString()));
    }
  }

  int get _reauthCount => _mailboxes.where((m) {
    final s = m['connectionState'] as String?;
    return s == 'REQUIRES_REAUTH' || s == 'REVOKED';
  }).length;
  int get _failedDomainCount => _domains.where((d) =>
      d['status'] == 'BLOCKED' || (d['status'] == 'PENDING' && d['failedReason'] != null)).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScreenHeader(
          title: 'Transport',
          subtitle: '${_mailboxes.length} mailbox${_mailboxes.length == 1 ? '' : 'es'} · ${_domains.length} domain${_domains.length == 1 ? '' : 's'}'
              '${_reauthCount > 0 ? ' · $_reauthCount need re-auth' : ''}'
              '${_failedDomainCount > 0 ? ' · $_failedDomainCount DNS issue${_failedDomainCount > 1 ? 's' : ''}' : ''}',
          loading: _loading,
          onRefresh: _loading ? null : _load,
        ),
        const SizedBox(height: 16),
        _TabRow(current: _tab, onSelect: (t) => setState(() => _tab = t)),
        const SizedBox(height: 16),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    if (_error != null) return _ErrorPanel(message: _error!, onRetry: _load);
    final list = _tab == 'mailboxes' ? _mailboxes : _domains;
    if (list.isEmpty) return _EmptyState(label: 'No ${_tab} found.');
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final entity = list[i];
        final id = entity['id'] as String? ?? '$i';
        if (_tab == 'mailboxes') {
          return _MailboxCard(
            mailbox: entity,
            action: _action[id],
            expanded: _expanded[id] ?? false,
            history: _history[id],
            historyLoading: _historyLoading[id] ?? false,
            onToggle: () {
              final next = !(_expanded[id] ?? false);
              setState(() => _expanded[id] = next);
              if (next) _loadHistory(id, 'Mailbox');
            },
            onAction: (ep, label, {bool confirm = false, bool isProof = false}) =>
                _runAction(id, ep, label, confirm: confirm, proofData: isProof ? const _ProofData() : null),
          );
        }
        return _DomainCard(
          domain: entity,
          action: _action[id],
          expanded: _expanded[id] ?? false,
          history: _history[id],
          historyLoading: _historyLoading[id] ?? false,
          onToggle: () {
            final next = !(_expanded[id] ?? false);
            setState(() => _expanded[id] = next);
            if (next) _loadHistory(id, 'SendingDomain');
          },
          onAction: (ep, label, {bool confirm = false}) =>
              _runAction(id, ep, label, confirm: confirm),
        );
      },
    );
  }
}

class _MailboxCard extends StatelessWidget {
  const _MailboxCard({
    required this.mailbox, required this.expanded, required this.action,
    required this.history, required this.historyLoading,
    required this.onToggle, required this.onAction,
  });
  final Map<String, dynamic> mailbox;
  final bool expanded;
  final _Act? action;
  final List<Map<String, dynamic>>? history;
  final bool historyLoading;
  final VoidCallback onToggle;
  final void Function(String ep, String label, {bool confirm, bool isProof}) onAction;

  String get _id => mailbox['id'] as String? ?? '';
  String get _email => mailbox['emailAddress'] as String? ?? _id;
  String? get _connState => mailbox['connectionState'] as String?;
  String? get _health => mailbox['healthStatus'] as String?;
  String? get _provider => mailbox['provider'] as String?;

  Color _connColor(String? s) {
    switch (s) {
      case 'AUTHORIZED': return AppTheme.emerald;
      case 'REQUIRES_REAUTH': return AppTheme.amber;
      case 'REVOKED': return AppTheme.rose;
      case 'PENDING_AUTH': return AppTheme.accent;
      default: return AppTheme.subdued;
    }
  }

  Color get _severity {
    if (_connState == 'REVOKED') return AppTheme.rose;
    if (_connState == 'REQUIRES_REAUTH') return AppTheme.amber;
    if (_health == 'DEGRADED') return AppTheme.amber;
    return AppTheme.emerald;
  }

  String _disconnectedLabel() {
    final ts = mailbox['disconnectedAt'] as String?;
    if (ts == null) return '';
    try {
      final d = DateTime.parse(ts);
      final h = DateTime.now().difference(d).inHours;
      return h < 24 ? ' · ${h}h ago' : ' · ${(h / 24).floor()}d ago';
    } catch (_) { return ''; }
  }

  List<Map<String, dynamic>> get _evidence => [
    {'label': 'Connection', 'value': _connState ?? '—',
      if (_connState == 'REQUIRES_REAUTH' || _connState == 'REVOKED') 'severity': 'critical'},
    {'label': 'Health', 'value': _health ?? '—',
      if (_health == 'DEGRADED') 'severity': 'warning'},
    if (_provider != null) {'label': 'Provider', 'value': _provider},
    if (mailbox['clientName'] != null) {'label': 'Client', 'value': mailbox['clientName']},
    if (mailbox['disconnectedAt'] != null) {'label': 'Disconnected', 'value': _disconnectedLabel().replaceAll(' · ', '')},
  ];

  String get _diagnosis {
    switch (_connState) {
      case 'AUTHORIZED': return 'Mailbox is authorized and ready to dispatch. ${_health == 'DEGRADED' ? 'Health is degraded — monitor send rates.' : 'No action required.'}';
      case 'REQUIRES_REAUTH': return 'OAuth token has expired. All dispatch through this mailbox is blocked until the client re-authorizes via the reconnect link.';
      case 'REVOKED': return 'OAuth access has been revoked by the provider or client. A new authorization flow is required.';
      case 'PENDING_AUTH': return 'Awaiting initial authorization. Client must complete the OAuth flow.';
      default: return 'Connection state unrecognized. Check mailbox configuration.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = _connColor(_connState);
    final needsReauth = _connState == 'REQUIRES_REAUTH' || _connState == 'REVOKED';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: expanded ? _severity.withOpacity(0.35) : AppTheme.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              Container(width: 3, height: 40, margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(color: _severity, borderRadius: BorderRadius.circular(2))),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_email, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14)),
                if (_provider != null)
                  Text('${_provider!.toLowerCase()}${_disconnectedLabel()}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.subdued)),
              ])),
              if (_connState != null)
                Container(margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(_connState!.toUpperCase().replaceAll('_', ' '),
                        style: TextStyle(fontSize: 10, color: sc, fontWeight: FontWeight.w600))),
              Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: AppTheme.subdued),
            ]),
          ),
        ),

        if (expanded) ...[
          Divider(height: 1, color: AppTheme.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _RingLabel('Evidence'), const SizedBox(height: 6),
              _EvidTable(rows: _evidence), const SizedBox(height: 14),

              _RingLabel('Diagnosis'), const SizedBox(height: 6),
              Text(_diagnosis, style: const TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.5)),
              const SizedBox(height: 14),

              _RingLabel('Actions'), const SizedBox(height: 8),
              if (action?.isWorking ?? false)
                _WorkingRow(action!.message)
              else
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (needsReauth)
                    _OutcomeBtn(label: 'Send reconnect link', outcome: 'INTERRUPT',
                        onTap: () => onAction('/operator/mailboxes/$_id/send-reconnect-link', 'Send reconnect link', confirm: true)),
                  _OutcomeBtn(label: 'Refresh health', outcome: 'RESOLVE',
                      onTap: () => onAction('/deliverability/mailboxes/$_id/refresh-health', 'Refresh health')),
                  _OutcomeBtn(label: 'Proof outbound', outcome: 'FORWARD',
                      onTap: () => onAction('', 'Proof outbound', isProof: true)),
                ]),
              if (action != null && !(action!.isWorking)) _ActFeedback(action!),
              const SizedBox(height: 14),

              _RingLabel('Verification source'), const SizedBox(height: 6),
              _VerifSource('mailboxes/$_id/audit', 'rows[0].action', needsReauth ? 'operator.mailbox.reconnect_link_sent' : null),
              const SizedBox(height: 14),

              _RingLabel('History'), const SizedBox(height: 6),
              if (historyLoading)
                const SizedBox(height: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)))
              else
                _HistList(rows: history ?? []),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({
    required this.domain, required this.expanded, required this.action,
    required this.history, required this.historyLoading,
    required this.onToggle, required this.onAction,
  });
  final Map<String, dynamic> domain;
  final bool expanded;
  final _Act? action;
  final List<Map<String, dynamic>>? history;
  final bool historyLoading;
  final VoidCallback onToggle;
  final void Function(String ep, String label, {bool confirm}) onAction;

  String get _id => domain['id'] as String? ?? '';
  String get _domainName => domain['domain'] as String? ?? _id;
  String? get _status => domain['status'] as String?;
  String? get _failedReason => domain['failedReason'] as String?;

  Color _statusColor(String? s) {
    switch (s) {
      case 'ACTIVE': return AppTheme.emerald;
      case 'PENDING': return AppTheme.accent;
      case 'BLOCKED': return AppTheme.rose;
      case 'PAUSED': return AppTheme.amber;
      default: return AppTheme.subdued;
    }
  }

  Color get _severity {
    if (_status == 'BLOCKED') return AppTheme.rose;
    if (_status == 'PENDING' && _failedReason != null) return AppTheme.amber;
    return AppTheme.emerald;
  }

  String _checkedLabel() {
    final ts = domain['lastCheckedAt'] as String?;
    if (ts == null) return '—';
    try {
      final d = DateTime.parse(ts);
      final h = DateTime.now().difference(d).inHours;
      return h < 24 ? '${h}h ago' : '${(h / 24).floor()}d ago';
    } catch (_) { return ts; }
  }

  List<Map<String, dynamic>> get _evidence => [
    {'label': 'Status', 'value': _status ?? '—',
      if (_status == 'BLOCKED') 'severity': 'critical',
      if (_status == 'PENDING' && _failedReason != null) 'severity': 'warning'},
    if (_failedReason != null) {'label': 'Failed reason', 'value': _failedReason, 'severity': 'warning'},
    {'label': 'Last checked', 'value': _checkedLabel()},
    if (domain['clientName'] != null) {'label': 'Client', 'value': domain['clientName']},
  ];

  String get _diagnosis {
    if (_status == 'BLOCKED') return 'Domain DNS verification has permanently failed. SPF, DKIM, or DMARC records are missing or misconfigured. Deliverability is blocked.';
    if (_status == 'PENDING' && _failedReason != null) return 'DNS verification is pending but has previously failed: $_failedReason. Send DNS instructions to the client and recheck after records are updated.';
    if (_status == 'ACTIVE') return 'Domain verified and active. All DNS records are in place. No action required.';
    if (_status == 'PAUSED') return 'Domain is paused. No sending through this domain until unpaused.';
    return 'DNS state unrecognized. Run a recheck to get the current verification status.';
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(_status);
    final needsDns = _status == 'BLOCKED' || (_status == 'PENDING' && _failedReason != null);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: expanded ? _severity.withOpacity(0.35) : AppTheme.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              Container(width: 3, height: 40, margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(color: _severity, borderRadius: BorderRadius.circular(2))),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_domainName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14)),
                Text('Last checked: ${_checkedLabel()}', style: const TextStyle(fontSize: 11, color: AppTheme.subdued)),
              ])),
              if (_status != null)
                Container(margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(_status!.toUpperCase(), style: TextStyle(fontSize: 10, color: sc, fontWeight: FontWeight.w600))),
              Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: AppTheme.subdued),
            ]),
          ),
        ),

        if (expanded) ...[
          Divider(height: 1, color: AppTheme.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _RingLabel('Evidence'), const SizedBox(height: 6),
              _EvidTable(rows: _evidence), const SizedBox(height: 14),

              _RingLabel('Diagnosis'), const SizedBox(height: 6),
              Text(_diagnosis, style: const TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.5)),
              const SizedBox(height: 14),

              _RingLabel('Actions'), const SizedBox(height: 8),
              if (action?.isWorking ?? false)
                _WorkingRow(action!.message)
              else
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _OutcomeBtn(label: 'Recheck DNS', outcome: 'RESOLVE',
                      onTap: () => onAction('/operator/domains/$_id/recheck-dns', 'Recheck DNS')),
                  if (needsDns)
                    _OutcomeBtn(label: 'Send DNS instructions', outcome: 'FORWARD',
                        onTap: () => onAction('/operator/domains/$_id/send-dns-instructions', 'Send DNS instructions')),
                ]),
              if (action != null && !(action!.isWorking)) _ActFeedback(action!),
              const SizedBox(height: 14),

              _RingLabel('Verification source'), const SizedBox(height: 6),
              _VerifSource('domains/$_id/audit', 'rows[0].action', 'operator.domain.dns_recheck'),
              const SizedBox(height: 14),

              _RingLabel('History'), const SizedBox(height: 6),
              if (historyLoading)
                const SizedBox(height: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)))
              else
                _HistList(rows: history ?? []),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─── Tab bar ─────────────────────────────────────────────────────────────────

class _TabRow extends StatelessWidget {
  const _TabRow({required this.current, required this.onSelect});
  final String current;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _Tab(label: 'Mailboxes', value: 'mailboxes', current: current, onSelect: onSelect),
      const SizedBox(width: 4),
      _Tab(label: 'Domains', value: 'domains', current: current, onSelect: onSelect),
    ]);
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.value, required this.current, required this.onSelect});
  final String label; final String value; final String current; final void Function(String) onSelect;
  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: active ? AppTheme.accent.withOpacity(0.4) : AppTheme.line),
        ),
        child: Text(label, style: TextStyle(fontSize: 12,
            color: active ? AppTheme.accent : AppTheme.subdued,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

// ─── Proof dialog ─────────────────────────────────────────────────────────────

class _ProofData { const _ProofData(); }

class _ProofResult {
  const _ProofResult(this.to, this.subject);
  final String to; final String? subject;
}

Future<_ProofResult?> _proofDialog(BuildContext context, String mailboxId) async {
  final toCtrl = TextEditingController();
  final subCtrl = TextEditingController();
  return showDialog<_ProofResult>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.panelRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
      title: const Text('Proof outbound', style: TextStyle(fontSize: 15, color: AppTheme.text)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: toCtrl, style: const TextStyle(fontSize: 13, color: AppTheme.text),
            decoration: InputDecoration(hintText: 'To (email address)', hintStyle: const TextStyle(color: AppTheme.subdued, fontSize: 12),
                filled: true, fillColor: AppTheme.panel,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radius), borderSide: const BorderSide(color: AppTheme.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radius), borderSide: BorderSide(color: AppTheme.accent.withOpacity(0.6))))),
        const SizedBox(height: 8),
        TextField(controller: subCtrl, style: const TextStyle(fontSize: 13, color: AppTheme.text),
            decoration: InputDecoration(hintText: 'Subject (optional)', hintStyle: const TextStyle(color: AppTheme.subdued, fontSize: 12),
                filled: true, fillColor: AppTheme.panel,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radius), borderSide: const BorderSide(color: AppTheme.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radius), borderSide: BorderSide(color: AppTheme.accent.withOpacity(0.6))))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.subdued))),
        FilledButton(
          onPressed: () {
            if (toCtrl.text.trim().isEmpty) return;
            Navigator.pop(ctx, _ProofResult(toCtrl.text.trim(), subCtrl.text.trim().isEmpty ? null : subCtrl.text.trim()));
          },
          style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
          child: const Text('Send proof', style: TextStyle(color: AppTheme.background, fontSize: 13)),
        ),
      ],
    ),
  );
}

Future<bool?> _confirmDialog(BuildContext context, String label) =>
    showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.panelRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
      title: Text(label, style: const TextStyle(fontSize: 15, color: AppTheme.text)),
      content: const Text('Confirm this action?', style: TextStyle(fontSize: 13, color: AppTheme.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.subdued))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Confirm', style: TextStyle(color: AppTheme.background, fontSize: 13))),
      ],
    ));

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.title, required this.subtitle, required this.loading, this.onRefresh});
  final String title; final String subtitle; final bool loading; final VoidCallback? onRefresh;
  @override Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.muted)),
    ])),
    if (onRefresh != null)
      OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.muted, side: const BorderSide(color: AppTheme.line))),
  ]);
}

class _RingLabel extends StatelessWidget {
  const _RingLabel(this.l); final String l;
  @override Widget build(BuildContext context) => Text(l.toUpperCase(),
      style: const TextStyle(fontSize: 9, color: AppTheme.subdued, fontWeight: FontWeight.w700, letterSpacing: 0.8));
}

class _EvidTable extends StatelessWidget {
  const _EvidTable({required this.rows}); final List<Map<String, dynamic>> rows;
  static Color _sc(String? s) { switch (s) { case 'critical': return AppTheme.rose; case 'warning': return AppTheme.amber; default: return AppTheme.muted; } }
  @override Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('—', style: TextStyle(fontSize: 12, color: AppTheme.subdued));
    return Container(
      decoration: BoxDecoration(color: AppTheme.panelRaised, borderRadius: BorderRadius.circular(AppTheme.radius), border: Border.all(color: AppTheme.line)),
      child: Column(children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: AppTheme.line.withOpacity(0.5)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              Expanded(flex: 2, child: Text(rows[i]['label']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.subdued))),
              Expanded(flex: 3, child: Text(rows[i]['value']?.toString() ?? '—',
                  style: TextStyle(fontSize: 11, color: _sc(rows[i]['severity'] as String?),
                      fontWeight: rows[i]['severity'] != null ? FontWeight.w600 : FontWeight.normal))),
            ])),
        ],
      ]),
    );
  }
}

class _HistList extends StatelessWidget {
  const _HistList({required this.rows}); final List<Map<String, dynamic>> rows;
  @override Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('No audit history.', style: TextStyle(fontSize: 11, color: AppTheme.subdued));
    return Column(children: rows.take(5).map((r) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 4, height: 4, margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.line)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r['action']?.toString() ?? '—', style: const TextStyle(fontSize: 11, color: AppTheme.muted, fontFamily: 'monospace')),
          if (r['createdAt'] != null) Text(_ts(r['createdAt'].toString()), style: const TextStyle(fontSize: 10, color: AppTheme.subdued)),
        ])),
      ]),
    )).toList());
  }
  static String _ts(String iso) { try { final dt = DateTime.parse(iso).toLocal(); return '${dt.year}-${_p(dt.month)}-${_p(dt.day)} ${_p(dt.hour)}:${_p(dt.minute)}'; } catch (_) { return iso; } }
  static String _p(int n) => n.toString().padLeft(2, '0');
}

class _VerifSource extends StatelessWidget {
  const _VerifSource(this.ep, this.field, this.value);
  final String ep; final String field; final String? value;
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: AppTheme.panelRaised, borderRadius: BorderRadius.circular(AppTheme.radius), border: Border.all(color: AppTheme.line)),
    child: Row(children: [
      const Icon(Icons.verified_outlined, size: 13, color: AppTheme.accent),
      const SizedBox(width: 8),
      Expanded(child: Text('GET /operator/$ep — $field${value != null ? ' = $value' : ''}',
          style: const TextStyle(fontSize: 11, color: AppTheme.subdued, fontFamily: 'monospace'))),
    ]),
  );
}

class _OutcomeBtn extends StatelessWidget {
  const _OutcomeBtn({required this.label, required this.outcome, required this.onTap});
  final String label; final String outcome; final VoidCallback onTap;
  Color _c() { switch (outcome) { case 'RESOLVE': return AppTheme.emerald; case 'INTERRUPT': return AppTheme.rose; case 'FORWARD': return AppTheme.accent; default: return AppTheme.subdued; } }
  @override Widget build(BuildContext context) {
    final c = _c();
    return OutlinedButton(onPressed: onTap,
      style: OutlinedButton.styleFrom(foregroundColor: c, side: BorderSide(color: c.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(outcome, style: TextStyle(fontSize: 8, color: c.withOpacity(0.7), letterSpacing: 0.3)),
      ]));
  }
}

class _WorkingRow extends StatelessWidget {
  const _WorkingRow(this.msg); final String? msg;
  @override Widget build(BuildContext context) => Row(children: [
    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
    const SizedBox(width: 8),
    Text(msg ?? 'Running…', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
  ]);
}

class _ActFeedback extends StatelessWidget {
  const _ActFeedback(this.act); final _Act act;
  @override Widget build(BuildContext context) {
    final c = act.isDone ? AppTheme.emerald : AppTheme.rose;
    return Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
      Icon(act.isDone ? Icons.check_circle_outline : Icons.error_outline, size: 13, color: c),
      const SizedBox(width: 6),
      Expanded(child: Text(act.message ?? '', style: TextStyle(fontSize: 11, color: c))),
    ]));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label}); final String label;
  @override Widget build(BuildContext context) => Center(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.muted)));
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message; final VoidCallback onRetry;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.warning_amber_outlined, size: 40, color: AppTheme.amber),
    const SizedBox(height: 12),
    Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.muted)),
    const SizedBox(height: 20),
    FilledButton(onPressed: onRetry, style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
        child: const Text('Retry', style: TextStyle(color: AppTheme.background))),
  ])));
}

class _Act {
  _Act.working(this.message) : _k = _K.working;
  _Act.done(this.message) : _k = _K.done;
  _Act.error(this.message) : _k = _K.error;
  final _K _k; final String? message;
  bool get isWorking => _k == _K.working;
  bool get isDone => _k == _K.done;
}
enum _K { working, done, error }
