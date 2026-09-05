import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/ui/governed_action.dart';
import 'package:orchestrate_app/data/repositories/client/client_engagement_repository.dart';

/// THE UNDERTAKINGS INSIDE ONE RELATIONSHIP.
///
/// Contained, never a competing domain. There is no route here and no
/// top-level list, because the moment undertakings get a list of their own the
/// durable account identity moves from the relationship to the deal and this
/// becomes the pipeline board the product exists not to be.
///
/// Absence is not a void. Most relationships in production hold no undertaking
/// at all — contact, correspondence and continuity exist there without anybody
/// having taken on a bounded piece of work, and the panel says so in the
/// server's words rather than showing an empty list that reads as a gap.
///
/// Every sentence here about what something means, or why an act was refused,
/// came from the authority that decided it. This file writes none of them.
class EngagementPanel extends StatefulWidget {
  const EngagementPanel({
    super.key,
    required this.relationshipId,
    this.repository,
    this.onChanged,
  });

  final String relationshipId;

  /// Injected in tests so the real orchestration is exercised.
  final ClientEngagementRepository? repository;

  /// The same seam, for tests that mount a whole screen above this and so
  /// cannot reach the constructor. Without it, a relationship test would have
  /// to assert against a failed network read, which proves nothing about
  /// containment and everything about the harness.
  @visibleForTesting
  static ClientEngagementRepository? testRepository;

  /// Called after anything that changes what is true, so the relationship
  /// around this can re-read its own condition from the server rather than
  /// this panel guessing what the change did to it.
  final VoidCallback? onChanged;

  @override
  State<EngagementPanel> createState() => _EngagementPanelState();
}

class _EngagementPanelState extends State<EngagementPanel> {
  late final ClientEngagementRepository _repository = widget.repository ??
      EngagementPanel.testRepository ??
      ClientEngagementRepository();

  RelationshipEngagements? _engagements;
  Refusal? _loadFailure;
  bool _loading = true;

  /// Which undertaking is expanded, and what the server said about it. Only
  /// ever presentation state — lifecycle and containment are server truth.
  String? _expandedId;
  EngagementDetail? _detail;
  bool _loadingDetail = false;

  bool _showConcluded = false;
  bool _opening = false;
  String? _busyId;
  Refusal? _commandFailure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EngagementPanel old) {
    super.didUpdateWidget(old);
    if (old.relationshipId != widget.relationshipId) {
      _expandedId = null;
      _detail = null;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailure = null;
    });
    try {
      final result = await _repository.forRelationship(widget.relationshipId);
      if (!mounted) return;
      setState(() {
        _engagements = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadFailure = Refusal.unexpected(error);
        _loading = false;
      });
    }
  }

  Future<void> _expand(String id) async {
    if (_expandedId == id) {
      setState(() {
        _expandedId = null;
        _detail = null;
      });
      return;
    }
    setState(() {
      _expandedId = id;
      _detail = null;
      _loadingDetail = true;
    });
    try {
      final detail = await _repository.detail(id);
      if (!mounted || _expandedId != id) return;
      setState(() {
        _detail = detail;
        _loadingDetail = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
    }
  }

  /// Run a command, then re-read. Never patch local state from what was sent.
  ///
  /// The server is the only thing that knows what an act did — a completion
  /// can be refused as stale by somebody else's earlier command, and a surface
  /// that optimistically marked it complete would show two people two
  /// different truths about the same undertaking.
  Future<void> _command(
    String id,
    Future<EngagementCommandResult> Function() run,
  ) async {
    setState(() {
      _busyId = id;
      _commandFailure = null;
    });
    try {
      final result = await run();
      if (!mounted) return;
      if (!result.ok) {
        setState(() {
          _busyId = null;
          _commandFailure = Refusal(
            reason: result.reason ?? 'This was refused, and no reason was given.',
            code: result.code,
          );
        });
        return;
      }
      await _load();
      if (_expandedId != null) await _expand(_expandedId!);
      widget.onChanged?.call();
      if (mounted) setState(() => _busyId = null);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyId = null;
        _commandFailure = Refusal.unexpected(error);
      });
    }
  }

  Future<void> _openUndertaking() async {
    final asked = await showDialog<_OpenIntent>(
      context: context,
      builder: (_) => _OpenUndertakingDialog(
        counterparty: _engagements?.counterparty,
      ),
    );
    if (asked == null || !mounted) return;

    setState(() {
      _opening = true;
      _commandFailure = null;
    });
    try {
      final result = await _repository.open(
        relationshipId: widget.relationshipId,
        purpose: asked.purpose,
        originNote: asked.originNote,
        // Identity of THIS admission, so a double submit or a retry is the
        // same undertaking rather than a second one with the same purpose.
        admissionKey: asked.admissionKey,
      );
      if (!mounted) return;
      if (!result.ok) {
        setState(() {
          _opening = false;
          _commandFailure = Refusal(
            reason: result.reason ?? 'This was refused, and no reason was given.',
            code: result.code,
          );
        });
        return;
      }
      await _load();
      widget.onChanged?.call();
      if (!mounted) return;
      setState(() => _opening = false);
      // Said only when it is true. A retried admission returns what already
      // existed, and calling that "opened" teaches people the button is broken.
      final note = result.created
          ? null
          : (result.note ?? 'This undertaking was already recorded.');
      if (note != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note)));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _commandFailure = Refusal.unexpected(error);
      });
    }
  }

  Future<void> _abandon(EngagementView engagement) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _AbandonDialog(purpose: engagement.purpose),
    );
    if (reason == null || !mounted) return;
    await _command(
      engagement.id,
      () => _repository.abandon(engagementId: engagement.id, reason: reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const WorkspaceBand(
        title: 'UNDERTAKINGS',
        children: [QuietState(message: 'Reading undertakings')],
      );
    }

    if (_loadFailure != null) {
      return WorkspaceBand(
        title: 'UNDERTAKINGS',
        children: [
          RefusalNotice(refusal: _loadFailure!, onRetry: _load),
        ],
      );
    }

    final engagements = _engagements;
    if (engagements == null) return const SizedBox.shrink();

    final open = engagements.open;
    final concluded = engagements.concluded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspaceBand(
          title: 'UNDERTAKINGS',
          // The server's sentence, including for the zero state. A relationship
          // holding none is a legitimate condition, not an empty list to fill.
          subtitle: engagements.says,
          trailing: GovernedAction(
            label: 'Open an undertaking',
            // Internal business organisation. Nothing leaves the building and
            // nobody is bound, so this is deliberately a quiet button — the
            // acts inside the undertaking are the ones that carry weight.
            consequence: Consequence.reversibleInternal,
            busy: _opening,
            onPressed: _opening ? null : _openUndertaking,
          ),
          children: [
            if (open.isEmpty && concluded.isEmpty)
              const QuietState(
                message: 'Nothing has been taken on here',
                hint: 'Contact, correspondence and commercial context all exist '
                    'without a bounded undertaking. This is not a gap.',
              ),
            for (final engagement in open)
              _EngagementRow(
                engagement: engagement,
                expanded: _expandedId == engagement.id,
                detail: _expandedId == engagement.id ? _detail : null,
                loadingDetail: _expandedId == engagement.id && _loadingDetail,
                busy: _busyId == engagement.id,
                onTap: () => _expand(engagement.id),
                onComplete: () => _command(
                    engagement.id, () => _repository.complete(engagement.id)),
                onAbandon: () => _abandon(engagement),
              ),
          ],
        ),
        if (_commandFailure != null)
          RefusalNotice(refusal: _commandFailure!),
        if (concluded.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _showConcluded = !_showConcluded),
            icon: Icon(_showConcluded ? Icons.expand_less : Icons.expand_more,
                size: 18),
            label: Text(_showConcluded
                ? 'Hide undertakings that have ended'
                : concluded.length == 1
                    ? 'Show 1 undertaking that has ended'
                    : 'Show ${concluded.length} undertakings that have ended'),
          ),
          if (_showConcluded)
            WorkspaceBand(
              title: 'ENDED',
              // Said plainly, because the alternative reading — that a
              // relationship is over because a piece of work is — is the
              // mistake this whole containment exists to prevent.
              subtitle: 'A relationship does not end because an undertaking does.',
              children: [
                for (final engagement in concluded)
                  _EngagementRow(
                    engagement: engagement,
                    expanded: _expandedId == engagement.id,
                    detail: _expandedId == engagement.id ? _detail : null,
                    loadingDetail: _expandedId == engagement.id && _loadingDetail,
                    busy: false,
                    onTap: () => _expand(engagement.id),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

class _EngagementRow extends StatelessWidget {
  const _EngagementRow({
    required this.engagement,
    required this.expanded,
    required this.detail,
    required this.loadingDetail,
    required this.busy,
    required this.onTap,
    this.onComplete,
    this.onAbandon,
  });

  final EngagementView engagement;
  final bool expanded;
  final EngagementDetail? detail;
  final bool loadingDetail;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onAbandon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspaceRow(
          title: engagement.purpose,
          // The server's sentence for the state. Never a word of this file's
          // own: "completed" is not "won", and there is no WON here to reach for.
          detail: engagement.blocker ?? engagement.stateMeans,
          meta: _meta(engagement),
          // A blocker earns attention. An undertaking that is merely open does
          // not — healthy work is quiet, and a list that lights up because
          // something exists is a list people learn to ignore.
          tone: engagement.needsAHuman
              ? RowTone.attention
              : engagement.state == EngagementState.open
                  ? RowTone.good
                  : RowTone.neutral,
          onTap: onTap,
          action: Icon(expanded ? Icons.expand_less : Icons.expand_more,
              size: 18, color: AppTheme.publicMuted),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4, bottom: 12),
            child: loadingDetail
                ? const QuietState(message: 'Reading this undertaking')
                : detail == null
                    ? const QuietState(message: 'This undertaking is no longer here')
                    : _Detail(
                        detail: detail!,
                        busy: busy,
                        onComplete: onComplete,
                        onAbandon: onAbandon,
                      ),
          ),
      ],
    );
  }

  static String _meta(EngagementView engagement) {
    final when = switch (engagement.state) {
      EngagementState.completed => engagement.completedAt,
      EngagementState.abandoned => engagement.abandonedAt,
      EngagementState.open => engagement.openedAt,
    };
    final verb = switch (engagement.state) {
      EngagementState.completed => 'ended',
      EngagementState.abandoned => 'stopped',
      EngagementState.open => 'opened',
    };
    if (when == null) return verb;
    return '$verb ${_when(when)}';
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.detail,
    required this.busy,
    required this.onComplete,
    required this.onAbandon,
  });

  final EngagementDetail detail;
  final bool busy;
  final VoidCallback? onComplete;
  final VoidCallback? onAbandon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final view = detail.view;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HOW THIS BECAME KNOWN. Never a created-at date standing in for
        // provenance: the question is who had the standing to say a bounded
        // undertaking exists, and evidence does not admit itself.
        Text(view.originMeans, style: text.bodySmall),
        if (detail.admittedBy != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Recorded by ${detail.admittedBy}',
                style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
          ),
        if (detail.originNote != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(detail.originNote!, style: text.bodySmall),
          ),

        // Why it stopped, when it did. Abandonment is a decision somebody
        // made, and a record without the reason is indistinguishable from
        // neglect — which is exactly what it must never be confused with.
        if (detail.abandonedReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Stopped because: ${detail.abandonedReason}',
                style: text.bodySmall),
          ),

        const SizedBox(height: 10),
        Text(detail.downstream.says,
            style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
        if (detail.downstream.anyExist)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${detail.downstream.agreements} agreements · '
              '${detail.downstream.obligations} obligations · '
              '${detail.downstream.invoices} invoices',
              style: text.bodySmall,
            ),
          ),

        if (view.state == EngagementState.open &&
            (onComplete != null || onAbandon != null)) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (onComplete != null)
                GovernedAction(
                  // Not "Won". Completion says the undertaking reached its
                  // legitimate conclusion — not that money arrived, not that
                  // obligations are discharged.
                  label: 'It reached its conclusion',
                  consequence: Consequence.reversibleInternal,
                  busy: busy,
                  onPressed: busy ? null : onComplete,
                ),
              if (onAbandon != null)
                GovernedAction(
                  label: 'It stopped without concluding',
                  consequence: Consequence.reversibleInternal,
                  busy: busy,
                  onPressed: busy ? null : onAbandon,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// What a person typed when opening an undertaking.
class _OpenIntent {
  const _OpenIntent({
    required this.purpose,
    required this.originNote,
    required this.admissionKey,
  });

  final String purpose;
  final String? originNote;
  final String admissionKey;
}

class _OpenUndertakingDialog extends StatefulWidget {
  const _OpenUndertakingDialog({required this.counterparty});

  final String? counterparty;

  @override
  State<_OpenUndertakingDialog> createState() => _OpenUndertakingDialogState();
}

class _OpenUndertakingDialogState extends State<_OpenUndertakingDialog> {
  final TextEditingController _purpose = TextEditingController();
  final TextEditingController _note = TextEditingController();

  /// Minted once, when the dialog opens, and reused for every submit from it.
  /// That is what makes a double-tap or a retry one undertaking instead of two.
  late final String _admissionKey =
      'client:${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _purpose.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counterparty = widget.counterparty;
    return AlertDialog(
      title: const Text('Open an undertaking'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              counterparty == null
                  ? 'Say what your business has taken on.'
                  : 'Say what your business has taken on with $counterparty.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _purpose,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'What is it',
                // The rule stated up front rather than sprung as a refusal
                // after the fact. The server will still refuse it — this just
                // means fewer people meet that refusal.
                helperText: 'Not who it is with — the relationship already '
                    'says that, and two undertakings would read identically.',
                helperMaxLines: 3,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'What supports this (optional)',
                helperText: 'What makes it true that this was taken on.',
                helperMaxLines: 2,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_OpenIntent(
            purpose: _purpose.text,
            originNote: _note.text,
            admissionKey: _admissionKey,
          )),
          child: const Text('Record it'),
        ),
      ],
    );
  }
}

class _AbandonDialog extends StatefulWidget {
  const _AbandonDialog({required this.purpose});

  final String purpose;

  @override
  State<_AbandonDialog> createState() => _AbandonDialogState();
}

class _AbandonDialogState extends State<_AbandonDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('It stopped without concluding'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.purpose,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Why did it stop',
              // The requirement, in the words of the rule behind it.
              helperText: 'A record with no reason is indistinguishable from '
                  'neglect. Silence and elapsed time cannot end an undertaking.',
              helperMaxLines: 3,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          Text(
            'If the work resumes later, that is a new undertaking rather than '
            'this one reopening.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.publicMuted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_reason.text),
          child: const Text('Record that it stopped'),
        ),
      ],
    );
  }
}

String _when(DateTime moment) {
  final days = DateTime.now().difference(moment).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 30) return '$days days ago';
  if (days < 365) {
    final months = (days / 30).floor();
    return months <= 1 ? 'last month' : '$months months ago';
  }
  return '${(days / 365).floor()} years ago';
}
