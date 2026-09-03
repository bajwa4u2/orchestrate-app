import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_relationship_workspace_repository.dart';

/// THE HISTORY SPINE.
///
/// Outbound, delivery evidence, replies, meetings, decisions, agreements,
/// obligations, invoices and payments in one stream, in the order they
/// happened — because that is the order they happened in. None of them earned
/// global navigation merely by being a separate backend service.
///
/// Delivery truth renders on the message. A message that left and has no
/// evidence back says so, in those words. The client previously had `sent` in
/// 68 files and `delivered` in 4, which is how "it was sent" quietly became
/// "it arrived".
class RelationshipTimeline extends StatelessWidget {
  const RelationshipTimeline({
    super.key,
    required this.events,
    required this.correspondence,
  });

  final List<TimelineEvent> events;
  final List<Correspondence> correspondence;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty && correspondence.isEmpty) {
      return const QuietState(
        message: 'Nothing has happened here yet.',
        hint: 'Messages, replies and commercial events appear as they occur.',
      );
    }

    // Correspondence is shown first when present, because "what did we say and
    // did it arrive" is the question people actually open a relationship with.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (correspondence.isNotEmpty)
          WorkspaceBand(
            title: 'CORRESPONDENCE',
            children: [
              for (final m in correspondence) _MessageRow(message: m),
            ],
          ),
        WorkspaceBand(
          title: 'HISTORY',
          children: [
            for (final e in events) _EventRow(event: e),
          ],
        ),
      ],
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});

  final Correspondence message;

  @override
  Widget build(BuildContext context) {
    final truth = message.delivery;
    return WorkspaceRow(
      title: message.subject?.isNotEmpty == true
          ? message.subject!
          : '(no subject)',
      detail: truth.label,
      meta: _when(message.sentAt),
      tone: switch (truth) {
        DeliveryTruth.bounced || DeliveryTruth.failed => RowTone.problem,
        DeliveryTruth.delivered => RowTone.good,
        DeliveryTruth.noEvidenceYet => RowTone.waiting,
        DeliveryTruth.notSent => RowTone.neutral,
      },
      leading: Icon(
        message.direction == 'INBOUND' ? Icons.south_west : Icons.north_east,
        size: 15,
        color: AppTheme.publicMuted,
      ),
    );
  }

  static String? _when(DateTime? at) {
    if (at == null) return null;
    return '${at.day}/${at.month}';
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return WorkspaceRow(
      title: event.label,
      detail: _consequenceLine(event.consequence),
      meta: '${event.occurredAt.day}/${event.occurredAt.month}',
      tone: switch (event.consequence) {
        'CONTRACTUAL' || 'FINANCIAL' => RowTone.attention,
        'TERMINAL' => RowTone.problem,
        _ => RowTone.neutral,
      },
      leading: Icon(_iconFor(event), size: 15, color: AppTheme.publicMuted),
    );
  }

  /// Consequence is carried through from the backend rather than inferred, so
  /// a contractual act does not read like a note.
  static String? _consequenceLine(String? consequence) => switch (consequence) {
        'REVERSIBLE_INTERNAL' => null,
        'EXTERNALLY_COMMUNICATED' => 'Went to the counterparty',
        'CONTRACTUAL' => 'Committed the business',
        'FINANCIAL' => 'Money',
        'TERMINAL' => 'Final',
        _ => null,
      };

  static IconData _iconFor(TimelineEvent e) {
    final t = e.type.toLowerCase();
    if (t.contains('deliver') || e.evidenceKind == 'delivery_evidence') {
      return Icons.mark_email_read_outlined;
    }
    if (t.contains('repl')) return Icons.forum_outlined;
    if (t.contains('meeting')) return Icons.event_outlined;
    if (t.contains('agreement')) return Icons.handshake_outlined;
    if (t.contains('obligation')) return Icons.assignment_outlined;
    if (t.contains('invoice')) return Icons.receipt_long_outlined;
    if (t.contains('payment')) return Icons.payments_outlined;
    if (t.contains('outreach') || t.contains('message')) {
      return Icons.north_east;
    }
    return Icons.circle_outlined;
  }
}
