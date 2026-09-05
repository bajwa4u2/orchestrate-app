import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/return_path.dart';
import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/relationships/client_relationships.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
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
    if (list.relationships.isEmpty) {
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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
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
