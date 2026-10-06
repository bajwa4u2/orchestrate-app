import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/market/client_market.dart';
import 'package:orchestrate_app/core/theme/ob.dart';

/// THE NOTE A BUSINESS WOULD RECEIVE, WHEREVER A YES IS GIVEN.
///
/// One yes covers who is written to and what they receive (founder, 6 Oct
/// 2026). Market's card, the business's sheet and Today all show this same
/// note before "Yes, send this note", so no yes is given to words nobody saw.
class NoteOnCard extends StatelessWidget {
  const NoteOnCard({
    super.key,
    required this.note,
    required this.busy,
    required this.onEdit,
    required this.onRewrite,
  });

  final CardNote note;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onRewrite;

  @override
  Widget build(BuildContext context) {
    if (!note.ok) {
      return Text(note.reason ?? 'No note is offered for this business.',
          style: Ob.body(13.5, color: Ob.inkMuted));
    }
    if (note.refused) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Ob.refusedSoft,
          borderRadius: BorderRadius.circular(Ob.radiusControl),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('No note we would send yet', style: Ob.strong(14)),
          const SizedBox(height: 4),
          Text(
              note.refusedBecause.isEmpty
                  ? 'The note did not pass its check.'
                  : note.refusedBecause.join('; '),
              style: Ob.body(13.5)),
          const SizedBox(height: 6),
          TextButton(onPressed: busy ? null : onRewrite, child: const Text('Write it again')),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Ob.well,
        borderRadius: BorderRadius.circular(Ob.radiusControl),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(note.edited ? 'Your note to them' : 'The note they will receive',
                style: Ob.body(12.5, color: Ob.inkMuted)),
          ),
          TextButton(onPressed: busy ? null : onEdit, child: const Text('Edit')),
        ]),
        Text(note.subject ?? '', style: Ob.strong(15)),
        const SizedBox(height: 8),
        Text(note.body ?? '', style: Ob.body(14.5)),
        const SizedBox(height: 10),
        if (note.bookingLinked)
          Text('Under it: your name and your booking link, so they can pick a time.',
              style: Ob.body(12.5, color: Ob.inkMuted)),
        if ((note.whatFollows ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(note.whatFollows!, style: Ob.body(12.5, color: Ob.inkMuted)),
        ],
        if (note.factsChanged) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text('Something about them changed since you wrote this.',
                  style: Ob.body(12.5, color: Ob.refused)),
            ),
            TextButton(onPressed: busy ? null : onRewrite, child: const Text('Write it again')),
          ]),
        ] else if (!note.edited)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: busy ? null : onRewrite, child: const Text('Write it again')),
          ),
      ]),
    );
  }
}

/// The owner's own words for a business's note. Returns the saved note, a
/// refusal note with its reason, or null when nothing was changed.
Future<CardNote?> editCardNote(
  BuildContext context, {
  required String businessName,
  required String candidateKey,
  required CardNote note,
}) async {
  final subject = TextEditingController(text: note.subject ?? '');
  final body = TextEditingController(text: note.body ?? '');
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Your note to $businessName', style: Ob.strong(17)),
      content: SizedBox(
        width: 560,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: subject,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: body,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(labelText: 'The note', alignLabelWithHint: true),
          ),
          const SizedBox(height: 6),
          Text('Your name, title and booking link are added under it.',
              style: Ob.body(12.5, color: Ob.inkMuted)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save these words')),
      ],
    ),
  );
  if (saved != true) return null;
  return ClientMarket.instance.editNote(candidateKey, subject: subject.text, body: body.text);
}
