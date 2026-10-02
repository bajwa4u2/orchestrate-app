import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/core/ui/ob_widgets.dart';
import 'package:orchestrate_app/data/repositories/public/visitor_assistant_repository.dart';

/// ASK BEFORE YOU START (founder, 2 Oct 2026: "public home support ... with new
/// business and setup logic ... serve visitors").
///
/// One conversation for someone who has not signed up: answered on the spot
/// from what Orchestrate is today, about their own kind of business, with the
/// published prices. When it cannot settle it, or they ask, their name, email
/// and question go to a person, who replies within one business day.
///
/// The same design as signed-in Support: a raised card, ink bubbles for the
/// visitor, soft bubbles for the answer, at most two next steps per answer.
class VisitorAssistant extends StatefulWidget {
  const VisitorAssistant({super.key, required this.page, this.repository});

  /// Where it is shown ('/', '/contact'), so a person sees where it was asked.
  final String page;
  final VisitorAssistantRepository? repository;

  @override
  State<VisitorAssistant> createState() => _VisitorAssistantState();
}

class _VisitorAssistantState extends State<VisitorAssistant> {
  late final VisitorAssistantRepository _repo = widget.repository ?? VisitorAssistantRepository();
  final _ask = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _company = TextEditingController();

  final List<VisitorTurn> _turns = [];
  List<String> _starters = const [
    'What does Orchestrate do?',
    'Is it for my kind of business?',
    'What does it cost?',
    'Is anything sent without my yes?',
  ];
  bool _asking = false;
  String? _error;
  bool _personOpen = false;
  bool _sending = false;
  String? _personError;
  String? _handedOff;

  @override
  void initState() {
    super.initState();
    _repo.starters().then((s) {
      if (mounted && s.isNotEmpty) setState(() => _starters = s);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _ask.dispose();
    _name.dispose();
    _email.dispose();
    _company.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final q = (text ?? _ask.text).trim();
    if (q.isEmpty || _asking) return;
    final history = List<VisitorTurn>.of(_turns);
    setState(() {
      _turns.add(VisitorTurn.you(q));
      _ask.clear();
      _asking = true;
      _error = null;
    });
    try {
      final a = await _repo.ask(q, history, page: widget.page);
      if (!mounted) return;
      setState(() {
        _turns.add(VisitorTurn.support(a));
        if (a.offerPerson) _personOpen = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No answer came back just now. Ask again, or send it to a person below.';
        _personOpen = true;
      });
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _toPerson() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final asked = _turns.where((t) => t.fromYou).map((t) => t.text).toList();
    final message = _ask.text.trim().isNotEmpty ? _ask.text.trim() : (asked.isNotEmpty ? asked.last : '');
    if (name.isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) || message.isEmpty) {
      setState(() => _personError = message.isEmpty
          ? 'Write your question above first.'
          : 'Your name and an email address the reply can reach.');
      return;
    }
    setState(() {
      _sending = true;
      _personError = null;
    });
    try {
      final says = await _repo.handoff(
        name: name,
        email: email,
        company: _company.text.trim(),
        message: message,
        conversation: _turns,
        answerIds: [for (final t in _turns) if (t.answer != null && t.answer!.id.isNotEmpty) t.answer!.id],
        page: widget.page,
      );
      if (!mounted) return;
      setState(() {
        _handedOff = says;
        _personOpen = false;
        _ask.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _personError =
          'It did not send. Write to support@orchestrateops.com and a person will reply.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ObCard(
      raised: true,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ASK BEFORE YOU START', style: Ob.eyebrow()),
          const SizedBox(height: 6),
          Text('An answer on the spot, about your kind of business. A person when you want one.',
              style: Ob.body(14.5, color: Ob.inkMuted)),
          const SizedBox(height: 14),
          if (_turns.isEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in _starters)
                ActionChip(
                  label: Text(s, style: Ob.body(14, color: Ob.ink)),
                  backgroundColor: Ob.cardSoft,
                  side: const BorderSide(color: Ob.line),
                  onPressed: _asking ? null : () => _send(s),
                ),
            ]),
          for (final t in _turns) ...[
            _Bubble(turn: t, onOpen: (p) => context.go(p.route)),
            const SizedBox(height: 10),
          ],
          if (_asking)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Finding the answer…', style: Ob.body(14, color: Ob.inkMuted)),
            ),
          if (_handedOff != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Ob.cardSoft, borderRadius: BorderRadius.circular(10)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.mark_email_read_outlined, size: 20, color: Ob.ink),
                const SizedBox(width: 10),
                Expanded(child: Text(_handedOff!, style: Ob.body(14.5, color: Ob.ink))),
              ]),
            ),
          const SizedBox(height: 6),
          TextField(
            controller: _ask,
            minLines: 1,
            maxLines: 4,
            maxLength: 1200,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: Ob.body(16, color: Ob.ink),
            decoration: InputDecoration(
              hintText: _turns.isEmpty
                  ? 'For example: I run a roofing company. Would this work for me?'
                  : 'Ask a follow-up',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: Ob.body(13.5, color: Ob.refused)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilledButton(onPressed: _asking ? null : _send, child: Text(_asking ? 'Asking…' : 'Ask')),
            if (!_personOpen && _handedOff == null)
              TextButton(
                onPressed: () => setState(() => _personOpen = true),
                child: const Text('Talk to a person'),
              ),
          ]),
          if (_personOpen && _handedOff == null) _personForm(),
          const SizedBox(height: 10),
          Text('A person replies by email within one business day.',
              style: Ob.body(12.5, color: Ob.inkMuted)),
        ],
      ),
    );
  }

  Widget _personForm() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Ob.cardSoft,
        borderRadius: BorderRadius.circular(Ob.radiusCard),
        border: Border.all(color: Ob.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Send it to a person', style: Ob.strong(15)),
        const SizedBox(height: 4),
        Text('Your question and this conversation go with it, so you are not asked twice.',
            style: Ob.body(13.5, color: Ob.inkMuted)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final fields = [
            TextField(
              controller: _name,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Your email'),
            ),
          ];
          return c.maxWidth < 520
              ? Column(children: [fields[0], const SizedBox(height: 10), fields[1]])
              : Row(children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 10),
                  Expanded(child: fields[1]),
                ]);
        }),
        const SizedBox(height: 10),
        TextField(
          controller: _company,
          decoration: const InputDecoration(labelText: 'Your business (optional)'),
        ),
        if (_personError != null) ...[
          const SizedBox(height: 8),
          Text(_personError!, style: Ob.body(13.5, color: Ob.refused)),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _sending ? null : _toPerson,
            icon: const Icon(Icons.person_outline, size: 18),
            label: Text(_sending ? 'Sending…' : 'Send to a person'),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn, required this.onOpen});
  final VisitorTurn turn;
  final void Function(VisitorPlace) onOpen;

  @override
  Widget build(BuildContext context) {
    final a = turn.answer;
    return Align(
      alignment: turn.fromYou ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          decoration: BoxDecoration(
            color: turn.fromYou ? Ob.ink : Ob.cardSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(turn.text,
                style: Ob.body(15, color: turn.fromYou ? Ob.onInk : Ob.ink).copyWith(height: 1.45)),
            if (a?.question != null) ...[
              const SizedBox(height: 8),
              Text(a!.question!, style: Ob.strong(14.5)),
            ],
            if (a != null && a.places.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in a.places)
                  FilledButton.tonal(onPressed: () => onOpen(p), child: Text(p.label)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
