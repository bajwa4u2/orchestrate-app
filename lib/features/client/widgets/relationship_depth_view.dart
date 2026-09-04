import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/relationships/client_relationships.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/ui/authority_gate.dart';
import 'package:orchestrate_app/core/ui/governed_action.dart';

/// ONE DURABLE RELATIONSHIP.
///
/// The test this has to pass: a business opening it should understand the
/// commercial relationship, not see the database records that happened
/// underneath it.
///
/// So the first viewport is who they are, where this stands and why, anything
/// waiting, and the current undertaking if one exists. Not event counts, not a
/// lead score, not seven status cards, not a raw activity log.
///
/// A healthy relationship stays quiet. There is no green banner for being fine
/// — problems and decisions earn prime space and everything else recedes.
class RelationshipDepthView extends StatefulWidget {
  const RelationshipDepthView({
    super.key,
    required this.relationshipId,
    required this.onBack,
  });

  final String relationshipId;
  final VoidCallback onBack;

  @override
  State<RelationshipDepthView> createState() => _RelationshipDepthViewState();
}

class _RelationshipDepthViewState extends State<RelationshipDepthView> {
  final ClientRelationships _relationships = ClientRelationships.instance;

  RelationshipDepth? _depth;
  Object? _error;

  // Local state, and only ever this: what is expanded. Condition, timeline and
  // engagement containment are server truth and are never held here.
  bool _showHistory = false;
  bool _showProvenance = false;
  bool _showPastEngagements = false;

  @override
  void initState() {
    super.initState();
    _relationships.addListener(_onChanged);
    _load();
  }

  @override
  void didUpdateWidget(RelationshipDepthView old) {
    super.didUpdateWidget(old);
    if (old.relationshipId != widget.relationshipId) _load();
  }

  @override
  void dispose() {
    _relationships.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final cached = _relationships.cachedDepth(widget.relationshipId);
    if (cached != null && mounted) setState(() => _depth = cached);
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _depth = _relationships.cachedDepth(widget.relationshipId);
    });
    try {
      final depth = await _relationships.depth(widget.relationshipId);
      if (mounted) setState(() => _depth = depth);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final depth = _depth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspaceHeader(
          title: depth?.counterparty ?? 'Relationship',
          context_: depth?.counterpartyKey ?? '',
          onBack: widget.onBack,
        ),
        Expanded(child: _body(depth)),
      ],
    );
  }

  Widget _body(RelationshipDepth? depth) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('We could not load this relationship.',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'Nothing has changed. The relationship and its history are intact.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.publicMuted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (depth == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (depth.refusalReason != null) {
      return QuietState(message: 'Not available', hint: depth.refusalReason!);
    }

    final text = Theme.of(context).textTheme;
    final current = depth.currentEngagement;
    final past = depth.pastEngagements;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── WHERE THIS STANDS ─────────────────────────────────────────────
        //
        // Compact by design. A condition that needs a person gets a border; a
        // healthy one is a line of text and takes almost no room.
        _Standing(
          condition: depth.condition,
          means: depth.conditionMeans,
          because: depth.conditionBecause,
        ),

        // ── WHAT IS WAITING ───────────────────────────────────────────────
        //
        // Referenced from Attention, never rebuilt here. Resolving it there
        // updates this view and Today through the shared authority.
        if (depth.attention.isNotEmpty)
          WorkspaceBand(
            title: 'WAITING ON SOMEONE',
            children: [
              for (final a in depth.attention)
                WorkspaceRow(
                  title: a.subject,
                  detail: 'This arrived and has not been placed on the relationship.',
                  meta: [
                    if (a.from != null) a.from!,
                    if (a.receivedAt != null) _when(a.receivedAt!),
                  ].join(' · '),
                  tone: RowTone.attention,
                  onTap: () => context.go('/client/inbound'),
                  action: const Icon(Icons.chevron_right,
                      size: 18, color: AppTheme.publicMuted),
                ),
            ],
          ),

        // ── THE CURRENT UNDERTAKING ───────────────────────────────────────
        //
        // Contained inside the relationship, never a competing domain. Its
        // absence is not a void: durable context legitimately exists before any
        // undertaking begins, and most production relationships are there.
        if (current != null)
          WorkspaceBand(
            title: 'CURRENT UNDERTAKING',
            children: [
              WorkspaceRow(
                title: current.reference ?? 'Open undertaking',
                detail: 'Opened ${current.openedAt != null ? _when(current.openedAt!) : 'recently'}. '
                    'The commercial detail of an undertaking is not built yet.',
                meta: current.label.toLowerCase(),
                tone: RowTone.good,
              ),
            ],
          ),

        if (past.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _showPastEngagements = !_showPastEngagements),
            icon: Icon(_showPastEngagements ? Icons.expand_less : Icons.expand_more,
                size: 18),
            label: Text(_showPastEngagements
                ? 'Hide earlier undertakings'
                : past.length == 1
                    ? 'Show 1 earlier undertaking'
                    : 'Show ${past.length} earlier undertakings'),
          ),
          if (_showPastEngagements)
            WorkspaceBand(
              title: 'EARLIER UNDERTAKINGS',
              children: [
                for (final e in past)
                  WorkspaceRow(
                    title: e.reference ?? 'Undertaking',
                    detail: 'A relationship does not end because an undertaking does.',
                    meta: e.label.toLowerCase(),
                    tone: RowTone.neutral,
                  ),
              ],
            ),
        ],

        // ── HISTORY ───────────────────────────────────────────────────────
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => setState(() => _showHistory = !_showHistory),
          icon: Icon(_showHistory ? Icons.expand_less : Icons.expand_more, size: 18),
          label: Text(_showHistory
              ? 'Hide what has happened'
              : 'What has happened (${depth.timeline.length})'),
        ),
        if (_showHistory)
          WorkspaceBand(
            title: 'HISTORY',
            children: [
              for (final entry in depth.timeline)
                WorkspaceRow(
                  title: entry.says,
                  // Superseded facts stay in the story and stop being the
                  // answer. History explains how we got here; current truth
                  // explains what governs now.
                  detail: entry.isCurrent
                      ? null
                      : 'A later record replaced this. Kept because it happened.',
                  meta: [
                    _when(entry.at),
                    if (entry.until != null && entry.occurrences > 1)
                      'through ${_when(entry.until!)}',
                    if (!entry.isCurrent) 'superseded',
                  ].join(' · '),
                  tone: entry.isCurrent ? RowTone.neutral : RowTone.waiting,
                ),
            ],
          ),

        // ── WHY THIS EXISTS ───────────────────────────────────────────────
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => setState(() => _showProvenance = !_showProvenance),
          icon: Icon(_showProvenance ? Icons.expand_less : Icons.expand_more, size: 18),
          label: const Text('Why this relationship exists'),
        ),
        if (_showProvenance)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.publicLine),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(depth.origin.says, style: text.bodySmall),
                if (depth.origin.at != null) ...[
                  const SizedBox(height: 6),
                  Text('The earliest thing on record here is from '
                      '${_when(depth.origin.at!)}.',
                      style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
                ],
                if (depth.origin.provenanceIsWeak) ...[
                  const SizedBox(height: 8),
                  // Admitted rather than hidden. Every production relationship
                  // record was created after the history it describes.
                  Text(
                    'This record was created after the events it describes, so '
                    'we cannot be certain nothing earlier is missing.',
                    style: text.bodySmall?.copyWith(color: AppTheme.amber),
                  ),
                ],
                const SizedBox(height: 8),
                Text('${depth.eventCount} things are on record here.',
                    style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
              ],
            ),
          ),

        // ── WHAT COULD HAPPEN NEXT ────────────────────────────────────────
        const SizedBox(height: 24),
        Text('Reaching out',
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        // Market makes an opportunity visible; the relationship makes the next
        // act visible. Neither may act on it — the authority contract answers,
        // and today it refuses for every client in production.
        AuthorityGate(
          consequence: Consequence.externallyCommunicated,
          label: 'Write to ${depth.counterparty}',
          onProceed: () {},
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  static String _when(DateTime at) {
    final days = DateTime.now().difference(at).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 30) return '$days days ago';
    if (days < 365) return '${(days / 30).round()} months ago';
    return '${at.year}-${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')}';
  }
}

/// Where the relationship stands, and why.
///
/// The word alone is not enough — "Active" about a counterparty nothing has
/// ever reached is exactly the lie this chapter set out to stop. The reason
/// travels with it, always.
class _Standing extends StatelessWidget {
  const _Standing({
    required this.condition,
    required this.means,
    required this.because,
  });

  final RelationshipCondition condition;
  final String means;
  final String because;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final wants = condition.wantsAttention;

    // A healthy relationship gets a line. Something that needs a person gets a
    // border and the space that goes with it.
    if (!wants) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, size: 15, color: AppTheme.publicMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: condition.label,
                      style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: ' — $because',
                      style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
                    ),
                  ],
                ),
                style: text.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 16, color: AppTheme.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(condition.label,
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(means,
                    style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
                const SizedBox(height: 6),
                Text(because, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData get _icon => switch (condition) {
        RelationshipCondition.inEngagement => Icons.handshake_outlined,
        RelationshipCondition.inDispute => Icons.gpp_maybe_outlined,
        RelationshipCondition.active => Icons.trending_flat,
        RelationshipCondition.unreachable => Icons.mark_email_unread_outlined,
        RelationshipCondition.dormant => Icons.schedule,
        RelationshipCondition.closed => Icons.do_not_disturb_on_outlined,
      };
}
