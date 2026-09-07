import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/return_path.dart';
import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/relationships/client_relationships.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/theme/workspace_theme.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';
import 'package:orchestrate_app/features/client/widgets/meeting_line.dart';
import 'package:orchestrate_app/features/client/widgets/relationship_depth_view.dart';

/// RELATIONSHIPS — THE DURABLE UNIT OF ACCOUNT.
///
/// The list is a way in, not a second Market table. It carries only what makes
/// a row worth opening: who, where it stands, why that is the answer, and
/// whether anything is waiting.
///
/// A healthy relationship is quiet here. Problems and decisions earn prime
/// space; nothing gets a green banner for being fine.
class RelationshipsWorkspaceScreen extends StatefulWidget {
  const RelationshipsWorkspaceScreen({
    super.key,
    this.relationshipId,
    this.returnTo,
  });

  /// When set, the workspace opens straight into this relationship.
  final String? relationshipId;

  /// Where the person came from — Today, Market, or a deep link. Back goes
  /// there rather than always dumping them on the list.
  final String? returnTo;

  @override
  State<RelationshipsWorkspaceScreen> createState() =>
      _RelationshipsWorkspaceScreenState();
}

class _RelationshipsWorkspaceScreenState extends State<RelationshipsWorkspaceScreen> {
  final ClientRelationships _relationships = ClientRelationships.instance;

  @override
  void initState() {
    super.initState();
    _relationships.addListener(_onChanged);
    if (!_relationships.hasAnswer &&
        !_relationships.isLoading &&
        _relationships.error == null) {
      _relationships.load().catchError((Object e) => throw e);
    }
  }

  @override
  void dispose() {
    _relationships.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Depth is the whole screen when one is addressed, so the durable
    // relationship gets the room rather than sharing it with a list.
    if (widget.relationshipId != null) {
      return RelationshipDepthView(
        relationshipId: widget.relationshipId!,
        onBack: _back,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WorkspaceHeader(
          title: 'Relationships',
          context_: 'The businesses you have durable commercial context with.',
        ),
        _ViewTabs(
          selected: _relationships.view,
          counts: _relationships.list?.viewCounts ?? const {},
          onSelect: (v) => _relationships.load(view: v).catchError((Object e) => throw e),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  /// Back respects where they came from, and always has somewhere to go.
  void _back() {
    final to = readReturnTo({kReturnToParam: widget.returnTo ?? ''});
    context.go(to ?? '/client/relationships');
  }

  Widget _body() {
    if (_relationships.error != null) {
      return _Unavailable(onRetry: () => _relationships.refresh());
    }
    final list = _relationships.list;
    if (list == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (list.relationships.isEmpty && list.unattachedMeetings.isEmpty) {
      return const QuietState(
        message: 'No relationships yet.',
        hint: 'One begins when something durable passes between your business '
            'and a counterparty.',
      );
    }

    // Anything contested or never reached comes first, because those are the
    // ones where a person can change the outcome.
    bool needsALook(RelationshipSummary r) =>
        r.condition.wantsAttention || r.reachability.wantsAttention || r.attention > 0;
    final wanting = list.relationships.where(needsALook);
    final rest = list.relationships.where((r) => !needsALook(r));

    // Meetings that belong to no relationship on record. Placed high because
    // a meeting somebody may attend is a commitment, and this is the only
    // place in the workspace it appears at all.
    // Split, because a meeting that is going to happen and a meeting that
    // already did are not the same thing to a person scanning this. Shown
    // together, one booked meeting among four settled ones reads as archive
    // and the live one disappears into it — which is exactly what happened.
    final loose = list.unattachedMeetings;
    final looseAhead = loose.where((m) => m.isAhead).toList();
    final looseSettled = loose.where((m) => !m.isAhead).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Only what is still ahead earns space above the relationships. A
        // meeting somebody may still attend is a commitment; four settled ones
        // are history, and history that pushes eighteen relationships below
        // the fold has taken a place it did not earn.
        if (looseAhead.isNotEmpty)
          WorkspaceBand(
            title: 'MEETINGS AHEAD, NOT TIED TO A RELATIONSHIP',
            children: [for (final m in looseAhead) _MeetingRow(meeting: m)],
          ),
        if (wanting.isNotEmpty)
          WorkspaceBand(
            title: 'NEEDS A LOOK',
            children: [for (final r in wanting) _Row(summary: r, onOpen: _open)],
          ),
        if (rest.isNotEmpty)
          WorkspaceBand(
            // Named only when something above it needed the eye. With nothing
            // wanting attention this is simply the list, and a heading over it
            // would be furniture.
            title: wanting.isEmpty ? 'RELATIONSHIPS' : 'EVERYTHING ELSE',
            children: [for (final r in rest) _Row(summary: r, onOpen: _open)],
          ),
        // History, after the relationships rather than in front of them.
        //
        // Not "held": this band carried a cancelled meeting under a heading
        // that said it took place. The band says where these sit in time and
        // each row says what actually happened to it.
        if (looseSettled.isNotEmpty)
          WorkspaceBand(
            title: 'EARLIER MEETINGS, NOT TIED TO A RELATIONSHIP',
            children: [for (final m in looseSettled) _MeetingRow(meeting: m)],
          ),
        if (list.note.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              list.note,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.publicMuted),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  void _open(RelationshipSummary summary) {
    // Carries where we are so depth can return here rather than guessing.
    context.go(withReturnTo(
      '/client/relationships/${summary.id}',
      '/client/relationships',
    ));
  }
}

/// FILTERS OVER THE SAME DURABLE RECORDS.
///
/// Fifty-five relationships in one undifferentiated list is a table, and a
/// table is what this surface was rebuilt to stop being. These are questions
/// asked of the same records — a relationship's condition does not change
/// because somebody looked at a different view, and nothing here writes
/// anything.
///
/// The views are the server's own, so the two cannot drift into meaning
/// different things, and the counts are taken before filtering so a view that
/// is currently empty still says zero instead of disappearing. A tab that
/// vanishes when it holds nothing is how a person stops believing the tabs are
/// the whole picture.
///
/// "Cannot be reached" is the channel, not the relationship, and is named so
/// it can never be read as a lifecycle stage — a bounce-only relationship is
/// ACTIVE with reachability FAILED, and neither half implies the other.
class _ViewTabs extends StatelessWidget {
  const _ViewTabs({
    required this.selected,
    required this.counts,
    required this.onSelect,
  });

  final String selected;
  final Map<String, int> counts;
  final void Function(String) onSelect;

  static const _views = <({String key, String label})>[
    (key: 'all', label: 'All'),
    (key: 'attention', label: 'Needs attention'),
    (key: 'engaged', label: 'Undertaking open'),
    (key: 'open', label: 'Not closed'),
    (key: 'unreachable', label: 'Cannot be reached'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final v in _views)
            _Tab(
              label: v.label,
              // Absent while the first answer is still loading, and shown as
              // soon as it arrives. A dash is honest; a zero would not be.
              count: counts[v.key],
              selected: v.key == selected,
              onTap: () => onSelect(v.key),
              theme: theme,
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? null : AppTheme.publicMuted,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A meeting that has no relationship to sit inside.
///
/// Deliberately reads as a meeting rather than as a relationship: the point of
/// showing it here is that the business has a commitment the product could not
/// place, and dressing it up as a counterparty row would hide exactly that.
class _MeetingRow extends StatelessWidget {
  const _MeetingRow({required this.meeting});

  final RelationshipMeeting meeting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meeting.title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          // What happened, what was planned, and how long it ran — composed
          // once, so every surface says the same thing about a meeting.
          Text(
            meetingLine(meeting),
            style: theme.textTheme.bodySmall?.copyWith(
              color: meeting.neverReachedProvider ? Ws.caution : Ws.inkMuted,
            ),
          ),
          // The way in, and only while there is still a meeting to get into.
          if (meeting.entrance != null && meeting.isAhead) ...[
            const SizedBox(height: 4),
            SelectableText(
              meeting.entrance!,
              style: theme.textTheme.bodySmall?.copyWith(color: Ws.accent),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.summary, required this.onOpen});

  final RelationshipSummary summary;
  final void Function(RelationshipSummary) onOpen;

  @override
  Widget build(BuildContext context) {
    return WorkspaceRow(
      title: summary.counterparty,
      // The reason, not the label. "Active" alone tells a business nothing;
      // "one message went out, nothing has come back either way" does.
      detail: summary.conditionBecause,
      meta: _meta,
      tone: summary.reachability.wantsAttention
          ? RowTone.problem
          : switch (summary.condition) {
              RelationshipCondition.inDispute => RowTone.problem,
              RelationshipCondition.inEngagement => RowTone.good,
              RelationshipCondition.active => RowTone.neutral,
              RelationshipCondition.dormant => RowTone.waiting,
              RelationshipCondition.closed => RowTone.neutral,
            },
      onTap: () => onOpen(summary),
      action: const Icon(Icons.chevron_right, size: 18, color: AppTheme.publicMuted),
    );
  }

  /// Two axes, two words, both spelled out — never a colour alone. A
  /// relationship can be active and still not reachable, and a row that showed
  /// only one of those would mislead in one direction or the other.
  String get _meta => [
        summary.condition.label.toLowerCase(),
        if (summary.reachability != Reachability.confirmed)
          summary.reachability.label.toLowerCase(),
        // Only where the condition axis has not already said it. IN_ENGAGEMENT
        // is labelled "In an undertaking", so adding the marker unconditionally
        // printed the same fact twice: "in an undertaking · nothing sent · in
        // an undertaking". It still earns its place when something is open
        // while the relationship reads dormant or in dispute.
        if (summary.openEngagementId != null &&
            summary.condition != RelationshipCondition.inEngagement)
          'in an undertaking',
        if (summary.attention > 0)
          summary.attention == 1 ? '1 waiting' : '${summary.attention} waiting',
      ].join(' · ');
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('We could not load your relationships.',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Nothing has changed and nothing was lost. We just could not read '
            'them right now.',
            style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
