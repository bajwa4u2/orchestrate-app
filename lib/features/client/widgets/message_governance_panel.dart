import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/system/widgets/governance_primitives.dart';

/// Workspace governance visibility surface.
///
/// Doctrine
/// --------
/// Backend provenance is now stamped on the wire and persisted into
/// OutreachMessage.metadataJson.governance for every governed
/// dispatch. The client must see what was sent on their behalf and
/// understand which governance properties applied — without a
/// black-box "AI sent something" feel.
///
/// UX rules
/// --------
///   - Primary language is operational: "Governed template used",
///     "AI body, no template provenance claimed", "Signature applied",
///     "Reply continuity thread".
///   - Advanced trace section is opt-in (expandable per row) and
///     surfaces raw identifiers (operation id, thread id, template
///     key, template version, lifecycle stage, attempt).
///   - Calm, audit-friendly. No flashy badges, no developer-dashboard
///     density, no growth-marketing tone.
///   - Empty + loading + error states are explicit.
class MessageGovernancePanel extends StatefulWidget {
  const MessageGovernancePanel({super.key, this.repository, this.limit});

  /// Optional override for tests / DI.
  final ClientPortalRepository? repository;

  /// Hard cap on how many rows to render. Backend already returns at
  /// most 25; this lets a host surface ask for fewer.
  final int? limit;

  @override
  State<MessageGovernancePanel> createState() => _MessageGovernancePanelState();
}

class _MessageGovernancePanelState extends State<MessageGovernancePanel> {
  late final ClientPortalRepository _repository =
      widget.repository ?? ClientPortalRepository();

  bool _loading = true;
  String? _error;
  List<dynamic> _messages = const [];

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
      final rows = await _repository.fetchRecentMessages();
      _messages = widget.limit == null ? rows : rows.take(widget.limit!).toList();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
              Icon(Icons.assignment_outlined,
                  size: 16, color: AppTheme.publicMuted),
              const SizedBox(width: 8),
              Text(
                'Message governance',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.publicMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Recent governed dispatches. Each row names which lane and lifecycle stage was applied, whether a governed template was used, and whether your signature was attached. Open a row for the full operation-scoped trace.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorRow(message: _error!, onRetry: _load)
          else if (_messages.isEmpty)
            _EmptyRow()
          else
            Column(
              children: [
                for (var i = 0; i < _messages.length; i++) ...[
                  _MessageRow(message: _asMap(_messages[i])),
                  if (i != _messages.length - 1) const Divider(height: 18),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatefulWidget {
  const _MessageRow({required this.message});

  final Map<String, dynamic> message;

  @override
  State<_MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<_MessageRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final subject = (m['subject'] ?? '').toString();
    final status = (m['status'] ?? '').toString();
    final sentAt = m['sentAt']?.toString();
    final governance = _asMap(m['governance']);
    final bodySource = (m['bodySource'] ?? '').toString();
    final signatureApplied = m['signatureApplied'] == true;

    final lane = (governance['lane'] ?? '').toString();
    final lifecycle = (governance['lifecycleStage'] ?? '').toString();
    final templateKey = (governance['templateKey'] ?? '').toString();
    final templateVersion = governance['templateVersion'];
    final operationId = (governance['operationId'] ?? '').toString();
    final threadId = (governance['threadId'] ?? '').toString();
    final attempt = governance['attempt']?.toString() ?? '';

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    subject.isNotEmpty ? subject : '(no subject)',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.publicText,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppTheme.publicMuted,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (lane.isNotEmpty)
                  GovernanceBadge(label: 'lane', value: lane),
                if (lifecycle.isNotEmpty)
                  GovernanceBadge(label: 'stage', value: lifecycle),
                BodySourcePill(
                  bodySource: bodySource.isEmpty ? null : bodySource,
                  templateKey: templateKey.isEmpty ? null : templateKey,
                ),
                BoundedAIIndicator(
                  bodySource: bodySource.isEmpty ? null : bodySource,
                ),
                if (signatureApplied)
                  const GovernanceBadge(
                    label: 'signature applied',
                    tone: GovernanceTone.positive,
                  ),
                if (status.isNotEmpty)
                  GovernanceBadge(label: 'status', value: status.toLowerCase()),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              ProvenanceChainStrip(
                operationId: operationId.isEmpty ? null : operationId,
                threadId: threadId.isEmpty ? null : threadId,
                templateKey: templateKey.isEmpty ? null : templateKey,
                templateVersion:
                    templateVersion is num ? templateVersion.toInt() : null,
              ),
              const SizedBox(height: 10),
              if (attempt.isNotEmpty)
                _traceField('Dispatch attempt', attempt),
              if (sentAt != null && sentAt.isNotEmpty)
                _traceField('Sent', sentAt),
              const SizedBox(height: 6),
              Text(
                _bodySourceExplanation(bodySource, templateKey),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.publicMuted,
                      height: 1.45,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.publicMuted,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _bodySourcePill(
    BuildContext context,
    String bodySource,
    String templateKey,
  ) {
    final label = _bodySourceLabel(bodySource);
    final usingTemplate = templateKey.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:
            usingTemplate ? AppTheme.publicAccentSoft : AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: usingTemplate
                  ? AppTheme.publicAccent
                  : AppTheme.publicMuted,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  String _bodySourceLabel(String bodySource) {
    switch (bodySource) {
      case 'catalog':
        return 'governed template';
      case 'ai_fallback_catalog':
        return 'governed fallback';
      case 'sequence_legacy':
        return 'legacy sequence body';
      case 'ai_draft':
        return 'AI body (no template claim)';
      default:
        return 'body source: ${bodySource.isEmpty ? "unknown" : bodySource}';
    }
  }

  String _bodySourceExplanation(String bodySource, String templateKey) {
    switch (bodySource) {
      case 'catalog':
        return 'Body rendered from the governed message-template catalog. Template provenance attached to the wire and persisted on the message row.';
      case 'ai_fallback_catalog':
        return 'AI generation did not succeed; the governed catalog fallback rendered the body. Template provenance is genuine.';
      case 'sequence_legacy':
        return 'Body came from a legacy SequenceStep.bodyTemplate string. No catalog template was claimed on the wire. Operation, thread, lane, lifecycle, and attempt provenance still attached.';
      case 'ai_draft':
        return 'AI produced the body in freeform. No template provenance is claimed on the wire — Orchestrate does not stamp template headers it cannot back. Operation, thread, lane, lifecycle, and attempt provenance still attached.';
      default:
        return 'Body source was not labeled on this row. The wire still carried operation, thread, lane, lifecycle, and attempt provenance.';
    }
  }

  Widget _traceField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                color: AppTheme.publicText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _EmptyRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'No governed dispatches recorded yet. Outbound messages will appear here once managed execution sends on your behalf.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.publicMuted,
            ),
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry('$k', v));
  return const <String, dynamic>{};
}
