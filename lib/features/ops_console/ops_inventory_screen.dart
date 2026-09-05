import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'ops_console_repository.dart';
import 'ops_empty_state.dart';

class OpsInventoryScreen extends StatefulWidget {
  const OpsInventoryScreen({super.key});

  @override
  State<OpsInventoryScreen> createState() => _OpsInventoryScreenState();
}

class _OpsInventoryScreenState extends State<OpsInventoryScreen> {
  final _repo = OpsConsoleRepository();

  List<Map<String, dynamic>> _batches = [];
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
      final data = await _repo.fetchImportBatches(limit: 50);
      if (!mounted) return;
      final raw = data['batches'] ?? data['rows'] ?? data['data'];
      setState(() {
        _batches = raw is List
            ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadHistory(String id) async {
    if (_history.containsKey(id)) return;
    setState(() => _historyLoading[id] = true);
    try {
      // Import batch audit is not per-batch — use generic entity audit via rawGet
      final data = await _repo.rawGet('/operator/audit',
          query: {'entityType': 'ImportBatch', 'entityId': id, 'limit': '5'});
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
      {bool confirm = false}) async {
    if (confirm) {
      final ok = await _confirmDialog(context, label);
      if (ok != true) return;
    }
    setState(() => _action[id] = _Act.working(label));
    try {
      await _repo.rawPost(endpoint);
      if (!mounted) return;
      setState(() => _action[id] = _Act.done('$label — triggered'));
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _action[id] = _Act.error(e.toString()));
    }
  }

  int get _failedCount => _batches.where((b) => b['status'] == 'FAILED').length;
  int get _canceledCount => _batches.where((b) => b['status'] == 'CANCELED').length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScreenHeader(
          title: 'Inventory & Imports',
          subtitle: '${_batches.length} batch${_batches.length == 1 ? '' : 'es'}'
              '${_failedCount > 0 ? ' · $_failedCount failed' : ''}'
              '${_canceledCount > 0 ? ' · $_canceledCount canceled' : ''}'
              ' — custody view',
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
    if (_batches.isEmpty) return const OpsEmptyState(headline: 'No imports in this organisation.');
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _batches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final b = _batches[i];
        final id = b['id'] as String? ?? '$i';
        return _BatchCard(
          batch: b,
          action: _action[id],
          expanded: _expanded[id] ?? false,
          history: _history[id],
          historyLoading: _historyLoading[id] ?? false,
          onToggle: () {
            final next = !(_expanded[id] ?? false);
            setState(() => _expanded[id] = next);
            if (next) _loadHistory(id);
          },
          onAction: (ep, label, {bool confirm = false}) =>
              _runAction(id, ep, label, confirm: confirm),
        );
      },
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    required this.batch, required this.expanded, required this.action,
    required this.history, required this.historyLoading,
    required this.onToggle, required this.onAction,
  });
  final Map<String, dynamic> batch;
  final bool expanded;
  final _Act? action;
  final List<Map<String, dynamic>>? history;
  final bool historyLoading;
  final VoidCallback onToggle;
  final void Function(String ep, String label, {bool confirm}) onAction;

  String get _id => batch['id'] as String? ?? '';
  String get _label => batch['sourceLabel'] as String? ?? _id;
  String? get _status => batch['status'] as String?;
  int get _total => (batch['totalRows'] as num?)?.toInt() ?? 0;
  int get _failed => (batch['failedRows'] as num?)?.toInt() ?? 0;
  int get _created => (batch['createdRows'] as num?)?.toInt() ?? 0;

  Color _statusColor(String? s) {
    switch (s) {
      case 'COMPLETED': return AppTheme.emerald;
      case 'PROCESSING': case 'UPLOADED': return AppTheme.accent;
      case 'FAILED': return AppTheme.rose;
      case 'CANCELED': return AppTheme.amber;
      default: return AppTheme.subdued;
    }
  }

  Color get _severity {
    if (_status == 'FAILED') return AppTheme.rose;
    if (_status == 'CANCELED') return AppTheme.amber;
    return AppTheme.accent;
  }

  String _staleLabel() {
    final ts = batch['updatedAt'] as String?;
    if (ts == null) return '—';
    try {
      final d = DateTime.parse(ts);
      final h = DateTime.now().difference(d).inHours;
      if (h < 24) return '${h}h ago';
      return '${(h / 24).floor()}d ago';
    } catch (_) { return ts; }
  }

  List<Map<String, dynamic>> get _evidence => [
    {'label': 'Status', 'value': _status ?? '—', if (_status == 'FAILED') 'severity': 'critical', if (_status == 'CANCELED') 'severity': 'warning'},
    {'label': 'Total rows', 'value': _total},
    {'label': 'Created rows', 'value': _created},
    if (_failed > 0) {'label': 'Failed rows', 'value': _failed, 'severity': 'warning'},
    {'label': 'Last updated', 'value': _staleLabel()},
    if (batch['campaign'] != null) {'label': 'Campaign', 'value': (batch['campaign'] as Map)['name'] ?? '—'},
  ];

  String get _diagnosis {
    switch (_status) {
      case 'COMPLETED': return 'Import completed. $_created leads created from $_total rows.${_failed > 0 ? ' $_failed rows failed processing.' : ''}';
      case 'PROCESSING': return 'Import is currently processing. No action required.';
      case 'UPLOADED': return 'Import uploaded and queued for processing.';
      case 'FAILED': return 'Import failed with $_failed row errors out of $_total total. Re-promote to retry the import pipeline from the start.';
      case 'CANCELED': return 'Import was canceled. $_created rows were created before cancellation. Re-promote to retry.';
      default: return 'Status unrecognized. Inspect the batch detail for errors.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(_status);
    final isFailed = _status == 'FAILED';
    final isCanceled = _status == 'CANCELED';

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
                Text(_label, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14)),
                Text('$_total rows · $_created created${_failed > 0 ? ' · $_failed failed' : ''}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.subdued)),
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
              _RingLabel('Evidence'),
              const SizedBox(height: 6),
              _EvidTable(rows: _evidence),
              const SizedBox(height: 14),

              _RingLabel('Diagnosis'),
              const SizedBox(height: 6),
              Text(_diagnosis, style: const TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.5)),
              const SizedBox(height: 14),

              _RingLabel('Actions'),
              const SizedBox(height: 8),
              if (action?.isWorking ?? false)
                _WorkingRow(action!.message)
              else
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (isFailed || isCanceled) ...[
                    _OutcomeBtn(label: 'Re-promote', outcome: 'RESOLVE',
                        onTap: () => onAction('/operator/imports/$_id/re-promote', 'Re-promote', confirm: true)),
                    _OutcomeBtn(label: 'Re-qualify leads', outcome: 'RESOLVE',
                        onTap: () => onAction('/operator/imports/$_id/re-qualify', 'Re-qualify leads')),
                  ],
                  _OutcomeBtn(label: 'View detail', outcome: 'FORWARD',
                      onTap: () => onAction('/operator/imports/$_id', 'View detail')),
                ]),
              if (action != null && !(action!.isWorking)) _ActFeedback(action!),
              const SizedBox(height: 14),

              _RingLabel('Verification source'),
              const SizedBox(height: 6),
              _VerifSource('imports/$_id', 'status', 'UPLOADED'),
              const SizedBox(height: 14),

              _RingLabel('History'),
              const SizedBox(height: 6),
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

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.title, required this.subtitle, required this.loading, this.onRefresh});
  final String title; final String subtitle; final bool loading; final VoidCallback? onRefresh;
  @override
  Widget build(BuildContext context) => Row(children: [
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
  const _EvidTable({required this.rows});
  final List<Map<String, dynamic>> rows;
  static Color _sc(String? s) { switch (s) { case 'critical': return AppTheme.rose; case 'warning': return AppTheme.amber; default: return AppTheme.muted; } }
  @override
  Widget build(BuildContext context) {
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

class _Act {
  _Act.working(this.message) : _k = _K.working;
  _Act.done(this.message) : _k = _K.done;
  _Act.error(this.message) : _k = _K.error;
  final _K _k; final String? message;
  bool get isWorking => _k == _K.working;
  bool get isDone => _k == _K.done;
}
enum _K { working, done, error }
