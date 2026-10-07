import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/market/client_market.dart';
import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/features/client/widgets/prospect_facts.dart';
import 'package:orchestrate_app/features/client/widgets/pursuit_outcome.dart';

/// READ THE NOTE, IN ONE WIDE WINDOW (founder, 7 Oct 2026).
///
/// "Detail/read/edit card is too narrow." The note was read inside a narrow
/// card or a narrow sheet, and edited in a second window on top. Everywhere a
/// yes is given (Market, Today, the business's sheet) now opens this one
/// window: the business and why it fits on one side, the exact note on the
/// other, written as the window opens and edited in place, and the decision
/// at the foot. On a phone it fills the screen.
Future<void> showNoteReview(
  BuildContext context, {
  required Candidate candidate,
  VoidCallback? onDecided,
}) {
  final phone = MediaQuery.sizeOf(context).width < 760;
  final review = _NoteReview(candidate: candidate, onDecided: onDecided, phone: phone);
  if (phone) {
    // Above the app's tabs, the whole screen (7 Oct 2026: inside the tab
    // area it left the note a sliver between two bars).
    return Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Ob.paper,
        appBar: AppBar(title: Text(candidate.name), backgroundColor: Ob.paper),
        body: SafeArea(child: review),
      ),
    ));
  }
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => Dialog(
      backgroundColor: Ob.paper,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ob.radiusPanel)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 860),
        child: review,
      ),
    ),
  );
}

class _NoteReview extends StatefulWidget {
  const _NoteReview({required this.candidate, this.onDecided, this.phone = false});

  final Candidate candidate;
  final VoidCallback? onDecided;
  /// Full screen on a phone: the screen's bar carries the name and the close.
  final bool phone;

  @override
  State<_NoteReview> createState() => _NoteReviewState();
}

class _NoteReviewState extends State<_NoteReview> {
  CardNote? _note;
  bool _writing = true;
  bool _deciding = false;
  bool _editing = false;
  String? _failure;
  final _subject = TextEditingController();
  final _body = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load({bool rewrite = false}) async {
    setState(() {
      _writing = true;
      _failure = null;
      _editing = false;
    });
    try {
      final note = await ClientMarket.instance.note(widget.candidate.key, rewrite: rewrite);
      if (mounted) setState(() => _note = note);
    } catch (_) {
      if (mounted) setState(() => _failure = 'The note could not be written just now. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  void _startEdit() {
    final note = _note;
    if (note == null) return;
    _subject.text = note.subject ?? '';
    _body.text = note.body ?? '';
    setState(() => _editing = true);
  }

  Future<void> _saveEdit() async {
    setState(() {
      _writing = true;
      _failure = null;
    });
    try {
      final saved = await ClientMarket.instance
          .editNote(widget.candidate.key, subject: _subject.text, body: _body.text);
      if (!mounted) return;
      setState(() {
        if (saved.ok) {
          _note = saved;
          _editing = false;
        } else {
          _failure = saved.reason ?? 'Those words could not be saved.';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _failure = 'Your words could not be saved just now.');
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _decide(PursuitDisposition d) async {
    setState(() {
      _deciding = true;
      _failure = null;
    });
    try {
      final result = await ClientMarket.instance.setPursuit(
        key: widget.candidate.key,
        disposition: d,
        write: d == PursuitDisposition.pursuing ? _note : null,
      );
      if (!mounted) return;
      if (result['ok'] == true) {
        widget.onDecided?.call();
        final messenger = ScaffoldMessenger.maybeOf(context);
        Navigator.of(context).pop();
        if (messenger != null && messenger.mounted) showPursuitOutcome(messenger.context, result);
        return;
      }
      setState(() => _failure = (result['reason'] ?? 'That decision was not recorded.').toString());
    } catch (_) {
      if (mounted) setState(() => _failure = 'Your decision could not be recorded just now. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _deciding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final business = _Business(candidate: widget.candidate);
    final note = _NotePanel(
      note: _note,
      writing: _writing,
      editing: _editing,
      subject: _subject,
      body: _body,
      onEdit: _startEdit,
      onCancelEdit: () => setState(() => _editing = false),
      onSave: _saveEdit,
      onRewrite: () => _load(rewrite: true),
    );
    final busy = _writing || _deciding;
    final note0 = _note;
    final canSend = !busy && !_editing && note0 != null && note0.sendable;
    final yesLabel = _deciding
        ? 'Saving…'
        : _writing
            ? 'Writing the note…'
            : note0 != null && !note0.sendable
                ? 'No note to send yet'
                : 'Yes, send this note';
    if (widget.phone) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              note,
              const SizedBox(height: 20),
              business,
            ]),
          ),
        ),
        // While the words are being edited the decision waits, and its bar
        // steps aside so Cancel and Save are in full view (7 Oct 2026).
        if (!_editing) Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Ob.paper,
            border: Border(top: BorderSide(color: Ob.line)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_failure != null) ...[
              Text(_failure!, style: Ob.body(14, color: Ob.refused)),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: canSend ? () => _decide(PursuitDisposition.pursuing) : null,
              child: Text(yesLabel),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => _decide(PursuitDisposition.holding),
                  child: const Text('Not now'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: busy ? null : () => _decide(PursuitDisposition.declined),
                  child: const Text('Not for us'),
                ),
              ),
            ]),
          ]),
        ),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(widget.candidate.name, style: Ob.name(26))),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 340, child: SingleChildScrollView(child: business)),
                    const SizedBox(width: 28),
                    Expanded(child: SingleChildScrollView(child: note)),
                  ])
                : SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      business,
                      const SizedBox(height: 20),
                      note,
                    ]),
                  ),
          ),
          if (_failure != null) ...[
            const SizedBox(height: 10),
            Text(_failure!, style: Ob.body(14, color: Ob.refused)),
          ],
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.end, children: [
            TextButton(
              onPressed: busy ? null : () => _decide(PursuitDisposition.declined),
              child: const Text('Not for us'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => _decide(PursuitDisposition.holding),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: canSend ? () => _decide(PursuitDisposition.pursuing) : null,
              child: Text(yesLabel),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Who they are and why they fit: the facts a person can check.
class _Business extends StatelessWidget {
  const _Business({required this.candidate});

  final Candidate candidate;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Why them', style: Ob.body(12.5, color: Ob.inkMuted)),
      const SizedBox(height: 6),
      Text(prospectProposal(c), style: Ob.body(15)),
      const SizedBox(height: 14),
      for (final f in prospectFacts(c))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(f.icon, size: 16, color: Ob.inkMuted),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(f.text, style: Ob.body(14, color: Ob.inkSoft))),
          ]),
        ),
    ]);
  }
}

/// The exact note, shown as it will arrive, or edited in place.
class _NotePanel extends StatelessWidget {
  const _NotePanel({
    required this.note,
    required this.writing,
    required this.editing,
    required this.subject,
    required this.body,
    required this.onEdit,
    required this.onCancelEdit,
    required this.onSave,
    required this.onRewrite,
  });

  final CardNote? note;
  final bool writing;
  final bool editing;
  final TextEditingController subject;
  final TextEditingController body;
  final VoidCallback onEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onSave;
  final VoidCallback onRewrite;

  @override
  Widget build(BuildContext context) {
    final n = note;
    if (n == null) {
      return _panel(Row(children: [
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        Text('Writing the note they would receive…', style: Ob.body(15, color: Ob.inkSoft)),
      ]));
    }
    if (!n.ok) return _panel(Text(n.reason ?? 'No note is offered for this business.', style: Ob.body(15)));
    if (n.refused) {
      return _panel(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('No note we would send yet', style: Ob.strong(16)),
          const SizedBox(height: 6),
          Text(n.refusedBecause.isEmpty ? 'The note did not pass its check.' : n.refusedBecause.join('; '),
              style: Ob.body(14.5)),
          const SizedBox(height: 10),
          TextButton(onPressed: writing ? null : onRewrite, child: const Text('Write it again')),
        ]),
        color: Ob.refusedSoft,
      );
    }
    if (editing) {
      return _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Your note to them', style: Ob.body(12.5, color: Ob.inkMuted)),
        const SizedBox(height: 8),
        TextField(
          controller: subject,
          maxLength: 120,
          style: Ob.strong(16),
          decoration: const InputDecoration(labelText: 'Subject'),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: body,
          minLines: 10,
          maxLines: 18,
          style: Ob.body(15.5),
          decoration: const InputDecoration(labelText: 'The note', alignLabelWithHint: true),
        ),
        const SizedBox(height: 8),
        Text('Your name, title and booking link are added under it.',
            style: Ob.body(13, color: Ob.inkMuted)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: writing ? null : onCancelEdit, child: const Text('Cancel')),
          const SizedBox(width: 8),
          FilledButton(onPressed: writing ? null : onSave, child: const Text('Save these words')),
        ]),
      ]));
    }
    return _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(n.edited ? 'Your note to them' : 'The note they will receive',
          style: Ob.body(12.5, color: Ob.inkMuted)),
      Wrap(spacing: 4, children: [
        TextButton(onPressed: writing ? null : onEdit, child: const Text('Edit')),
        if (!n.edited || n.factsChanged)
          TextButton(onPressed: writing ? null : onRewrite, child: const Text('Write it again')),
      ]),
      const SizedBox(height: 4),
      SelectableText(n.subject ?? '', style: Ob.strong(17)),
      const SizedBox(height: 12),
      SelectableText(n.body ?? '', style: Ob.body(16)),
      const SizedBox(height: 16),
      if (n.bookingLinked)
        Text('Under it: your name and your booking link, so they can pick a time.',
            style: Ob.body(13, color: Ob.inkMuted)),
      if ((n.whatFollows ?? '').isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(n.whatFollows!, style: Ob.body(13, color: Ob.inkMuted)),
      ],
      if (n.factsChanged) ...[
        const SizedBox(height: 8),
        Text('Something about them changed since you wrote this.',
            style: Ob.body(13, color: Ob.refused)),
      ],
    ]));
  }

  Widget _panel(Widget child, {Color color = Ob.card}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Ob.radiusCard),
          boxShadow: Ob.liftLow,
        ),
        child: child,
      );
}
