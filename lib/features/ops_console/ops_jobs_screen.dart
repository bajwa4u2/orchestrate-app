import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'ops_console_repository.dart';
import 'ops_empty_state.dart';

class OpsJobsScreen extends StatefulWidget {
  const OpsJobsScreen({super.key});

  @override
  State<OpsJobsScreen> createState() => _OpsJobsScreenState();
}

class _OpsJobsScreenState extends State<OpsJobsScreen> {
  final _repo = OpsConsoleRepository();

  List<Map<String, dynamic>> _jobs = [];
  bool _loading = true;
  String? _error;

  final Map<String, bool> _expanded = {};
  final Map<String, _Act> _action = {};
  final Map<String, List<Map<String, dynamic>>> _history = {};
  final Map<String, bool> _historyLoading = {};

  bool _dispatchingDue = false;
  String? _dispatchResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _repo.fetchExecutionWorkspace(limit: 50);
      if (!mounted) return;
      final raw = data['jobs'] ?? data['rows'] ?? data['data'];
      setState(() {
        _jobs = raw is List
            ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadHistory(String jobId) async {
    if (_history.containsKey(jobId)) return;
    setState(() => _historyLoading[jobId] = true);
    try {
      final data = await _repo.fetchJobAudit(jobId, limit: 5);
      if (!mounted) return;
      final rows = data['rows'] as List? ?? [];
      setState(() {
        _history[jobId] = rows.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _historyLoading.remove(jobId);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _history[jobId] = []; _historyLoading.remove(jobId); });
    }
  }

  Future<void> _retryJob(String jobId) async {
    final reason = await _reasonDialog(context, 'Retry job');
    if (reason == null) return;
    setState(() => _action[jobId] = _Act.working('Retrying…'));
    try {
      final result = await _repo.retryJob(jobId, reason: reason.isEmpty ? null : reason);
      if (!mounted) return;
      final status = result['status'] as String? ?? 'QUEUED';
      setState(() => _action[jobId] = _Act.done('Queued — $status'));
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _action[jobId] = _Act.error(e.toString()));
    }
  }

  Future<void> _cancelJob(String jobId) async {
    final reason = await _reasonDialog(context, 'Cancel job');
    if (reason == null) return;
    setState(() => _action[jobId] = _Act.working('Canceling…'));
    try {
      await _repo.cancelJob(jobId, reason: reason.isEmpty ? null : reason);
      if (!mounted) return;
      setState(() => _action[jobId] = _Act.done('Canceled'));
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _action[jobId] = _Act.error(e.toString()));
    }
  }

  Future<void> _dispatchDue() async {
    setState(() { _dispatchingDue = true; _dispatchResult = null; });
    try {
      final result = await _repo.dispatchDueJobs();
      if (!mounted) return;
      final count = result['dispatched'] as int? ?? result['count'] as int?;
      setState(() {
        _dispatchingDue = false;
        _dispatchResult = count != null ? 'Dispatched $count due job${count == 1 ? '' : 's'}' : 'Dispatch-due complete';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _dispatchingDue = false; _dispatchResult = 'Error: $e'; });
    }
  }

  int get _failedCount => _jobs.where((j) => j['status'] == 'FAILED').length;
  int get _runningCount => _jobs.where((j) => j['status'] == 'RUNNING' || j['status'] == 'QUEUED').length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScreenHeader(
          title: 'Jobs',
          subtitle: '${_jobs.length} job${_jobs.length == 1 ? '' : 's'}'
              '${_failedCount > 0 ? ' · $_failedCount failed' : ''}'
              '${_runningCount > 0 ? ' · $_runningCount active' : ''}'
              ' in this organisation',
          loading: _loading,
          dispatchResult: _dispatchResult,
          isDispatching: _dispatchingDue,
          onRefresh: _loading ? null : _load,
          onDispatchDue: _dispatchingDue ? null : _dispatchDue,
        ),
        const SizedBox(height: 20),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    if (_error != null) return _ErrorPanel(message: _error!, onRetry: _load);
    if (_jobs.isEmpty) return const OpsEmptyState(headline: 'No jobs in this organisation.');
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final j = _jobs[i];
        final id = j['id'] as String? ?? '$i';
        return _JobCard(
          job: j,
          action: _action[id],
          expanded: _expanded[id] ?? false,
          history: _history[id],
          historyLoading: _historyLoading[id] ?? false,
          onToggle: () {
            final next = !(_expanded[id] ?? false);
            setState(() => _expanded[id] = next);
            if (next) _loadHistory(id);
          },
          onRetry: () => _retryJob(id),
          onCancel: () => _cancelJob(id),
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job, required this.expanded, required this.action,
    required this.history, required this.historyLoading,
    required this.onToggle, required this.onRetry, required this.onCancel,
  });
  final Map<String, dynamic> job;
  final bool expanded;
  final _Act? action;
  final List<Map<String, dynamic>>? history;
  final bool historyLoading;
  final VoidCallback onToggle;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  String get _id => job['id'] as String? ?? '';
  String get _type => job['type'] as String? ?? job['jobType'] as String? ?? job['name'] as String? ?? _id;
  String? get _status => job['status'] as String?;
  int get _attempts => (job['attemptCount'] as num?)?.toInt() ?? 0;
  int get _maxAttempts => (job['maxAttempts'] as num?)?.toInt() ?? 0;
  String? get _lastError => job['lastError'] as String?;

  Color _statusColor(String? s) {
    switch (s?.toUpperCase()) {
      case 'SUCCEEDED': case 'COMPLETED': return AppTheme.emerald;
      case 'RUNNING': return AppTheme.accent;
      case 'QUEUED': case 'RETRY_SCHEDULED': return AppTheme.amber;
      case 'FAILED': return AppTheme.rose;
      case 'CANCELED': return AppTheme.subdued;
      default: return AppTheme.subdued;
    }
  }

  Color get _severity {
    final s = _status?.toUpperCase();
    if (s == 'FAILED') return _isCriticalType ? AppTheme.rose : AppTheme.amber;
    if (s == 'CANCELED') return AppTheme.amber;
    if (s == 'RUNNING' || s == 'QUEUED') return AppTheme.accent;
    return AppTheme.emerald;
  }

  bool get _isCriticalType {
    const critTypes = {'FIRST_SEND', 'FOLLOWUP_SEND', 'REPLY_RESPONSE_SEND', 'INBOX_SYNC'};
    return critTypes.contains(_type.toUpperCase());
  }

  String _startedLabel() {
    final ts = job['startedAt'] as String? ?? job['createdAt'] as String?;
    if (ts == null) return '—';
    try {
      final d = DateTime.parse(ts).toLocal();
      return '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}';
    } catch (_) { return ts; }
  }

  static String _p(int n) => n.toString().padLeft(2, '0');

  List<Map<String, dynamic>> get _evidence {
    final base = <Map<String, dynamic>>[
      {'label': 'Status', 'value': _status ?? '—',
        if (_status == 'FAILED') 'severity': 'critical',
        if (_status == 'CANCELED') 'severity': 'warning'},
      {'label': 'Job type', 'value': _type},
    ];
    if (_maxAttempts > 0) {
      base.add({'label': 'Attempts', 'value': '$_attempts / $_maxAttempts',
        if (_attempts >= _maxAttempts) 'severity': 'critical'});
    }
    base.add({'label': 'Started', 'value': _startedLabel()});
    if (job['campaignId'] != null) {
      base.add({'label': 'Campaign', 'value': job['campaign']?['name'] ?? job['campaignId']});
    }
    if (job['clientId'] != null) {
      base.add({'label': 'Client', 'value': job['client']?['displayName'] ?? job['clientId']});
    }
    return base;
  }

  String get _diagnosis {
    final s = _status?.toUpperCase();
    switch (s) {
      case 'FAILED':
        return 'Job type $_type exhausted all $_maxAttempts retry attempts. '
            '${_lastError != null ? 'Last error: ${_lastError!.length > 100 ? '${_lastError!.substring(0, 100)}…' : _lastError}. ' : ''}'
            'Fix the underlying cause before retrying.';
      case 'CANCELED':
        return 'Job was canceled. Retry if the underlying intent should still be fulfilled.';
      case 'RUNNING':
        return 'Job is actively running. No action required.';
      case 'QUEUED': case 'RETRY_SCHEDULED':
        return 'Job is queued and will run shortly. No action required.';
      case 'SUCCEEDED': case 'COMPLETED':
        return 'Job completed successfully.';
      default:
        return 'Status unrecognized. Check execution logs.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(_status);
    final isFailed = _status?.toUpperCase() == 'FAILED';
    final isCanceled = _status?.toUpperCase() == 'CANCELED';
    final isRunning = _status?.toUpperCase() == 'RUNNING';
    final isQueued = _status?.toUpperCase() == 'QUEUED' || _status?.toUpperCase() == 'RETRY_SCHEDULED';

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
                Text(_type, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14, fontFamily: 'monospace')),
                Text(_startedLabel(), style: const TextStyle(fontSize: 11, color: AppTheme.subdued)),
              ])),
              if (_maxAttempts > 0 && _attempts > 0)
                Container(margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.panelRaised, borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: AppTheme.line)),
                    child: Text('$_attempts/$_maxAttempts',
                        style: const TextStyle(fontSize: 9, color: AppTheme.subdued))),
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
                  if (isFailed || isCanceled)
                    _OutcomeBtn(label: 'Retry job', outcome: 'RESOLVE', onTap: onRetry),
                  if (isRunning || isQueued)
                    _OutcomeBtn(label: 'Cancel job', outcome: 'INTERRUPT', onTap: onCancel),
                  if (!isFailed && !isCanceled && !isRunning && !isQueued)
                    const Text('No actions available for this state.',
                        style: TextStyle(fontSize: 12, color: AppTheme.subdued)),
                ]),
              if (action != null && !(action!.isWorking)) _ActFeedback(action!),
              const SizedBox(height: 14),

              _RingLabel('Verification source'), const SizedBox(height: 6),
              _VerifSource('jobs/$_id/audit', 'rows[0].action',
                  isFailed ? 'operator.job.retry' : isCanceled ? 'operator.job.retry' : null),
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

// ─── Screen header with dispatch-due ─────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({
    required this.title, required this.subtitle, required this.loading,
    required this.isDispatching, this.dispatchResult,
    this.onRefresh, this.onDispatchDue,
  });
  final String title; final String subtitle; final bool loading;
  final bool isDispatching; final String? dispatchResult;
  final VoidCallback? onRefresh; final VoidCallback? onDispatchDue;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.muted)),
        ])),
        if (isDispatching)
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
        else if (onDispatchDue != null) ...[
          OutlinedButton(onPressed: onDispatchDue,
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accent, side: BorderSide(color: AppTheme.accent.withOpacity(0.4))),
              child: const Text('Dispatch due')),
          const SizedBox(width: 8),
        ],
        if (onRefresh != null)
          OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.muted, side: const BorderSide(color: AppTheme.line))),
      ]),
      if (dispatchResult != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(AppTheme.radius)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.accent),
            const SizedBox(width: 6),
            Text(dispatchResult!, style: const TextStyle(fontSize: 12, color: AppTheme.accent)),
          ]),
        ),
      ],
    ]);
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

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

Future<String?> _reasonDialog(BuildContext context, String label) async {
  final ctrl = TextEditingController();
  return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
    backgroundColor: AppTheme.panelRaised,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
    title: Text(label, style: const TextStyle(fontSize: 15, color: AppTheme.text)),
    content: TextField(controller: ctrl, style: const TextStyle(fontSize: 13, color: AppTheme.text), maxLines: 2,
        decoration: InputDecoration(hintText: 'Reason (optional)', hintStyle: const TextStyle(color: AppTheme.subdued, fontSize: 12),
            filled: true, fillColor: AppTheme.panel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radius), borderSide: const BorderSide(color: AppTheme.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radius), borderSide: BorderSide(color: AppTheme.accent.withOpacity(0.6))))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.subdued))),
      FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
          child: Text(label, style: const TextStyle(color: AppTheme.background, fontSize: 13))),
    ],
  ));
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
