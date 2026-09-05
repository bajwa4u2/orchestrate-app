import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'ops_console_repository.dart';
import 'ops_empty_state.dart';

/// Dispatch & Governance — per-campaign custody of outreach messages.
///
/// Fetches the governance review queue (RETRYABLE_FAILED + FAILED messages),
/// groups by campaign, and renders each group as a six-ring custody card.
class OpsDispatchScreen extends StatefulWidget {
  const OpsDispatchScreen({super.key});

  @override
  State<OpsDispatchScreen> createState() => _OpsDispatchScreenState();
}

class _OpsDispatchScreenState extends State<OpsDispatchScreen> {
  final _repo = OpsConsoleRepository();

  List<_DispatchGroup> _groups = [];
  bool _loading = true;
  String? _error;

  final Map<String, bool> _expanded = {};
  final Map<String, _Act> _groupAction = {};
  final Map<String, Map<String, _Act>> _msgAction = {};
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
      final msgs = await _repo.fetchDispatchReviewQueue(limit: 200);
      if (!mounted) return;
      setState(() {
        _groups = _buildGroups(msgs);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<_DispatchGroup> _buildGroups(List<Map<String, dynamic>> msgs) {
    final byId = <String, List<Map<String, dynamic>>>{};
    for (final m in msgs) {
      final key = m['campaignId'] as String? ?? 'unknown';
      byId.putIfAbsent(key, () => []).add(m);
    }
    return byId.entries.map((e) {
      final list = e.value;
      final first = list.first;
      return _DispatchGroup(
        campaignId: e.key,
        campaignName: first['campaign']?['name'] as String? ?? first['campaignName'] as String? ?? e.key,
        clientName: first['client']?['displayName'] as String? ?? first['clientName'] as String?,
        messages: list,
      );
    }).toList()
      ..sort((a, b) => b.criticalCount.compareTo(a.criticalCount));
  }

  Future<void> _loadHistory(String campaignId) async {
    if (_history.containsKey(campaignId)) return;
    setState(() => _historyLoading[campaignId] = true);
    try {
      final data = await _repo.fetchCampaignAudit(campaignId, limit: 5);
      if (!mounted) return;
      final rows = data['rows'] as List? ?? [];
      setState(() {
        _history[campaignId] = rows.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _historyLoading.remove(campaignId);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _history[campaignId] = []; _historyLoading.remove(campaignId); });
    }
  }

  Future<void> _clearCampaignFailed(String campaignId) async {
    final ok = await _confirmDialog(context, 'Clear all failed dispatches');
    if (ok != true) return;
    setState(() => _groupAction[campaignId] = _Act.working('Clearing…'));
    try {
      await _repo.clearCampaignFailed(campaignId);
      if (!mounted) return;
      setState(() => _groupAction[campaignId] = _Act.done('Cleared — reloading'));
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _groupAction[campaignId] = _Act.error(e.toString()));
    }
  }

  Future<void> _retryMessage(String campaignId, String messageId) async {
    _msgAction.putIfAbsent(campaignId, () => {})[messageId] = _Act.working('Retrying…');
    setState(() {});
    try {
      await _repo.retryMessage(messageId);
      if (!mounted) return;
      _msgAction[campaignId]![messageId] = _Act.done('Queued');
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _msgAction[campaignId]![messageId] = _Act.error(e.toString());
      setState(() {});
    }
  }

  Future<void> _terminalMessage(String campaignId, String messageId) async {
    final reason = await _reasonDialog(context, 'Terminal message');
    if (reason == null) return;
    _msgAction.putIfAbsent(campaignId, () => {})[messageId] = _Act.working('Terminating…');
    setState(() {});
    try {
      await _repo.terminalMessage(messageId, reason: reason.isEmpty ? null : reason);
      if (!mounted) return;
      _msgAction[campaignId]![messageId] = _Act.done('Terminated');
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _msgAction[campaignId]![messageId] = _Act.error(e.toString());
      setState(() {});
    }
  }

  Future<void> _dismissMessage(String campaignId, String messageId) async {
    _msgAction.putIfAbsent(campaignId, () => {})[messageId] = _Act.working('Dismissing…');
    setState(() {});
    try {
      await _repo.dismissMessage(messageId);
      if (!mounted) return;
      _msgAction[campaignId]![messageId] = _Act.done('Dismissed');
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _msgAction[campaignId]![messageId] = _Act.error(e.toString());
      setState(() {});
    }
  }

  int get _totalMessages => _groups.fold(0, (s, g) => s + g.messages.length);
  int get _criticalGroups => _groups.where((g) => g.criticalCount > 0).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScreenHeader(
          title: 'Dispatch & Governance',
          subtitle: '${_groups.length} campaign${_groups.length == 1 ? '' : 's'}'
              ' · $_totalMessages message${_totalMessages == 1 ? '' : 's'}'
              '${_criticalGroups > 0 ? ' · $_criticalGroups with failures' : ''}',
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
    if (_groups.isEmpty) {
      return const OpsEmptyState(
          headline: 'Nothing failed in this organisation.');
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final g = _groups[i];
        return _DispatchGroupCard(
          group: g,
          groupAction: _groupAction[g.campaignId],
          msgActions: _msgAction[g.campaignId] ?? {},
          expanded: _expanded[g.campaignId] ?? false,
          history: _history[g.campaignId],
          historyLoading: _historyLoading[g.campaignId] ?? false,
          onToggle: () {
            final next = !(_expanded[g.campaignId] ?? false);
            setState(() => _expanded[g.campaignId] = next);
            if (next) _loadHistory(g.campaignId);
          },
          onClearFailed: () => _clearCampaignFailed(g.campaignId),
          onRetryMsg: (mid) => _retryMessage(g.campaignId, mid),
          onTerminalMsg: (mid) => _terminalMessage(g.campaignId, mid),
          onDismissMsg: (mid) => _dismissMessage(g.campaignId, mid),
        );
      },
    );
  }
}

class _DispatchGroup {
  const _DispatchGroup({
    required this.campaignId, required this.campaignName,
    required this.clientName, required this.messages,
  });
  final String campaignId;
  final String campaignName;
  final String? clientName;
  final List<Map<String, dynamic>> messages;

  int get retryableCount => messages.where((m) => m['status'] == 'RETRYABLE_FAILED').length;
  int get failedCount => messages.where((m) => m['status'] == 'FAILED').length;
  int get criticalCount => failedCount;
}

class _DispatchGroupCard extends StatelessWidget {
  const _DispatchGroupCard({
    required this.group, required this.groupAction, required this.msgActions,
    required this.expanded, required this.history, required this.historyLoading,
    required this.onToggle, required this.onClearFailed,
    required this.onRetryMsg, required this.onTerminalMsg, required this.onDismissMsg,
  });
  final _DispatchGroup group;
  final _Act? groupAction;
  final Map<String, _Act> msgActions;
  final bool expanded;
  final List<Map<String, dynamic>>? history;
  final bool historyLoading;
  final VoidCallback onToggle;
  final VoidCallback onClearFailed;
  final void Function(String mid) onRetryMsg;
  final void Function(String mid) onTerminalMsg;
  final void Function(String mid) onDismissMsg;

  Color get _severity {
    if (group.failedCount > 0) return AppTheme.rose;
    if (group.retryableCount > 0) return AppTheme.amber;
    return AppTheme.accent;
  }

  String get _stateLabel {
    if (group.failedCount > 0 && group.retryableCount > 0) return 'Failed + Retryable';
    if (group.failedCount > 0) return 'Terminal failures';
    return 'Retryable failures';
  }

  List<Map<String, dynamic>> get _evidence => [
    {'label': 'Retryable', 'value': group.retryableCount,
      if (group.retryableCount > 0) 'severity': 'warning'},
    {'label': 'Terminal failed', 'value': group.failedCount,
      if (group.failedCount > 0) 'severity': 'critical'},
    {'label': 'Total in queue', 'value': group.messages.length},
  ];

  String get _diagnosis {
    if (group.failedCount > 0 && group.retryableCount > 0) {
      return '${group.retryableCount} message${group.retryableCount == 1 ? '' : 's'} can be retried. '
          '${group.failedCount} have permanently failed and require terminal or dismiss. '
          'Retry retryable messages first, then clear terminal failures.';
    }
    if (group.failedCount > 0) {
      return '${group.failedCount} message${group.failedCount == 1 ? '' : 's'} have permanently failed. '
          'Each must be marked terminal or dismissed before the campaign queue clears.';
    }
    return '${group.retryableCount} message${group.retryableCount == 1 ? '' : 's'} failed with a retryable error '
        '(rate limit or temporary SMTP). Retry when the underlying cause has cleared.';
  }

  @override
  Widget build(BuildContext context) {
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
                Text(group.campaignName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14)),
                if (group.clientName != null)
                  Text(group.clientName!, style: const TextStyle(fontSize: 11, color: AppTheme.subdued)),
              ])),
              Container(margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: _severity.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(_stateLabel, style: TextStyle(fontSize: 10, color: _severity, fontWeight: FontWeight.w600))),
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

              _RingLabel('Messages'), const SizedBox(height: 8),
              ...group.messages.take(20).map((m) {
                final mid = m['id'] as String? ?? '';
                final mAct = msgActions[mid];
                return _MessageRow(
                  message: m, action: mAct,
                  onRetry: () => onRetryMsg(mid),
                  onTerminal: () => onTerminalMsg(mid),
                  onDismiss: () => onDismissMsg(mid),
                );
              }),
              if (group.messages.length > 20)
                Padding(padding: const EdgeInsets.only(top: 4),
                    child: Text('… and ${group.messages.length - 20} more',
                        style: const TextStyle(fontSize: 11, color: AppTheme.subdued))),
              const SizedBox(height: 14),

              _RingLabel('Campaign actions'), const SizedBox(height: 8),
              if (groupAction?.isWorking ?? false)
                _WorkingRow(groupAction!.message)
              else
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _OutcomeBtn(label: 'Clear all failed', outcome: 'INTERRUPT', onTap: onClearFailed),
                ]),
              if (groupAction != null && !(groupAction!.isWorking)) _ActFeedback(groupAction!),
              const SizedBox(height: 14),

              _RingLabel('Verification source'), const SizedBox(height: 6),
              _VerifSource('governance/review-queue?campaignId=${group.campaignId}', 'length', '0'),
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

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.action,
      required this.onRetry, required this.onTerminal, required this.onDismiss});
  final Map<String, dynamic> message;
  final _Act? action;
  final VoidCallback onRetry;
  final VoidCallback onTerminal;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final status = message['status'] as String? ?? '—';
    final lead = message['lead'] as Map?;
    final leadName = lead?['contact']?['fullName'] as String?
        ?? lead?['email'] as String?
        ?? message['leadId'] as String? ?? '—';
    final errorMsg = message['errorMessage'] as String?;
    final isRetryable = status == 'RETRYABLE_FAILED';
    final isFailed = status == 'FAILED';
    final sc = isRetryable ? AppTheme.amber : AppTheme.rose;
    final isWorking = action?.isWorking ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(color: AppTheme.panelRaised,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 5, height: 5, margin: const EdgeInsets.only(right: 8, top: 1),
              decoration: BoxDecoration(shape: BoxShape.circle, color: sc)),
          Expanded(child: Text(leadName, style: const TextStyle(fontSize: 12, color: AppTheme.text))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
              child: Text(status, style: TextStyle(fontSize: 9, color: sc, fontWeight: FontWeight.w600))),
        ]),
        if (errorMsg != null)
          Padding(padding: const EdgeInsets.only(top: 3, left: 13),
              child: Text(errorMsg.length > 100 ? '${errorMsg.substring(0, 100)}…' : errorMsg,
                  style: const TextStyle(fontSize: 10, color: AppTheme.subdued))),
        if (isWorking)
          Padding(padding: const EdgeInsets.only(top: 6, left: 13), child: _WorkingRow(action!.message))
        else if (action != null)
          Padding(padding: const EdgeInsets.only(top: 4, left: 13), child: _ActFeedback(action!))
        else
          Padding(padding: const EdgeInsets.only(top: 6, left: 13), child: Wrap(spacing: 6, children: [
            if (isRetryable)
              _SmallBtn(label: 'Retry', color: AppTheme.emerald, onTap: onRetry),
            if (isFailed || isRetryable)
              _SmallBtn(label: 'Terminal', color: AppTheme.rose, onTap: onTerminal),
            _SmallBtn(label: 'Dismiss', color: AppTheme.subdued, onTap: onDismiss),
          ])),
      ]),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  const _SmallBtn({required this.label, required this.color, required this.onTap});
  final String label; final Color color; final VoidCallback onTap;
  @override Widget build(BuildContext context) => OutlinedButton(onPressed: onTap,
    style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    child: Text(label, style: const TextStyle(fontSize: 10)));
}

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
    return Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
      Icon(act.isDone ? Icons.check_circle_outline : Icons.error_outline, size: 12, color: c),
      const SizedBox(width: 5),
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
