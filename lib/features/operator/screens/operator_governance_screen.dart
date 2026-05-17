import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/operator_repository.dart';
import 'package:orchestrate_app/features/system/widgets/governance_primitives.dart';

/// Operator governance workspace.
///
/// Lists recent governed dispatches across the operator's
/// organization (optionally filtered to one client) and renders a
/// detail panel for the selected message with the full provenance
/// trace, template lineage, attribution chain, and dispatch-recovery
/// track.
///
/// Doctrine
/// --------
/// Every visualization on this screen consumes real metadata from
/// the persisted OutreachMessage row (via the /operator/governance/*
/// endpoints). Missing fields are surfaced as "not recorded" or
/// omitted — no fabricated events, no fake lineage.
class OperatorGovernanceScreen extends StatefulWidget {
  const OperatorGovernanceScreen({super.key, this.repository});

  final OperatorRepository? repository;

  @override
  State<OperatorGovernanceScreen> createState() =>
      _OperatorGovernanceScreenState();
}

class _OperatorGovernanceScreenState extends State<OperatorGovernanceScreen> {
  late final OperatorRepository _repository =
      widget.repository ?? OperatorRepository();

  bool _loadingList = true;
  String? _listError;
  List<Map<String, dynamic>> _messages = const [];
  String? _selectedId;
  Map<String, dynamic>? _selectedTrace;
  bool _loadingTrace = false;
  String? _traceError;

  List<Map<String, dynamic>> _reviewQueue = const [];
  bool _loadingReview = true;
  String? _reviewError;
  String? _retryingId;
  String? _retryNotice;

  Future<void> _retryMessage(String messageId) async {
    setState(() {
      _retryingId = messageId;
      _retryNotice = null;
    });
    try {
      final result = await _repository.retryGovernanceMessage(messageId);
      final attempt = result['attempt']?.toString() ?? '?';
      _retryNotice =
          'Message requeued. Attempt $attempt scheduled; provenance preserved.';
    } catch (error) {
      _retryNotice = 'Retry failed: $error';
    } finally {
      if (mounted) {
        setState(() => _retryingId = null);
      }
      await _loadReviewQueue();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadList();
    _loadReviewQueue();
  }

  Future<void> _loadReviewQueue() async {
    setState(() {
      _loadingReview = true;
      _reviewError = null;
    });
    try {
      final rows = await _repository.fetchGovernanceReviewQueue(limit: 30);
      _reviewQueue = rows
          .map((r) =>
              r is Map ? r.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{})
          .toList();
    } catch (error) {
      _reviewError = error.toString();
    } finally {
      if (mounted) setState(() => _loadingReview = false);
    }
  }

  Future<void> _loadList() async {
    setState(() {
      _loadingList = true;
      _listError = null;
    });
    try {
      final rows = await _repository.fetchGovernanceRecent(limit: 50);
      _messages = rows
          .map((r) => r is Map ? r.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{})
          .toList();
      if (_messages.isNotEmpty) {
        _selectMessage(_messages.first['id']?.toString() ?? '');
      }
    } catch (error) {
      _listError = error.toString();
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _selectMessage(String id) async {
    if (id.isEmpty) return;
    setState(() {
      _selectedId = id;
      _loadingTrace = true;
      _traceError = null;
      _selectedTrace = null;
    });
    try {
      final trace = await _repository.fetchGovernanceMessage(id);
      _selectedTrace = trace;
    } catch (error) {
      _traceError = error.toString();
    } finally {
      if (mounted) setState(() => _loadingTrace = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(coverage: _coverage()),
          const SizedBox(height: 18),
          _ReviewQueueCard(
            loading: _loadingReview,
            error: _reviewError,
            rows: _reviewQueue,
            onRetry: _loadReviewQueue,
            onSelect: (id) => _selectMessage(id),
            onRetryMessage: _retryMessage,
            retryingId: _retryingId,
            retryNotice: _retryNotice,
          ),
          const SizedBox(height: 18),
          if (_loadingList)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_listError != null)
            _Error(message: _listError!, onRetry: _loadList)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 1100;
                final list = _RecentList(
                  messages: _messages,
                  selectedId: _selectedId,
                  onSelect: _selectMessage,
                );
                final detail = _DetailPanel(
                  loading: _loadingTrace,
                  error: _traceError,
                  trace: _selectedTrace,
                );
                if (stacked) {
                  return Column(
                    children: [
                      list,
                      const SizedBox(height: 18),
                      detail,
                    ],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: list),
                      const SizedBox(width: 18),
                      Expanded(flex: 7, child: detail),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  ({int governed, int fallback, int legacy, int aiFreeform, int bounded}) _coverage() {
    int governed = 0,
        fallback = 0,
        legacy = 0,
        aiFreeform = 0,
        bounded = 0;
    for (final m in _messages) {
      switch (m['bodySource']?.toString()) {
        case 'catalog':
          governed++;
          break;
        case 'ai_fallback_catalog':
          fallback++;
          break;
        case 'sequence_legacy':
          legacy++;
          break;
        case 'ai_draft':
          aiFreeform++;
          break;
        case 'bounded_ai_catalog':
          bounded++;
          break;
      }
    }
    return (
      governed: governed,
      fallback: fallback,
      legacy: legacy,
      aiFreeform: aiFreeform,
      bounded: bounded,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.coverage});

  final ({int governed, int fallback, int legacy, int aiFreeform, int bounded}) coverage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Governance',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Recent governed dispatches across the organization. Every row reads from the same persisted provenance the wire carried.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 18),
          GovernanceCoverageMeter(
            // bounded folded into governed for the coverage view; both
            // are catalog-rendered with template provenance stamped.
            governedCount: coverage.governed + coverage.bounded,
            fallbackCount: coverage.fallback,
            legacyCount: coverage.legacy,
            aiFreeformCount: coverage.aiFreeform,
          ),
        ],
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({
    required this.messages,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> messages;
  final String? selectedId;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.publicLine),
        ),
        child: Text(
          'No governed dispatches recorded yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.publicMuted,
              ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                Icon(Icons.list_alt_outlined,
                    size: 16, color: AppTheme.publicMuted),
                const SizedBox(width: 8),
                Text(
                  'Recent dispatches',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.publicMuted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Text(
                  '${messages.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.publicMuted,
                      ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < messages.length; i++) ...[
            _ListRow(
              message: messages[i],
              selected: messages[i]['id']?.toString() == selectedId,
              onTap: () => onSelect(messages[i]['id']?.toString() ?? ''),
            ),
            if (i != messages.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.message,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> message;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subject = message['subject']?.toString() ?? '(no subject)';
    final sentAt = message['sentAt']?.toString();
    final clientId = message['clientId']?.toString();
    final bodySource = message['bodySource']?.toString();
    final governance = message['governance'];
    final lane = governance is Map ? governance['lane']?.toString() : null;
    final lifecycle =
        governance is Map ? governance['lifecycleStage']?.toString() : null;
    final templateKey =
        governance is Map ? governance['templateKey']?.toString() : null;

    return Material(
      color: selected ? AppTheme.publicSurfaceSoft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.publicText,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (clientId != null && clientId.isNotEmpty)
                    GovernanceBadge(
                        label: 'client',
                        value: clientId.length > 10
                            ? '${clientId.substring(0, 10)}…'
                            : clientId,
                        monospace: true),
                  if (lane != null && lane.isNotEmpty)
                    GovernanceBadge(label: 'lane', value: lane),
                  if (lifecycle != null && lifecycle.isNotEmpty)
                    GovernanceBadge(label: 'stage', value: lifecycle),
                  BodySourcePill(
                    bodySource: bodySource,
                    templateKey: templateKey,
                  ),
                ],
              ),
              if (sentAt != null && sentAt.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    sentAt,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppTheme.publicMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.loading,
    required this.error,
    required this.trace,
  });

  final bool loading;
  final String? error;
  final Map<String, dynamic>? trace;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: CircularProgressIndicator(),
              ),
            )
          : error != null
              ? Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                )
              : trace == null
                  ? Text(
                      'Select a dispatch to inspect.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.publicMuted,
                          ),
                    )
                  : _renderTrace(context, trace!),
    );
  }

  Widget _renderTrace(BuildContext context, Map<String, dynamic> t) {
    final subject = t['subject']?.toString() ?? '(no subject)';
    final body = t['body']?.toString() ?? '';
    final status = t['status']?.toString();
    final sentAt = t['sentAt']?.toString();
    final createdAt = t['createdAt']?.toString();
    final externalId = t['externalMessageId']?.toString();
    final threadKey = t['threadKey']?.toString();
    final bodySource = t['bodySource']?.toString();
    final signatureApplied = t['signatureApplied'] == true;
    final governance = (t['governance'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subject,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            BodySourcePill(
              bodySource: bodySource,
              templateKey: governance['templateKey']?.toString(),
            ),
            BoundedAIIndicator(bodySource: bodySource),
            if (signatureApplied)
              const GovernanceBadge(
                label: 'signature applied',
                tone: GovernanceTone.positive,
              ),
            if (status != null && status.isNotEmpty)
              GovernanceBadge(label: 'status', value: status.toLowerCase()),
            DispatchAttemptTrack(
                attempt: governance['attempt'] is num
                    ? (governance['attempt'] as num).toInt()
                    : null),
            RecoveryStatePill(state: status),
          ],
        ),
        const SizedBox(height: 18),
        _section(context, 'Provenance chain'),
        ProvenanceChainStrip(
          operationId: governance['operationId']?.toString(),
          threadId: governance['threadId']?.toString(),
          templateKey: governance['templateKey']?.toString(),
          templateVersion: governance['templateVersion'] is num
              ? (governance['templateVersion'] as num).toInt()
              : null,
        ),
        const SizedBox(height: 22),
        _section(context, 'Template lineage'),
        TemplateLineageMap(
          bodySource: bodySource,
          templateKey: governance['templateKey']?.toString(),
          templateVersion: governance['templateVersion'] is num
              ? (governance['templateVersion'] as num).toInt()
              : null,
        ),
        const SizedBox(height: 22),
        _section(context, 'Lifecycle'),
        LifecycleTimeline(
          steps: _lifecycleSteps(
            createdAt: createdAt,
            sentAt: sentAt,
            status: status,
            signatureApplied: signatureApplied,
            externalId: externalId,
            bodySource: bodySource,
          ),
        ),
        const SizedBox(height: 22),
        _section(context, 'Attribution chain'),
        AttributionChainView(
          operationId: governance['operationId']?.toString(),
          threadId: threadKey ?? governance['threadId']?.toString(),
          // The /operator/governance/messages/:id endpoint does not
          // yet return matched reply or follow-up-cancel events. We
          // surface that gap honestly through AttributionChainView's
          // 'pending' state.
          replyId: null,
          followUpCancelled: null,
        ),
        const SizedBox(height: 22),
        _section(context, 'Dispatch / recovery'),
        DispatchRecoveryTrack(
          attempt: governance['attempt'] is num
              ? (governance['attempt'] as num).toInt()
              : null,
          status: status,
          lastError: null,
        ),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 22),
          _section(context, 'Rendered body (operator view)'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.publicSurfaceSoft,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: SelectableText(
              body,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.45,
                color: AppTheme.publicText,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _section(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.publicMuted,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  List<LifecycleStep> _lifecycleSteps({
    required String? createdAt,
    required String? sentAt,
    required String? status,
    required bool signatureApplied,
    required String? externalId,
    required String? bodySource,
  }) {
    final normalized = (status ?? '').toUpperCase();
    final dispatched =
        normalized == 'SENT' || normalized == 'DELIVERED' || normalized == 'OPENED' ||
            normalized == 'CLICKED' || normalized == 'REPLIED';
    final failed = normalized == 'FAILED' || normalized == 'RETRYABLE_FAILED';

    return [
      LifecycleStep(
        label: 'Authored',
        state: createdAt != null ? 'done' : 'missing',
        timestamp: createdAt,
      ),
      LifecycleStep(
        label: 'Generated',
        state: bodySource != null ? 'done' : 'missing',
        detail: bodySource != null ? 'bodySource: $bodySource' : null,
      ),
      LifecycleStep(
        label: 'Governance validated',
        state: bodySource == 'catalog' ||
                bodySource == 'bounded_ai_catalog' ||
                bodySource == 'ai_fallback_catalog'
            ? 'done'
            : bodySource == 'sequence_legacy' || bodySource == 'ai_draft'
                ? 'attention'
                : 'missing',
        detail: bodySource == 'sequence_legacy'
            ? 'Legacy body — no template provenance claimed (honest)'
            : bodySource == 'ai_draft'
                ? 'Freeform AI body — no template provenance claimed (honest)'
                : null,
      ),
      LifecycleStep(
        label: signatureApplied ? 'Signature applied' : 'Signature',
        state: signatureApplied ? 'done' : 'pending',
        detail: signatureApplied
            ? 'Client signature appended at dispatch time'
            : 'No signature authored for the sending client',
      ),
      LifecycleStep(
        label: 'Dispatched',
        state: dispatched ? 'done' : failed ? 'failed' : 'pending',
        timestamp: sentAt,
        detail: externalId != null && externalId.isNotEmpty
            ? 'Provider message id: $externalId'
            : null,
      ),
      LifecycleStep(
        label: 'Provider acceptance',
        state: dispatched ? 'done' : failed ? 'failed' : 'pending',
        detail: failed
            ? 'Provider rejected the send (see Dispatch / recovery below).'
            : null,
      ),
    ];
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Operator review queue — recent FAILED / RETRYABLE_FAILED dispatches
/// surfaced as a list so an operator can decide whether to retry,
/// convert to legacy, or escalate. Tapping a row selects it in the
/// main detail panel above.
class _ReviewQueueCard extends StatelessWidget {
  const _ReviewQueueCard({
    required this.loading,
    required this.error,
    required this.rows,
    required this.onRetry,
    required this.onSelect,
    required this.onRetryMessage,
    required this.retryingId,
    required this.retryNotice,
  });

  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> rows;
  final VoidCallback onRetry;
  final void Function(String id) onSelect;
  final Future<void> Function(String id) onRetryMessage;
  final String? retryingId;
  final String? retryNotice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
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
              Icon(Icons.priority_high_outlined,
                  size: 16, color: AppTheme.publicMuted),
              const SizedBox(width: 8),
              Text(
                'Operator review queue',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.publicMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              if (!loading)
                GovernanceBadge(
                  label: 'open',
                  value: rows.length.toString(),
                  tone: rows.isEmpty
                      ? GovernanceTone.positive
                      : GovernanceTone.cautious,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dispatches the runtime could not complete. Each row carries the persisted error + governance metadata so retry, convert, or escalate decisions are made against truth — not guesswork.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            )
          else if (rows.isEmpty)
            Text(
              'No dispatches require review. Every recent outbound completed or is in flight.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  _ReviewRow(
                    row: rows[i],
                    onTap: () => onSelect(rows[i]['id']?.toString() ?? ''),
                    onRetry: () =>
                        onRetryMessage(rows[i]['id']?.toString() ?? ''),
                    retrying: retryingId == rows[i]['id']?.toString(),
                  ),
                  if (i != rows.length - 1) const Divider(height: 14),
                ],
              ],
            ),
          if (retryNotice != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.publicSurfaceSoft,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: AppTheme.publicLine),
              ),
              child: Text(
                retryNotice!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.publicMuted,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.row,
    required this.onTap,
    required this.onRetry,
    required this.retrying,
  });

  final Map<String, dynamic> row;
  final VoidCallback onTap;
  final VoidCallback onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final subject = row['subject']?.toString() ?? '(no subject)';
    final status = row['status']?.toString() ?? '';
    final error = row['errorMessage']?.toString();
    final clientId = row['clientId']?.toString();
    final governance = (row['governance'] as Map?)?.cast<String, dynamic>();
    final lane = governance?['lane']?.toString();
    final lifecycle = governance?['lifecycleStage']?.toString();
    final bodySource = row['bodySource']?.toString();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.publicText,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (clientId != null && clientId.isNotEmpty)
                  GovernanceBadge(
                    label: 'client',
                    value: clientId.length > 10
                        ? '${clientId.substring(0, 10)}…'
                        : clientId,
                    monospace: true,
                  ),
                if (status.isNotEmpty)
                  GovernanceBadge(
                    label: 'status',
                    value: status.toLowerCase(),
                    tone: GovernanceTone.critical,
                  ),
                if (lane != null && lane.isNotEmpty)
                  GovernanceBadge(label: 'lane', value: lane),
                if (lifecycle != null && lifecycle.isNotEmpty)
                  GovernanceBadge(label: 'stage', value: lifecycle),
                BodySourcePill(
                  bodySource: bodySource,
                  templateKey: governance?['templateKey']?.toString(),
                ),
              ],
            ),
            if (error != null && error.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                error,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontFamily: 'monospace',
                    ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: retrying ? null : onRetry,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text(retrying ? 'Retrying…' : 'Retry'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.publicText,
                    side: BorderSide(color: AppTheme.publicLine),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Provenance preserved on retry',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.publicMuted,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
