import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/core/ui/ob_widgets.dart';
import 'package:orchestrate_app/data/repositories/client/client_support_repository.dart';

/// SUPPORT THAT KNOWS THIS BUSINESS (DD-35, founder, 2 Oct 2026: "support them
/// where they stuck before sending to a human").
///
/// It used to discard the answer to a question and reload a list, knew nothing
/// about the business, and handed off to nobody. Now, top to bottom:
///
///   1. What is in your way, from the business's real standing, each with
///      whose move it is and the one place to fix it.
///   2. Ask: answered on the spot from product knowledge and that standing,
///      naming the place to go; a person offered when it cannot settle it.
///   3. Common questions, to browse without typing.
///   4. Your requests: what a person is handling, with the thread and a reply.
class ClientSupportScreen extends StatefulWidget {
  const ClientSupportScreen({super.key, this.repository});

  final ClientSupportRepository? repository;

  @override
  State<ClientSupportScreen> createState() => _ClientSupportScreenState();
}

class _ClientSupportScreenState extends State<ClientSupportScreen> {
  late final ClientSupportRepository _repo = widget.repository ?? ClientSupportRepository();
  final _ask = TextEditingController();
  final _caseReply = TextEditingController();

  SupportStanding? _standing;
  bool _standingFailed = false;
  List<SupportTopic> _topics = const [];
  List<SupportCase> _cases = const [];

  final List<SupportTurn> _turns = [];
  bool _asking = false;
  bool _handingOff = false;
  String? _handedOff;
  String? _askError;

  String? _openCase;
  List<SupportMessage> _thread = const [];
  bool _replying = false;
  String? _caseNote;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ask.dispose();
    _caseReply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _repo.standing().then((s) {
      if (mounted) setState(() => _standing = s);
    }, onError: (Object _) {
      if (mounted) setState(() => _standingFailed = true);
    });
    _repo.topics().then((t) {
      if (mounted) setState(() => _topics = t);
    }, onError: (Object _) {});
    _loadCases();
  }

  void _loadCases() {
    _repo.cases().then((c) {
      if (mounted) setState(() => _cases = c);
    }, onError: (Object _) {});
  }

  Future<void> _send() async {
    final text = _ask.text.trim();
    if (text.isEmpty || _asking) return;
    setState(() {
      _asking = true;
      _askError = null;
      _handedOff = null;
      _turns.add(SupportTurn(true, text));
      _ask.clear();
    });
    try {
      final history = _turns.sublist(0, _turns.length - 1);
      final answer = await _repo.ask(text, history);
      if (!mounted) return;
      setState(() => _turns.add(SupportTurn(false, answer.answer, answer: answer)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _askError = 'Support could not answer just now. You can send this to a person instead.');
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _toPerson() async {
    final first = _turns.firstWhere((t) => t.fromYou, orElse: () => SupportTurn(true, _ask.text.trim()));
    final message = first.text.trim();
    if (message.isEmpty || _handingOff) {
      setState(() => _askError = 'Write what you need help with first.');
      return;
    }
    setState(() => _handingOff = true);
    try {
      final says = await _repo.handoff(
        message,
        _turns.where((t) => t.text.isNotEmpty).toList(),
        [for (final t in _turns) if (t.answer != null) t.answer!.id],
      );
      if (!mounted) return;
      setState(() {
        _handedOff = says;
        _askError = null;
      });
      _loadCases();
    } catch (_) {
      if (!mounted) return;
      setState(() => _askError = 'It could not be sent just now. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _handingOff = false);
    }
  }

  Future<void> _openThread(String id) async {
    if (_openCase == id) {
      setState(() => _openCase = null);
      return;
    }
    setState(() {
      _openCase = id;
      _thread = const [];
      _caseNote = null;
    });
    try {
      final t = await _repo.thread(id);
      if (mounted && _openCase == id) setState(() => _thread = t);
    } catch (_) {
      if (mounted) setState(() => _caseNote = 'This request could not be opened just now.');
    }
  }

  Future<void> _replyOnCase(String id) async {
    final text = _caseReply.text.trim();
    if (text.isEmpty || _replying) return;
    setState(() => _replying = true);
    try {
      final says = await _repo.replyToCase(id, text);
      _caseReply.clear();
      final t = await _repo.thread(id);
      if (!mounted) return;
      setState(() {
        _thread = t;
        _caseNote = says;
      });
      _loadCases();
    } catch (_) {
      if (mounted) setState(() => _caseNote = 'Your reply could not be sent just now. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _replying = false);
    }
  }

  void _go(SupportPlace p) => context.go(p.route);

  // ── Layout ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final phone = Workspace.sizeOf(context, MediaQuery.sizeOf(context).width).isPhone;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ObHeadline('How can we help?', size: phone ? 30 : 40),
              const SizedBox(height: 8),
              Text(
                  'Ask anything about Orchestrate or your account. Support sees where '
                  'your business stands, so the answer is about you. A person takes '
                  'over whenever you want one.',
                  style: Ob.body(16, color: Ob.inkSoft)),
              const SizedBox(height: 28),
              _inYourWay(),
              const SizedBox(height: 30),
              _askCard(),
              if (_topics.isNotEmpty) ...[
                const SizedBox(height: 30),
                _commonQuestions(),
              ],
              if (_cases.isNotEmpty) ...[
                const SizedBox(height: 30),
                _requests(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _eyebrow(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: Ob.eyebrow()),
      );

  Widget _inYourWay() {
    final s = _standing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _eyebrow("WHAT'S IN YOUR WAY"),
        if (s == null && !_standingFailed)
          Text('Checking where your business stands…', style: Ob.body(14.5, color: Ob.inkMuted))
        else if (_standingFailed)
          Text('Where your business stands could not be checked just now. Ask below and Support will look.',
              style: Ob.body(14.5, color: Ob.inkMuted))
        else if (s!.items.isEmpty)
          ObCard(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: Ob.ink, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text('Nothing is in your way right now.', style: Ob.strong(15))),
            ]),
          )
        else
          for (final item in s.items) ...[
            _StandingRow(item: item, onOpen: _go),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _askCard() {
    final last = _turns.isNotEmpty && !_turns.last.fromYou ? _turns.last.answer : null;
    final canHandOff = _turns.any((t) => t.fromYou) && _handedOff == null;
    return ObCard(
      raised: true,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ASK', style: Ob.eyebrow()),
          const SizedBox(height: 12),
          for (final t in _turns) ...[
            _Bubble(turn: t, onOpen: _go),
            const SizedBox(height: 10),
          ],
          if (_asking)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Looking at your account…', style: Ob.body(14, color: Ob.inkMuted)),
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
          TextField(
            controller: _ask,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: Ob.body(16, color: Ob.ink),
            decoration: InputDecoration(
              hintText: _turns.isEmpty
                  ? 'For example: why does Market show no businesses?'
                  : 'Ask a follow-up, or answer the question above',
            ),
          ),
          if (_askError != null) ...[
            const SizedBox(height: 8),
            Text(_askError!, style: Ob.body(13.5, color: Ob.refused)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilledButton(
              onPressed: _asking ? null : _send,
              child: Text(_asking ? 'Asking…' : 'Ask'),
            ),
            if (canHandOff)
              (last?.offerPerson ?? false) || _askError != null
                  ? OutlinedButton.icon(
                      onPressed: _handingOff ? null : _toPerson,
                      icon: const Icon(Icons.person_outline, size: 18),
                      label: Text(_handingOff ? 'Sending…' : 'Send this to a person'),
                    )
                  : TextButton(
                      onPressed: _handingOff ? null : _toPerson,
                      child: Text(_handingOff ? 'Sending…' : 'Not answered? Send it to a person'),
                    ),
          ]),
          const SizedBox(height: 8),
          Text('A person replies by email within one business day.',
              style: Ob.body(12.5, color: Ob.inkMuted)),
        ],
      ),
    );
  }

  Widget _commonQuestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _eyebrow('COMMON QUESTIONS'),
        for (final topic in _topics)
          if (topic.questions.isNotEmpty)
            _TopicGroup(topic: topic, onOpen: _go),
      ],
    );
  }

  Widget _requests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _eyebrow('YOUR REQUESTS'),
        for (final c in _cases) ...[
          ObCard(
            padding: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              InkWell(
                onTap: () => _openThread(c.id),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.subject, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ob.strong(15)),
                        if (c.at != null) ...[
                          const SizedBox(height: 2),
                          Text(_when(c.at!), style: Ob.body(13, color: Ob.inkMuted)),
                        ],
                      ]),
                    ),
                    const SizedBox(width: 10),
                    ObPill(c.standing, tone: c.closed ? PillTone.plain : PillTone.ink),
                    const SizedBox(width: 6),
                    Icon(_openCase == c.id ? Icons.expand_less : Icons.expand_more, color: Ob.inkMuted),
                  ]),
                ),
              ),
              if (_openCase == c.id) _threadView(c),
            ]),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _threadView(SupportCase c) {
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ob.line))),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_thread.isEmpty && _caseNote == null)
          Text('Opening…', style: Ob.body(14, color: Ob.inkMuted)),
        for (final m in _thread) ...[
          Text('${m.who}${m.at != null ? ' · ${_when(m.at!)}' : ''}', style: Ob.body(12.5, color: Ob.inkMuted)),
          const SizedBox(height: 2),
          Text(m.text, style: Ob.body(14.5, color: Ob.ink)),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _caseReply,
          minLines: 1,
          maxLines: 5,
          style: Ob.body(15, color: Ob.ink),
          decoration: const InputDecoration(hintText: 'Reply to the person handling this'),
        ),
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton(
            onPressed: _replying ? null : () => _replyOnCase(c.id),
            child: Text(_replying ? 'Sending…' : 'Send reply'),
          ),
          if (_caseNote != null) ...[
            const SizedBox(width: 12),
            Expanded(child: Text(_caseNote!, style: Ob.body(13.5, color: Ob.inkMuted))),
          ],
        ]),
      ]),
    );
  }
}

/// "today · 4:42 PM", or "14 Sep 2026 · 5:18 PM". Always with the time.
String _when(DateTime at) {
  final now = DateTime.now();
  final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final time = '$h:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'AM' : 'PM'}';
  if (at.year == now.year && at.month == now.month && at.day == now.day) return 'today · $time';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${at.day} ${months[at.month - 1]} ${at.year} · $time';
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.item, required this.onOpen});
  final StandingItem item;
  final void Function(SupportPlace) onOpen;

  @override
  Widget build(BuildContext context) {
    final blocking = item.state == 'blocking';
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return ObCard(
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: blocking ? Ob.refused : (item.yours ? Ob.ink : Ob.line),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(item.title, style: Ob.strong(15)),
              ObPill(item.yours ? 'Your move' : 'Orchestrate is on it',
                  tone: item.yours ? PillTone.ink : PillTone.plain),
            ]),
            if (item.detail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.detail, style: Ob.body(14, color: Ob.inkSoft)),
            ],
            // Beneath on a phone: beside the text it squeezed the reason
            // into a narrow column (Pixel walk, 3 Oct 2026).
            if (item.place != null && narrow) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => onOpen(item.place!), child: Text(item.place!.label)),
            ],
          ]),
        ),
        if (item.place != null && !narrow) ...[
          const SizedBox(width: 12),
          OutlinedButton(onPressed: () => onOpen(item.place!), child: Text(item.place!.label)),
        ],
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn, required this.onOpen});
  final SupportTurn turn;
  final void Function(SupportPlace) onOpen;

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

class _TopicGroup extends StatefulWidget {
  const _TopicGroup({required this.topic, required this.onOpen});
  final SupportTopic topic;
  final void Function(SupportPlace) onOpen;

  @override
  State<_TopicGroup> createState() => _TopicGroupState();
}

class _TopicGroupState extends State<_TopicGroup> {
  bool _open = false;
  String? _question;

  @override
  Widget build(BuildContext context) {
    final t = widget.topic;
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ob.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(children: [
              Expanded(child: Text(t.label, style: Ob.strong(15.5))),
              Text('${t.questions.length}', style: Ob.body(13.5, color: Ob.inkMuted)),
              const SizedBox(width: 6),
              Icon(_open ? Icons.expand_less : Icons.expand_more, color: Ob.inkMuted),
            ]),
          ),
        ),
        if (_open)
          for (final q in t.questions)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                InkWell(
                  onTap: () => setState(() => _question = _question == q.question ? null : q.question),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(q.question,
                        style: Ob.body(15, color: Ob.ink).copyWith(
                            decoration: _question == q.question ? null : TextDecoration.underline,
                            decorationColor: Ob.line)),
                  ),
                ),
                if (_question == q.question) ...[
                  Text(q.answer, style: Ob.body(14.5, color: Ob.inkSoft).copyWith(height: 1.5)),
                  if (q.places.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final p in q.places)
                        OutlinedButton(onPressed: () => widget.onOpen(p), child: Text(p.label)),
                    ]),
                  ],
                  const SizedBox(height: 10),
                ],
              ]),
            ),
      ]),
    );
  }
}
