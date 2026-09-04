import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'ops_console_repository.dart';

class OpsWorkQueueScreen extends StatefulWidget {
  const OpsWorkQueueScreen({super.key});

  @override
  State<OpsWorkQueueScreen> createState() => _OpsWorkQueueScreenState();
}

class _OpsWorkQueueScreenState extends State<OpsWorkQueueScreen> {
  final _repo = OpsConsoleRepository();

  List<Map<String, dynamic>> _cases = [];
  String? _generatedAt;
  bool _loading = true;
  String? _error;

  // Per-case action state: case id → _CaseAction
  final Map<String, _CaseAction> _action = {};

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
      final data = await _repo.fetchWorkQueue();
      if (!mounted) return;
      final rawCases = data['cases'];
      setState(() {
        _cases = rawCases is List
            ? rawCases.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
            : [];
        _generatedAt = data['generatedAt'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int get _criticalCount =>
      _cases.where((c) => c['severity'] == 'critical').length;
  int get _warningCount =>
      _cases.where((c) => c['severity'] == 'warning').length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          caseCount: _cases.length,
          criticalCount: _criticalCount,
          warningCount: _warningCount,
          generatedAt: _generatedAt,
          loading: _loading,
          onRefresh: _loading ? null : _load,
        ),
        const SizedBox(height: 20),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_error != null) {
      return _ErrorPanel(message: _error!, onRetry: _load);
    }
    if (_cases.isEmpty) {
      return const _EmptyState();
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _cases.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = _cases[i];
        final id = c['id'] as String? ?? '$i';
        return _CaseCard(
          wqCase: c,
          action: _action[id],
          onAction: (action) => _runAction(id, c, action),
        );
      },
    );
  }

  Future<void> _runAction(
    String caseId,
    Map<String, dynamic> wqCase,
    Map<String, dynamic> action,
  ) async {
    final requiresConfirmation = action['requiresConfirmation'] as bool? ?? false;
    final requiresReason = action['requiresReason'] as bool? ?? false;

    String? reason;
    if (requiresConfirmation || requiresReason) {
      final result = await _showActionDialog(
        context,
        label: action['label'] as String? ?? 'Confirm',
        entityLabel: wqCase['entityLabel'] as String? ?? '',
        requiresReason: requiresReason,
      );
      if (result == null) return; // cancelled
      reason = result;
    }

    setState(() => _action[caseId] = const _CaseAction.working('Running…'));

    final method = (action['method'] as String? ?? 'POST').toUpperCase();
    final endpoint = '/operator/${action['endpoint'] as String? ?? ''}';

    try {
      if (method == 'POST') {
        // The server decides what an action means; the console posts what it
        // was handed. `body` carries fields already determined server-side —
        // which of five quarantine dispositions this button records, for
        // instance — and `reasonField` names where the operator's own account
        // of the decision belongs. Quarantine calls it `evidence`, because what
        // is recorded is what the operator determined rather than why they
        // pressed a button.
        //
        // Nothing here interprets a case type. A console that grew a switch on
        // caseType would become a second copy of the domain, and the two would
        // disagree the first time one of them changed.
        final serverBody = action['body'];
        final reasonField = action['reasonField'] as String? ?? 'reason';
        await _repo.rawPost(endpoint, body: {
          if (serverBody is Map) ...Map<String, dynamic>.from(serverBody),
          if (reason != null) reasonField: reason,
        });
      } else {
        await _repo.rawGet(endpoint);
      }
      if (!mounted) return;
      setState(() => _action[caseId] =
          _CaseAction.done(action['label'] as String? ?? 'Done'));
      // Reload after a short pause so verification data has time to land
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _action[caseId] = _CaseAction.error(e.toString()));
    }
  }

  Future<String?> _showActionDialog(
    BuildContext context, {
    required String label,
    required String entityLabel,
    required bool requiresReason,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.panelRaised,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Text(label,
            style: const TextStyle(fontSize: 15, color: AppTheme.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target: $entityLabel',
                style: const TextStyle(fontSize: 12, color: AppTheme.subdued)),
            if (requiresReason) ...[
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(fontSize: 13, color: AppTheme.text),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Reason (required)',
                  hintStyle: const TextStyle(color: AppTheme.subdued, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.panel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    borderSide: const BorderSide(color: AppTheme.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    borderSide:
                        BorderSide(color: AppTheme.accent.withOpacity(0.6)),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.subdued)),
          ),
          FilledButton(
            onPressed: () {
              if (requiresReason && controller.text.trim().isEmpty) return;
              Navigator.pop(ctx, controller.text.trim().isEmpty ? '' : controller.text.trim());
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
            child: Text(label,
                style: const TextStyle(color: AppTheme.background, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.caseCount,
    required this.criticalCount,
    required this.warningCount,
    required this.loading,
    this.generatedAt,
    this.onRefresh,
  });
  final int caseCount;
  final int criticalCount;
  final int warningCount;
  final bool loading;
  final String? generatedAt;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Work Queue',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  if (!loading && caseCount > 0)
                    Row(
                      children: [
                        if (criticalCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.rose.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$criticalCount critical',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.rose,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (warningCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$warningCount warning',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.amber,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Text(
                          '$caseCount case${caseCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.subdued),
                        ),
                      ],
                    )
                  else if (!loading)
                    Text(
                      'No open cases',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.muted),
                    ),
                ],
              ),
            ),
            if (onRefresh != null)
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.muted,
                  side: const BorderSide(color: AppTheme.line),
                ),
              ),
          ],
        ),
        if (generatedAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Generated ${_formatTs(generatedAt!)}',
            style: const TextStyle(fontSize: 10, color: AppTheme.subdued),
          ),
        ],
      ],
    );
  }

  static String _formatTs(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${_p(dt.hour)}:${_p(dt.minute)}:${_p(dt.second)}';
    } catch (_) {
      return iso;
    }
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}

// ── Case card ─────────────────────────────────────────────────────────────────

class _CaseCard extends StatefulWidget {
  const _CaseCard({
    required this.wqCase,
    required this.action,
    required this.onAction,
  });
  final Map<String, dynamic> wqCase;
  final _CaseAction? action;
  final void Function(Map<String, dynamic> action) onAction;

  @override
  State<_CaseCard> createState() => _CaseCardState();
}

class _CaseCardState extends State<_CaseCard> {
  bool _expanded = false;

  Color get _severityColor {
    switch (widget.wqCase['severity'] as String?) {
      case 'critical':
        return AppTheme.rose;
      case 'warning':
        return AppTheme.amber;
      default:
        return AppTheme.accent;
    }
  }

  String get _severityLabel {
    switch (widget.wqCase['severity'] as String?) {
      case 'critical':
        return 'CRITICAL';
      case 'warning':
        return 'WARNING';
      default:
        return 'INFO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.wqCase;
    final sc = _severityColor;
    final entityLabel = c['entityLabel'] as String? ?? c['entityId'] as String? ?? '—';
    final clientName = c['clientName'] as String?;
    final campaignName = c['campaignName'] as String?;
    final caseType = c['caseType'] as String? ?? '';
    final state = c['state'] as Map? ?? {};
    final stateLabel = state['label'] as String? ?? state['value'] as String? ?? '—';
    final actions = c['actions'] as List? ?? [];
    final isWorking = widget.action?.isWorking ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: _expanded ? sc.withOpacity(0.35) : AppTheme.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppTheme.radiusLarge),
              topRight: Radius.circular(AppTheme.radiusLarge),
              bottomLeft: _expanded ? Radius.zero : Radius.circular(AppTheme.radiusLarge),
              bottomRight: _expanded ? Radius.zero : Radius.circular(AppTheme.radiusLarge),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Severity stripe
                  Container(
                    width: 3,
                    height: 44,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: sc,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: sc.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                _severityLabel,
                                style: TextStyle(
                                    fontSize: 9,
                                    color: sc,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              caseType,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.subdued,
                                  fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entityLabel,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontSize: 14),
                        ),
                        if (clientName != null || campaignName != null)
                          Text(
                            [clientName, if (campaignName != null && campaignName != entityLabel) campaignName]
                                .whereType<String>()
                                .join(' · '),
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.subdued),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.panelRaised,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.line),
                        ),
                        child: Text(
                          stateLabel,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: AppTheme.subdued,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded body ─────────────────────────────────────────
          if (_expanded) ...[
            Divider(height: 1, color: AppTheme.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Evidence
                  _SectionLabel('Evidence'),
                  const SizedBox(height: 6),
                  _EvidenceTable(evidence: c['evidence'] as List? ?? []),
                  const SizedBox(height: 14),

                  // Diagnosis
                  _SectionLabel('Diagnosis'),
                  const SizedBox(height: 6),
                  Text(
                    c['diagnosis'] as String? ?? '—',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.muted, height: 1.5),
                  ),
                  const SizedBox(height: 14),

                  // Actions
                  if (actions.isNotEmpty) ...[
                    _SectionLabel('Actions'),
                    const SizedBox(height: 8),
                    if (isWorking)
                      Row(
                        children: [
                          const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.accent)),
                          const SizedBox(width: 8),
                          Text(widget.action!.message ?? 'Running…',
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.muted)),
                        ],
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: actions
                            .whereType<Map>()
                            .map((a) => _ActionButton(
                                  action: Map<String, dynamic>.from(a),
                                  onTap: () => widget.onAction(Map<String, dynamic>.from(a)),
                                ))
                            .toList(),
                      ),
                    if (widget.action != null && !isWorking) ...[
                      const SizedBox(height: 8),
                      _VerificationRow(action: widget.action!),
                    ],
                    const SizedBox(height: 14),
                  ],

                  // Verification source
                  _SectionLabel('Verification source'),
                  const SizedBox(height: 6),
                  _VerificationSourceRow(
                    source: c['verificationSource'] as Map? ?? {},
                  ),
                  const SizedBox(height: 14),

                  // Audit history
                  _SectionLabel('Local history'),
                  const SizedBox(height: 6),
                  _HistoryList(
                    rows: c['history'] as List? ?? [],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sub-components ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 9,
        color: AppTheme.subdued,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _EvidenceTable extends StatelessWidget {
  const _EvidenceTable({required this.evidence});
  final List evidence;

  Color _sevColor(String? sev) {
    switch (sev) {
      case 'critical':
        return AppTheme.rose;
      case 'warning':
        return AppTheme.amber;
      default:
        return AppTheme.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (evidence.isEmpty) {
      return const Text('—',
          style: TextStyle(fontSize: 12, color: AppTheme.subdued));
    }
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.panelRaised,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          for (int i = 0; i < evidence.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: AppTheme.line.withOpacity(0.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      (evidence[i] as Map)['label']?.toString() ?? '',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.subdued),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      (evidence[i] as Map)['value']?.toString() ?? '—',
                      style: TextStyle(
                        fontSize: 11,
                        color: _sevColor(
                            (evidence[i] as Map)['severity'] as String?),
                        fontWeight: (evidence[i] as Map)['severity'] != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.onTap});
  final Map<String, dynamic> action;
  final VoidCallback onTap;

  Color _outcomeColor(String? outcome) {
    switch (outcome) {
      case 'RESOLVE':
        return AppTheme.emerald;
      case 'INTERRUPT':
        return AppTheme.rose;
      case 'FORWARD':
        return AppTheme.accent;
      case 'DISMISS':
        return AppTheme.subdued;
      default:
        return AppTheme.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final outcome = action['outcome'] as String?;
    final color = _outcomeColor(outcome);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(action['label'] as String? ?? '—',
              style: const TextStyle(fontSize: 12)),
          if (outcome != null)
            Text(
              outcome,
              style: TextStyle(
                  fontSize: 8,
                  color: color.withOpacity(0.7),
                  letterSpacing: 0.4),
            ),
        ],
      ),
    );
  }
}

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({required this.action});
  final _CaseAction action;

  @override
  Widget build(BuildContext context) {
    final isDone = action.isDone;
    final color = isDone ? AppTheme.emerald : AppTheme.rose;
    final icon =
        isDone ? Icons.check_circle_outline : Icons.error_outline;
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(action.message ?? '',
              style: TextStyle(fontSize: 11, color: color)),
        ),
      ],
    );
  }
}

class _VerificationSourceRow extends StatelessWidget {
  const _VerificationSourceRow({required this.source});
  final Map source;

  @override
  Widget build(BuildContext context) {
    final endpoint = source['endpoint'] as String? ?? '—';
    final expectField = source['expectField'] as String? ?? '';
    final expectValue = source['expectValue'] as String?;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.panelRaised,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, size: 13, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'GET /operator/$endpoint — check $expectField${expectValue != null ? ' = $expectValue' : ''}',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.subdued, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.rows});
  final List rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('No audit history.',
          style: TextStyle(fontSize: 11, color: AppTheme.subdued));
    }
    return Column(
      children: rows
          .take(5)
          .whereType<Map>()
          .map((row) => _HistoryRow(row: Map<String, dynamic>.from(row)))
          .toList(),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final action = row['action'] as String? ?? '—';
    final actor = row['actorUserId'] as String?;
    final ts = row['createdAt'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 4, right: 8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.line,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.muted,
                        fontFamily: 'monospace')),
                if (actor != null || ts != null)
                  Text(
                    [
                      if (actor != null) actor.length > 12 ? '${actor.substring(0, 12)}…' : actor,
                      if (ts != null) _formatTs(ts),
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.subdued),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTs(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${_p(dt.month)}-${_p(dt.day)} ${_p(dt.hour)}:${_p(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 40, color: AppTheme.emerald),
          const SizedBox(height: 12),
          Text(
            'No open cases',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 6),
          Text(
            'All subsystems are within normal operating parameters.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.subdued, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_outlined,
                size: 40, color: AppTheme.amber),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.muted)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
              child: const Text('Retry',
                  style: TextStyle(color: AppTheme.background)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action state ──────────────────────────────────────────────────────────────

class _CaseAction {
  const _CaseAction.working(this.message) : _kind = _CAKind.working;
  const _CaseAction.done(this.message) : _kind = _CAKind.done;
  _CaseAction.error(this.message) : _kind = _CAKind.error;

  final _CAKind _kind;
  final String? message;

  bool get isWorking => _kind == _CAKind.working;
  bool get isDone => _kind == _CAKind.done;
  bool get isError => _kind == _CAKind.error;
}

enum _CAKind { working, done, error }
