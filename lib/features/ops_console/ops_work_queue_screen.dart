import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'ops_console_repository.dart';
import 'ops_empty_state.dart';

/// WHAT NEEDS A PERSON, NOW.
///
/// Rebuilt around two things the old queue could not do at twenty-seven cases
/// and would have done worse at two hundred.
///
/// IT TOLD THE TRUTH ABOUT ITS OWN SIZE. It did not: every detector carried a
/// private ceiling, the queue sliced the result to a hundred, and the console
/// rendered that as the total. Thirty-nine held messages appeared as
/// twenty-five under a heading that read "27 cases". The count now describes
/// the work, the page says whether there is more, and the server names any
/// detector that reached its ceiling.
///
/// IT LET SOMEBODY LOOK AT ONE THING. It did not: every case rendered its whole
/// diagnosis, evidence table and action grid inline, so a queue of thirty was
/// several thousand pixels of decision surface nobody had asked for. The list
/// is now one line per case with one way in, and reviewing opens the case.
class OpsWorkQueueScreen extends StatefulWidget {
  const OpsWorkQueueScreen({super.key});

  @override
  State<OpsWorkQueueScreen> createState() => _OpsWorkQueueScreenState();
}

class _OpsWorkQueueScreenState extends State<OpsWorkQueueScreen> {
  final _repo = OpsConsoleRepository();

  static const _pageSize = 25;

  List<Map<String, dynamic>> _cases = [];
  List<Map<String, dynamic>> _workTypes = const [];
  List<Map<String, dynamic>> _businesses = const [];
  Map<String, dynamic> _bySeverity = const {};
  String? _generatedAt;
  List<String> _atCeiling = const [];

  int _total = 0;
  int _totalUnfiltered = 0;
  int _offset = 0;
  bool _hasMore = false;

  String? _workType;
  String? _clientId;
  String? _severity;

  /// Which case is open. Null is the list; anything else is the review state.
  String? _reviewing;

  bool _loading = true;
  String? _error;

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
      final data = await _repo.fetchWorkQueue(
        limit: _pageSize,
        offset: _offset,
        workType: _workType,
        clientId: _clientId,
        severity: _severity,
      );
      if (!mounted) return;
      final page = Map<String, dynamic>.from((data['page'] as Map?) ?? {});
      final totals = Map<String, dynamic>.from((data['totals'] as Map?) ?? {});
      setState(() {
        _cases = _mapList(data['cases']);
        _workTypes = _mapList(data['workTypes']);
        _businesses = _mapList(totals['byClient']);
        _bySeverity = Map<String, dynamic>.from((totals['bySeverity'] as Map?) ?? {});
        _generatedAt = data['generatedAt'] as String?;
        _total = (data['total'] as num?)?.toInt() ?? _cases.length;
        _totalUnfiltered = (data['totalUnfiltered'] as num?)?.toInt() ?? _total;
        _hasMore = page['hasMore'] == true;
        _atCeiling =
            ((data['atCeiling'] as List?) ?? const []).whereType<String>().toList();
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

  static List<Map<String, dynamic>> _mapList(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
      : const [];

  void _filter({String? workType, String? clientId, String? severity, bool clear = false}) {
    setState(() {
      if (clear) {
        _workType = null;
        _clientId = null;
        _severity = null;
      } else {
        if (workType != null) _workType = workType == _workType ? null : workType;
        if (clientId != null) _clientId = clientId == _clientId ? null : clientId;
        if (severity != null) _severity = severity == _severity ? null : severity;
      }
      // A filter changes what the pages are, so staying on page three of the
      // old result is meaningless.
      _offset = 0;
      _reviewing = null;
    });
    _load();
  }

  Map<String, dynamic>? get _openCase {
    if (_reviewing == null) return null;
    for (final c in _cases) {
      if (c['id'] == _reviewing) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final open = _openCase;
    if (open != null) {
      return _CaseDetail(
        wqCase: open,
        action: _action[open['id'] as String? ?? ''],
        onAction: (a) => _runAction(open['id'] as String? ?? '', open, a),
        onBack: () => setState(() => _reviewing = null),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          total: _total,
          totalUnfiltered: _totalUnfiltered,
          bySeverity: _bySeverity,
          generatedAt: _generatedAt,
          loading: _loading,
          atCeiling: _atCeiling,
          filtered: _workType != null || _clientId != null || _severity != null,
          onClear: () => _filter(clear: true),
          onRefresh: _loading ? null : _load,
        ),
        const SizedBox(height: 14),
        _Filters(
          workTypes: _workTypes,
          businesses: _businesses,
          bySeverity: _bySeverity,
          workType: _workType,
          clientId: _clientId,
          severity: _severity,
          onWorkType: (v) => _filter(workType: v),
          onClient: (v) => _filter(clientId: v),
          onSeverity: (v) => _filter(severity: v),
        ),
        const SizedBox(height: 14),
        Expanded(child: _body()),
        if (!_loading && _error == null && (_hasMore || _offset > 0)) ...[
          const SizedBox(height: 10),
          _Pager(
            offset: _offset,
            shown: _cases.length,
            total: _total,
            hasMore: _hasMore,
            onPrevious: _offset == 0
                ? null
                : () {
                    setState(() => _offset = (_offset - _pageSize).clamp(0, 1 << 30));
                    _load();
                  },
            onNext: !_hasMore
                ? null
                : () {
                    setState(() => _offset = _offset + _pageSize);
                    _load();
                  },
          ),
        ],
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_error != null) {
      return _ErrorPanel(message: _error!, onRetry: _load);
    }
    if (_cases.isEmpty) {
      final filtered = _workType != null || _clientId != null || _severity != null;
      if (filtered) {
        return OpsEmptyState(
          headline: 'Nothing matches this filter.',
          detail: _totalUnfiltered > 0
              ? 'There ${_totalUnfiltered == 1 ? 'is' : 'are'} $_totalUnfiltered case'
                  '${_totalUnfiltered == 1 ? '' : 's'} in total. Clear the filter to see them.'
              : 'Nothing is waiting for a decision.',
        );
      }
      return const OpsEmptyState(
        icon: Icons.check_circle_outline,
        headline: 'Nothing is waiting for a decision.',
        detail: 'Held messages and authority submissions are checked across every '
            'business. Everything else is checked in the organisation you are '
            'signed in as.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _cases.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = _cases[i];
        final id = c['id'] as String? ?? '$i';
        return _QueueRow(
          wqCase: c,
          onReview: () => setState(() => _reviewing = id),
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
        records: action['records'] as String?,
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
        // which of five quarantine dispositions this button records, or which
        // capabilities an admission establishes — and `reasonField` names where
        // the operator's own account of the decision belongs.
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
      // Reload after a short pause so verification data has time to land, and
      // return to the list: the case that was being reviewed has been decided.
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _reviewing = null);
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _action[caseId] = _CaseAction.error(_readable(e)));
    }
  }

  String _readable(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.length > 200 ? '${text.substring(0, 200)}…' : text;
  }

  Future<String?> _showActionDialog(
    BuildContext context, {
    required String label,
    required String entityLabel,
    required bool requiresReason,
    String? records,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: Text(label, style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entityLabel,
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
            if (records != null) ...[
              const SizedBox(height: 10),
              // What pressing this writes, repeated at the moment of pressing
              // it. A confirmation that only says "are you sure" asks somebody
              // to be sure about something it declined to restate.
              Text(
                records,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.subdued, height: 1.4),
              ),
            ],
            if (requiresReason) ...[
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'What did you determine?',
                  helperText: 'Recorded with the decision. It is not the decision.',
                  helperStyle: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              requiresReason ? controller.text.trim() : '',
            ),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
            child: Text(label, style: const TextStyle(color: AppTheme.background)),
          ),
        ],
      ),
    );
  }
}

// ── The list ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.totalUnfiltered,
    required this.bySeverity,
    required this.generatedAt,
    required this.loading,
    required this.atCeiling,
    required this.filtered,
    required this.onClear,
    required this.onRefresh,
  });

  final int total;
  final int totalUnfiltered;
  final Map<String, dynamic> bySeverity;
  final String? generatedAt;
  final bool loading;
  final List<String> atCeiling;
  final bool filtered;
  final VoidCallback onClear;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final critical = (bySeverity['critical'] as num?)?.toInt() ?? 0;
    final warning = (bySeverity['warning'] as num?)?.toInt() ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Work queue', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (critical > 0) ...[
                    _Pill(text: '$critical critical', color: AppTheme.rose),
                    const SizedBox(width: 8),
                  ],
                  if (warning > 0) ...[
                    _Pill(text: '$warning warning', color: AppTheme.amber),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    filtered
                        ? '$total of $totalUnfiltered case'
                            '${totalUnfiltered == 1 ? '' : 's'}'
                        : '$total case${total == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.muted),
                  ),
                  if (filtered) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: onClear,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppTheme.accent,
                      ),
                      child: const Text('Show everything', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
              if (generatedAt != null) ...[
                const SizedBox(height: 3),
                Text(
                  'Generated ${_clock(generatedAt!)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.subdued),
                ),
              ],
              // A count that is a floor rather than a total says so. Silence
              // here is what made "27 cases" above twenty-five rows possible.
              if (atCeiling.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'More than we read: ${atCeiling.join(', ')}. The counts above are '
                  'at least this many.',
                  style: const TextStyle(fontSize: 11, color: AppTheme.amber),
                ),
              ],
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: loading
              ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.muted),
                )
              : const Icon(Icons.refresh, size: 15),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.muted,
            side: const BorderSide(color: AppTheme.line),
          ),
        ),
      ],
    );
  }

  static String _clock(String iso) {
    final at = DateTime.tryParse(iso);
    if (at == null) return iso;
    final local = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}

/// WHOSE WORK, AND WHAT KIND.
///
/// The two questions an operator actually switches between: everything owed to
/// one business, and every decision of one kind across all of them. A row of
/// permanent tabs per business would be unreadable at twenty clients, so the
/// businesses are a menu that names how much each owes.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.workTypes,
    required this.businesses,
    required this.bySeverity,
    required this.workType,
    required this.clientId,
    required this.severity,
    required this.onWorkType,
    required this.onClient,
    required this.onSeverity,
  });

  final List<Map<String, dynamic>> workTypes;
  final List<Map<String, dynamic>> businesses;
  final Map<String, dynamic> bySeverity;
  final String? workType;
  final String? clientId;
  final String? severity;
  final void Function(String) onWorkType;
  final void Function(String) onClient;
  final void Function(String) onSeverity;

  @override
  Widget build(BuildContext context) {
    final withWork = workTypes.where((t) => ((t['count'] as num?)?.toInt() ?? 0) > 0).toList();
    final selectedBusiness = businesses.firstWhere(
      (b) => b['clientId'] == clientId,
      orElse: () => const {},
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Only the kinds of work that exist. An empty tab is a promise of
        // somewhere to go that goes nowhere.
        for (final type in withWork)
          _FilterChip(
            label: '${type['label']}',
            count: (type['count'] as num?)?.toInt() ?? 0,
            selected: workType == type['key'],
            tooltip: type['describes'] as String?,
            onTap: () => onWorkType('${type['key']}'),
          ),
        if (withWork.isNotEmpty && businesses.length > 1)
          const SizedBox(width: 4, height: 24),
        if (businesses.length > 1)
          PopupMenuButton<String>(
            tooltip: 'Show one business',
            onSelected: onClient,
            color: AppTheme.panel,
            itemBuilder: (context) => [
              for (final b in businesses)
                PopupMenuItem<String>(
                  value: '${b['clientId'] ?? ''}',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${b['clientName'] ?? 'Not attached to a business'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      Text('${b['count']}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.subdued)),
                    ],
                  ),
                ),
            ],
            child: _ChipShell(
              selected: clientId != null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    clientId == null
                        ? 'All businesses'
                        : '${selectedBusiness['clientName'] ?? 'One business'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: clientId != null ? AppTheme.accent : AppTheme.muted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more,
                      size: 14,
                      color: clientId != null ? AppTheme.accent : AppTheme.muted),
                ],
              ),
            ),
          ),
        for (final level in const ['critical', 'warning'])
          if (((bySeverity[level] as num?)?.toInt() ?? 0) > 0)
            _FilterChip(
              label: level == 'critical' ? 'Critical' : 'Warning',
              count: (bySeverity[level] as num?)?.toInt() ?? 0,
              selected: severity == level,
              color: level == 'critical' ? AppTheme.rose : AppTheme.amber,
              onTap: () => onSeverity(level),
            ),
      ],
    );
  }
}

class _ChipShell extends StatelessWidget {
  const _ChipShell({required this.child, required this.selected, this.color});
  final Widget child;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? tint.withOpacity(0.12) : AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: selected ? tint.withOpacity(0.5) : AppTheme.line),
      ),
      child: child,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.tooltip,
    this.color,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppTheme.accent;
    final chip = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: _ChipShell(
        selected: selected,
        color: color,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: selected ? tint : AppTheme.muted)),
            const SizedBox(width: 6),
            Text('$count',
                style: TextStyle(
                    fontSize: 11,
                    color: selected ? tint.withOpacity(0.8) : AppTheme.subdued)),
          ],
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );
}

/// ONE LINE PER CASE, ONE WAY IN.
///
/// Whose it is, what kind of work, what needs deciding, how long it has waited,
/// how urgent, and Review. The old row rendered the entire diagnosis, evidence
/// table and action grid inline, which made a queue of thirty into several
/// thousand pixels of decision surface nobody had asked to see yet.
class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.wqCase, required this.onReview});

  final Map<String, dynamic> wqCase;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final severity = wqCase['severity'] as String? ?? 'info';
    final colour = severity == 'critical'
        ? AppTheme.rose
        : severity == 'warning'
            ? AppTheme.amber
            : AppTheme.accent;
    final state = wqCase['state'] as Map? ?? {};
    final since = DateTime.tryParse('${state['since'] ?? ''}');
    final waited = since == null ? null : _howLong(DateTime.now().difference(since));
    final client = (wqCase['clientName'] as String?)?.trim();

    return InkWell(
      onTap: onReview,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 3,
              height: 34,
              margin: const EdgeInsets.only(right: 12),
              decoration:
                  BoxDecoration(color: colour, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${wqCase['entityLabel'] ?? wqCase['entityId'] ?? '—'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, height: 1.2),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    // Urgency in words as well as colour. A three-pixel stripe
                    // is the whole difference between "somebody is waiting" and
                    // "this has been waiting four days", and a header saying
                    // "1 critical" above rows that all look alike does not tell
                    // an operator which one.
                    [
                      if (severity != 'info') _urgency(severity),
                      if (client != null && client.isNotEmpty) client,
                      '${(state['label'] ?? state['value'] ?? '—')}',
                      if (waited != null) waited,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.subdued),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: onReview,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Review', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.offset,
    required this.shown,
    required this.total,
    required this.hasMore,
    required this.onPrevious,
    required this.onNext,
  });

  final int offset;
  final int shown;
  final int total;
  final bool hasMore;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final first = total == 0 ? 0 : offset + 1;
    final last = offset + shown;
    return Row(
      children: [
        Text(
          '$first–$last of $total',
          style: const TextStyle(fontSize: 12, color: AppTheme.subdued),
        ),
        const Spacer(),
        TextButton(
          onPressed: onPrevious,
          style: TextButton.styleFrom(foregroundColor: AppTheme.muted),
          child: const Text('Previous', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: onNext,
          style: TextButton.styleFrom(foregroundColor: AppTheme.muted),
          child: const Text('Next', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

// ── The review state ─────────────────────────────────────────────────────────

/// ONE CASE, WITH EVERYTHING NEEDED TO DECIDE IT.
///
/// Its own state rather than an expander in the list. Deciding whether a
/// business authorised somebody, or where a held message belongs, is not
/// something to do while scrolling past twenty other things.
class _CaseDetail extends StatelessWidget {
  const _CaseDetail({
    required this.wqCase,
    required this.action,
    required this.onAction,
    required this.onBack,
  });

  final Map<String, dynamic> wqCase;
  final _CaseAction? action;
  final void Function(Map<String, dynamic>) onAction;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = wqCase;
    final severity = c['severity'] as String? ?? 'info';
    final colour = severity == 'critical'
        ? AppTheme.rose
        : severity == 'warning'
            ? AppTheme.amber
            : AppTheme.accent;
    final state = c['state'] as Map? ?? {};
    final actions = (c['actions'] as List? ?? [])
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .toList();
    final isWorking = action?.isWorking ?? false;
    final client = (c['clientName'] as String?)?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // THE WAY OUT NEEDS A REAL TARGET.
        //
        // At shrinkWrap with four pixels of padding this was about eighteen
        // pixels tall, and a click aimed at the middle of the text landed
        // outside it. The only way back from a case is not the place to save
        // vertical space.
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 15),
          label: const Text('Back to the queue', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.muted,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${c['entityLabel'] ?? '—'}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 5),
        Text(
          [
            if (client != null && client.isNotEmpty) client,
            '${state['label'] ?? state['value'] ?? '—'}',
          ].join(' · '),
          style: const TextStyle(fontSize: 13, color: AppTheme.muted),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _SectionLabel('Why this exists'),
              const SizedBox(height: 6),
              Text(
                c['diagnosis'] as String? ?? '—',
                style: const TextStyle(fontSize: 13, color: AppTheme.muted, height: 1.55),
              ),
              const SizedBox(height: 18),
              _SectionLabel('Evidence'),
              const SizedBox(height: 6),
              _EvidenceTable(evidence: c['evidence'] as List? ?? []),
              const SizedBox(height: 18),
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
                      Text(action!.message ?? 'Running…',
                          style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                    ],
                  )
                else
                  _ActionSet(actions: actions, onAction: onAction),
                if (action != null && !isWorking) ...[
                  const SizedBox(height: 10),
                  _VerificationRow(action: action!),
                ],
                const SizedBox(height: 18),
              ],
              _SectionLabel('How you will know'),
              const SizedBox(height: 6),
              _VerificationSourceRow(source: c['verificationSource'] as Map? ?? {}),
              const SizedBox(height: 18),
              _SectionLabel('What has been done'),
              const SizedBox(height: 6),
              _HistoryList(rows: c['history'] as List? ?? []),
              const SizedBox(height: 18),
              // TECHNICAL IDENTITY, LAST AND QUIET.
              //
              // A case type and a row id are how an engineer finds this again;
              // they are not what a person needs to decide it, and leading with
              // them is how an operator surface starts reading like a log.
              _Fingerprint(
                caseType: c['caseType'] as String? ?? '',
                entityType: c['entityType'] as String? ?? '',
                entityId: c['entityId'] as String? ?? '',
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Container(height: 2, color: colour.withOpacity(0.0)),
      ],
    );
  }
}

class _Fingerprint extends StatelessWidget {
  const _Fingerprint({
    required this.caseType,
    required this.entityType,
    required this.entityId,
  });

  final String caseType;
  final String entityType;
  final String entityId;

  @override
  Widget build(BuildContext context) {
    if (entityId.isEmpty && caseType.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: const Text(
          'Details',
          style: TextStyle(fontSize: 11, color: AppTheme.subdued, letterSpacing: 0.4),
        ),
        iconColor: AppTheme.subdued,
        collapsedIconColor: AppTheme.subdued,
        children: [
          for (final line in [
            if (caseType.isNotEmpty) caseType,
            if (entityType.isNotEmpty || entityId.isNotEmpty)
              [entityType, entityId].where((s) => s.isNotEmpty).join(' '),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                line,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.subdued, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Sub-components ───────────────────────────────────────────────────────────

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
    final records = action['records'] as String?;
    final color = _outcomeColor(outcome);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        // A two-line consequence needs room under it; at vertical 8 the last
        // line sat on the border.
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        minimumSize: Size.zero,
        alignment: Alignment.centerLeft,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(action['label'] as String? ?? '—',
              style: const TextStyle(fontSize: 12)),
          // What pressing this writes, in the server's words. An operator
          // choosing between five dispositions is deciding what is true about
          // a message, and each answer leaves a different permanent record.
          // A row of buttons that says only what it is called asks someone to
          // guess at the consequence of the one they press.
          if (records != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                records,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.subdued, height: 1.3),
              ),
            )
          else if (outcome != null)
            Text(
              outcome,
              style: TextStyle(
                  fontSize: 8,
                  color: color.withOpacity(0.7),
                  letterSpacing: 0.4),
            ),
        ],
        ),
      ),
    );
  }
}

/// AN INSPECTION IS NOT A DISPOSITION, AND MUST NOT LOOK LIKE ONE.
///
/// Opening a held message and deciding where it belongs are different acts with
/// different consequences: one is a read, the other writes a permanent record
/// against a client's business. Laid out in a single wrap they read as six
/// equivalent buttons, and the first row comes out ragged because the odd one
/// is narrower than the rest. The inspection sits on its own line above, in a
/// quieter treatment; the decisions form an even grid beneath it.
class _ActionSet extends StatelessWidget {
  const _ActionSet({required this.actions, required this.onAction});

  final List<Map<String, dynamic>> actions;
  final void Function(Map<String, dynamic>) onAction;

  @override
  Widget build(BuildContext context) {
    final inspect =
        actions.where((a) => a['outcome'] == 'INSPECT').toList();
    final decisions =
        actions.where((a) => a['outcome'] != 'INSPECT').toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        // Two up where each column still holds a sentence; one up below that,
        // rather than two columns of four-word wraps.
        final twoUp = constraints.maxWidth >= 620;
        final width =
            twoUp ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final a in inspect) ...[
              _InspectButton(action: a, onTap: () => onAction(a)),
              const SizedBox(height: 10),
            ],
            if (decisions.isNotEmpty)
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final a in decisions)
                    SizedBox(
                      width: width,
                      child: _ActionButton(
                        action: a,
                        onTap: () => onAction(a),
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _InspectButton extends StatelessWidget {
  const _InspectButton({required this.action, required this.onTap});

  final Map<String, dynamic> action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.visibility_outlined, size: 14),
      label: Text(action['label'] as String? ?? 'Open',
          style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.muted,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    // What a person will SEE if this worked. An operator deciding where a
    // client's held message belongs should not have to read an HTTP method to
    // find out whether the decision took; the endpoint is the right answer on
    // an engineering surface and the wrong one here.
    final confirm = (source['confirm'] as String?)?.trim();
    final endpoint = source['endpoint'] as String?;
    final expectField = source['expectField'] as String? ?? '';
    final expectValue = source['expectValue'] as String?;

    // Older cases predate the sentence. Rather than print nothing, fall back to
    // the exact check — unhelpful phrasing beats an empty promise of proof.
    final text = (confirm != null && confirm.isNotEmpty)
        ? confirm
        : (endpoint == null
            ? 'No stated way to confirm this.'
            : 'Check $endpoint for '
                '$expectField${expectValue != null ? ' = $expectValue' : ''}.');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.panelRaised,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child:
                Icon(Icons.verified_outlined, size: 13, color: AppTheme.accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.subdued, height: 1.4),
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
      return const Text('Nothing has been decided about this yet.',
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

// ── Error state ──────────────────────────────────────────────────────────────

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

/// Urgency in a word. Colour alone cannot be read aloud, cannot be searched,
/// and is invisible to anyone who does not see it.
String _urgency(String severity) =>
    severity == 'critical' ? 'Critical' : 'Needs attention';

/// Age in words an operator reads at a glance.
String _howLong(Duration d) {
  if (d.inMinutes < 60) return 'just now';
  if (d.inHours < 24) return '${d.inHours}h waiting';
  return '${d.inDays}d waiting';
}
