import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/commercial/client_capabilities.dart';
import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/market/client_market.dart';
import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/core/ui/ob_widgets.dart';
import 'package:orchestrate_app/features/client/widgets/candidate_sheet.dart';
import 'package:orchestrate_app/features/client/widgets/commercial_boundary.dart';

/// MARKET — WHO MAY BE WORTH ENTERING INTO COMMERCIAL RELATIONSHIP WITH.
///
/// Relationship is depth; Market is comparison. So this is a list a person can
/// scan and judge across, not a stack of company cards each five screens tall,
/// and not a CRM grid either.
///
/// What it deliberately does not open with: "215 leads", "average score 74",
/// "6 campaigns", "79,705 signals". Those are accounting numbers about a
/// database. The question a business actually arrives with is who deserves
/// attention now and why, so the first thing on screen is what the business
/// sells, and then the counterparties where something was genuinely observed.
///
/// Ordering comes from the server. A client-side re-rank would be a second
/// commercial opinion, and one of the two would be wrong in front of a real
/// business.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key, this.focusCounterpartyKey});

  /// Open straight onto one counterparty. Used when a person arrives from work
  /// that is about a specific company, so they land on the thing rather than
  /// on a list they then have to search.
  final String? focusCounterpartyKey;

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final ClientMarket _market = ClientMarket.instance;
  bool _showQuiet = false;

  @override
  void initState() {
    super.initState();
    _market.addListener(_onChanged);
    // Whether this business may be searched for at all is part of what an
    // empty Market has to explain, so the commercial answer is asked for here.
    ClientCapabilities.instance.addListener(_onChanged);
    unawaited(ClientCapabilities.instance
        .load()
        .then<void>((_) {}, onError: (Object _) {}));
    if (!_market.hasAnswer && !_market.isLoading && _market.error == null) {
      // Held, not rethrown. load() has already recorded the error and notified
      // listeners, so _body() renders the failure; rethrowing here does nothing
      // except turn a handled error into an unhandled async one, which reaches
      // the zone handler and reports as a crash on top of a screen that is
      // already showing the problem correctly.
      unawaited(_market.load().then<void>((_) {}, onError: (Object _) {}));
    }
    _focusIfAsked();
  }

  @override
  void dispose() {
    _market.removeListener(_onChanged);
    ClientCapabilities.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
    _focusIfAsked();
  }

  bool _focused = false;

  /// Opens the requested counterparty once the answer is in, and only once.
  /// A key we do not hold is left alone — arriving on the list is a fair
  /// outcome, and inventing a sheet for a company Market cannot see is not.
  void _focusIfAsked() {
    final key = widget.focusCounterpartyKey;
    if (_focused || key == null || !mounted || !_market.hasAnswer) return;
    Candidate? match;
    for (final c in _market.view!.candidates) {
      if (c.key == key) match = c;
    }
    if (match == null) return;
    _focused = true;
    final found = match;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open(found);
    });
  }

  // DD-30: the whole page scrolls. The header was pinned above an inner list
  // and took about 40% of a laptop screen before a single business showed.
  @override
  Widget build(BuildContext context) {
    final view = _market.view;
    final failure = _market.error;
    final Widget body;
    if (failure != null) {
      body = _Unavailable(error: failure, onRetry: () => _market.refresh());
    } else if (view == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    } else {
      body = _body(view);
    }
    return RefreshIndicator(
      onRefresh: () => _market.refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MarketHeader(view: view),
            const SizedBox(height: 22),
            body,
          ],
        ),
      ),
    );
  }

  Widget _body(MarketView view) {
    // AN EMPTY MARKET MUST EXPLAIN ITSELF.
    //
    // These are different situations, not one. "Nobody has been found yet"
    // reads as "there is nobody out there" — and for most of this product's
    // life the real answer was that discovery could not look, or did not know
    // where to look. Only one branch below is a statement about the world, and
    // even that one is bounded by how much has actually been searched.
    if (view.candidates.isEmpty) {
      final coverage = view.coverage;

      // A POINTER HAS TO LEAD SOMEWHERE THAT RESOLVES IT.
      if (view.intent == null) {
        return QuietState(
          message: 'Your business has not said what it sells.',
          hint: 'Until it does, there is nothing to judge a counterparty '
              'against. Describe your offer in Business identity.',
          action: OutlinedButton(
            onPressed: () => context.go('/client/representation'),
            child: const Text('Describe what you sell'),
          ),
        );
      }

      // The one thing only the business can resolve, so it comes first.
      if (coverage.geographyNeedsConfirmation) {
        return QuietState(
          message: 'We need to know where your market is.',
          hint: 'Once your business sets the places it sells into, we can '
              'start looking for businesses there.',
          action: OutlinedButton(
            onPressed: () => context.go('/client/setup'),
            child: const Text('Set where you operate'),
          ),
        );
      }

      // NOT SEARCHED BECAUSE IT MAY NOT BE, SAID AS THAT.
      if (ClientCapabilities.instance
              .refusalFor(Capabilities.researchCounterparties) !=
          null) {
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuietState(message: 'Your market is not being searched.'),
            CommercialBoundary(capability: Capabilities.researchCounterparties),
          ],
        );
      }

      if (!coverage.discovering) {
        return const QuietState(
          message: 'Discovery is paused for your market.',
          hint: 'Nothing is being looked for right now.',
        );
      }

      // Found, and still being proven. The checks themselves are the promise.
      if (view.research.checking > 0 || coverage.hasSearched) {
        return _ChecksPromise(research: view.research, coverage: coverage);
      }

      return const QuietState(
        message: 'Searching your market.',
        hint: 'Businesses appear here once they pass every check.',
      );
    }

    final ready = view.needsReview;
    final decided = view.decided;
    final quiet = view.notEnoughKnown;
    final related = view.alreadyRelated;
    final setAside = view.excludedWithoutIdentity + view.excludedArtifacts;

    // DD-26 (board S09): cards a person can decide on where they stand. The
    // order is the server's; nothing here re-ranks.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_decisionFailure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(_decisionFailure!,
                style: Ob.body(14, color: Ob.refused)),
          ),
        if (ready.isEmpty)
          _ChecksPromise(research: view.research, coverage: view.coverage)
        else ...[
          _Section('Ready for you',
              note: ready.length == 1
                  ? 'One business passed every check.'
                  : '${ready.length} businesses passed every check.',
              first: true),
          _Grid(children: [
            for (final c in ready)
              _CandidateCard(
                candidate: c,
                busy: _deciding.contains(c.key),
                onOpen: _open,
                onDecide: _decide,
              ),
          ]),
        ],
        if (decided.isNotEmpty) ...[
          const _Section('You decided'),
          _Rows(children: [
            for (final c in decided) _DecidedRow(candidate: c, onOpen: _open),
          ]),
        ],
        if (related.isNotEmpty) ...[
          const _Section('Already your customers'),
          _Rows(children: [
            for (final c in related) _DecidedRow(candidate: c, onOpen: _open),
          ]),
        ],
        if (quiet.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showQuiet = !_showQuiet),
              icon: Icon(_showQuiet ? Icons.expand_less : Icons.expand_more,
                  size: 18),
              label: Text(_showQuiet
                  ? 'Hide the ones we know little about'
                  : 'Show ${quiet.length} we know little about'),
            ),
          ),
          if (_showQuiet)
            _Rows(children: [
              for (final c in quiet)
                _DecidedRow(candidate: c, onOpen: _open, detail: c.certaintyMeans),
            ]),
        ],
        if (view.excludedNote != null && setAside > 0) ...[
          const SizedBox(height: 20),
          Text('$setAside set aside. ${view.excludedNote!}',
              style: Ob.body(13, color: Ob.inkMuted)),
        ],
      ],
    );
  }

  final Set<String> _deciding = {};
  String? _decisionFailure;

  Future<void> _decide(Candidate c, PursuitDisposition d) async {
    setState(() {
      _deciding.add(c.key);
      _decisionFailure = null;
    });
    try {
      final result = await _market.setPursuit(key: c.key, disposition: d);
      if (result['ok'] != true && mounted) {
        setState(() => _decisionFailure = (result['says'] ??
                result['message'] ??
                'That decision was not recorded.')
            .toString());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _decisionFailure =
            'Your decision on ${c.name} could not be recorded just now. '
            'Try again in a moment.');
      }
    } finally {
      if (mounted) setState(() => _deciding.remove(c.key));
    }
  }

  void _open(Candidate candidate) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CandidateSheet(
        candidate: candidate,
        onChanged: () => _market.refresh(),
      ),
    );
  }
}

/// "14 Sep 2026 · 5:18 PM", or "today · 5:18 PM". Always with the time.
String _when(DateTime at) {
  final now = DateTime.now();
  final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final time = '$h:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'AM' : 'PM'}';
  final today = at.year == now.year && at.month == now.month && at.day == now.day;
  if (today) return 'today · $time';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${at.day} ${months[at.month - 1]} ${at.year} · $time';
}

String _count(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// What the business sells, and one line on the research under way. No
/// tiles: the counts that matter are said in a sentence.
class _MarketHeader extends StatelessWidget {
  const _MarketHeader({required this.view});
  final MarketView? view;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final phone =
        Workspace.sizeOf(context, MediaQuery.sizeOf(context).width).isPhone;
    final r = v?.research;
    final researching = r != null && (r.checking + r.passed) > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ObHeadline('Businesses worth your time', size: phone ? 28 : 34),
        if (v?.intent != null) ...[
          const SizedBox(height: 6),
          Text(v!.intent!.says,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Ob.body(15, color: Ob.inkSoft)),
          if (v.intent!.triggers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('We watch for: ${v.intent!.triggers.join(', ').toLowerCase()}.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ob.body(13.5, color: Ob.inkMuted)),
          ],
        ],
        if (researching) ...[
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: _Pulse(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Checking ${_count(r.checking)} '
                '${r.checking == 1 ? 'business' : 'businesses'} in your market. '
                '${r.passed == 0 ? 'None has' : '${_count(r.passed)} ${r.passed == 1 ? 'has' : 'have'}'} '
                'passed every check so far.'
                '${r.lastCheckedAt != null ? ' Last check ${_when(r.lastCheckedAt!)}.' : ''}',
                style: Ob.body(13.5, color: Ob.inkMuted),
              ),
            ),
          ]),
        ],
      ],
    );
  }
}

/// A small steady dot: the research is running.
class _Pulse extends StatelessWidget {
  const _Pulse();

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: Ob.inkSoft, shape: BoxShape.circle),
      );
}

/// Before anything has passed: what every business must prove before it is
/// shown here. The promise, said once, instead of an empty list.
class _ChecksPromise extends StatelessWidget {
  const _ChecksPromise({required this.research, required this.coverage});
  final MarketResearch research;
  final MarketCoverage coverage;

  static const _checks = [
    ('It exists', 'Seen by two independent sources, or an official registry.'),
    ('It is alive', 'Its own website answers, and it is not parked.'),
    ('It fits', 'It is the kind of business you sell to.'),
    ('It can be reached', 'It published an address, and that mailbox accepts mail.'),
    ('It can be explained', 'Why it fits is said in plain words.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Ob.card,
        borderRadius: BorderRadius.circular(Ob.radiusCard),
        border: Border.all(color: Ob.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nothing has passed every check yet.', style: Ob.name(20)),
          const SizedBox(height: 6),
          Text(
              'We show a business only when all five hold. Anything that passes '
              'appears here with the reason, and on Today.',
              style: Ob.body(14.5, color: Ob.inkSoft)),
          const SizedBox(height: 16),
          for (final (title, detail) in _checks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_circle_outline, size: 18, color: Ob.inkMuted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '$title. ', style: Ob.strong(14)),
                    TextSpan(text: detail, style: Ob.body(14, color: Ob.inkSoft)),
                  ])),
                ),
              ]),
            ),
          if (coverage.note != null) ...[
            const SizedBox(height: 4),
            Text(coverage.note!, style: Ob.body(13, color: Ob.inkMuted)),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.note, this.first = false});
  final String title;
  final String? note;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 28, bottom: 12),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(title, style: Ob.name(21)),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(note!, style: Ob.body(13.5, color: Ob.inkMuted)),
              ),
          ],
        ),
      );
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
      final w = (c.maxWidth - 16 * (cols - 1)) / cols;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: w, child: child)
        ],
      );
    });
  }
}

/// Decided businesses, as a list: they are a record now, not a judgement.
class _Rows extends StatelessWidget {
  const _Rows({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Ob.card,
          borderRadius: BorderRadius.circular(Ob.radiusCard),
          border: Border.all(color: Ob.line),
        ),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Ob.line),
            children[i],
          ],
        ]),
      );
}

class _DecidedRow extends StatelessWidget {
  const _DecidedRow({required this.candidate, required this.onOpen, this.detail});
  final Candidate candidate;
  final void Function(Candidate) onOpen;

  /// A line under the name, for rows that are not a decision yet.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final state = c.hasRelationship
        ? 'Customer'
        : switch (c.disposition) {
            PursuitDisposition.pursuing => 'On your Today list',
            _ => c.disposition.label,
          };
    final where = [
      if ((c.geography ?? '').isNotEmpty) c.geography!,
      if (c.domain.isNotEmpty && !c.domain.startsWith('name:')) c.domain,
    ].join(' · ');
    return InkWell(
      onTap: () => c.hasRelationship && c.relationshipId != null
          ? context.go('/client/relationships/${c.relationshipId}')
          : onOpen(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: Ob.strong(15)),
              if (where.isNotEmpty)
                Text(where,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ob.body(13, color: Ob.inkMuted)),
              if ((detail ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(detail!, style: Ob.body(13.5, color: Ob.inkSoft)),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          Text(state, style: Ob.body(13.5, color: Ob.inkSoft)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 18, color: Ob.inkFaint),
        ]),
      ),
    );
  }
}

/// One business that passed every check: why it fits, what was proven, and
/// the owner's decision.
class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.busy,
    required this.onOpen,
    this.onDecide,
  });

  final Candidate candidate;
  final bool busy;
  final void Function(Candidate) onOpen;
  final Future<void> Function(Candidate, PursuitDisposition)? onDecide;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final checks = c.checks;
    final reason = switch (c.certainty) {
      Certainty.evidenced || Certainty.thin => c.whyItMatters ?? c.certaintyMeans,
      Certainty.stale || Certainty.insufficient =>
        checks != null ? (c.whyItMatters ?? c.certaintyMeans) : c.certaintyMeans,
    };
    // Never green: green is money. A passed check is said as a word.
    final pill = checks != null
        ? const ObPill('Checked', tone: PillTone.ink)
        : ObPill(c.certainty.label, tone: PillTone.plain);
    final decide = onDecide;
    Widget fact(IconData icon, String text, {Color color = Ob.inkSoft}) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 15, color: Ob.inkMuted),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: Ob.body(13.5, color: color))),
          ]),
        );
    return InkWell(
      onTap: () => onOpen(c),
      borderRadius: BorderRadius.circular(Ob.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Ob.card,
          borderRadius: BorderRadius.circular(Ob.radiusCard),
          boxShadow: Ob.liftLow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(c.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: Ob.name(20)),
              ),
              const SizedBox(width: 8),
              pill,
            ]),
            const SizedBox(height: 10),
            Text(reason,
                maxLines: 4, overflow: TextOverflow.ellipsis, style: Ob.body(14.5)),
            const SizedBox(height: 6),
            if ((c.geography ?? '').isNotEmpty) fact(Icons.place_outlined, c.geography!),
            if (c.domain.isNotEmpty && !c.domain.startsWith('name:'))
              fact(Icons.language,
                  '${c.domain}${checks?.websiteAnswers == true ? ', its own site, answering' : ''}'),
            if (checks != null) ...[
              fact(
                Icons.alternate_email,
                '${checks.email}, found ${checks.addressFoundInSaid}'
                '${checks.mailboxConfirmed ? '. Its mailbox accepts mail.' : '.'}',
              ),
              if (checks.checkedAt != null)
                fact(Icons.schedule, 'Checked ${_when(checks.checkedAt!)}',
                    color: Ob.inkMuted),
            ],
            const SizedBox(height: 16),
            if (decide != null)
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => decide(c, PursuitDisposition.pursuing),
                    child: Text(busy ? 'Saving…' : 'Pursue'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: busy ? null : () => decide(c, PursuitDisposition.holding),
                  child: const Text('Not now'),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

/// WHY IT COULD NOT BE LOADED, WHICH IS NOT ONE SITUATION.
///
/// This said "we could not read it right now" whatever had happened, and threw
/// away an exception that already knew the status code, the message and the
/// request id. Four different faults with four different owners read
/// identically: a session that ended, a network that could not be reached, an
/// error on our side, and an answer that arrived intact and could not be
/// parsed. Only one of them is fixed by pressing Try again, and nobody looking
/// at the screen could tell which one they had.
///
/// What it keeps: a failure is never rendered as an empty market. Zero
/// candidates would tell a business its pipeline had vanished, and that is a
/// worse lie than an unhelpful message.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  /// Platform-safe: naming SocketException directly would pull in dart:io,
  /// which does not exist on web, and this screen builds for both.
  bool get _isNetwork {
    final name = error.runtimeType.toString();
    return name.contains('SocketException')
        || name.contains('ClientException')
        || name.contains('HandshakeException')
        || name.contains('TimeoutException');
  }

  /// Did the answer arrive and fail to be understood?
  ///
  /// Only claimed when the error actually says so. Asserting it for anything
  /// unrecognised tells a business its app is out of date and sends them to
  /// update it, which is a confident answer to a question this screen did not
  /// have the evidence to answer.
  bool get _isUnreadable {
    final name = error.runtimeType.toString();
    return name.contains('FormatException')
        || name.contains('TypeError')
        || name.contains('CastError');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final api = error is ApiException ? error as ApiException : null;

    final String headline;
    final String detail;
    final String? reference;

    if (api != null && api.isAuthFailure) {
      headline = 'Your session has ended.';
      detail = 'Sign in again and your market will be here.';
      reference = null;
    } else if (_isNetwork) {
      headline = 'Orchestrate could not be reached.';
      detail = 'This looks like the connection rather than your data.';
      reference = null;
    } else if (api != null && api.statusCode >= 500) {
      headline = 'Orchestrate answered with an error.';
      // Named as ours, because it is. Telling a business to try again when the
      // fault is on this side wastes their time on a button that cannot help.
      detail = 'This is a fault on our side rather than anything about your '
          'business. Trying again may not help; the reference below identifies '
          'exactly what failed.';
      reference = api.displayId.isEmpty ? null : api.displayId;
    } else if (api != null) {
      headline = 'We could not load your market.';
      detail = api.message;
      reference = api.displayId.isEmpty ? null : api.displayId;
    } else if (_isUnreadable) {
      // The answer arrived and could not be read. A different fault with a
      // different owner: retrying fetches the same unreadable answer again.
      headline = 'Your market arrived but could not be read.';
      detail = 'The answer reached this device and did not have the shape this '
          'version expects, so nothing is being shown rather than something '
          'wrong. Updating the app is more likely to help than trying again.';
      reference = error.runtimeType.toString();
    } else {
      // Something went wrong that this screen cannot classify. Saying so is
      // the honest answer; naming a cause it cannot see would send a business
      // to fix the wrong thing.
      headline = 'We could not load your market.';
      detail = 'Something went wrong on the way to your market, and this '
          'screen cannot tell what. Trying again is worth doing first.';
      reference = error.runtimeType.toString();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(detail,
              style: text.bodySmall?.copyWith(color: Ob.inkMuted)),
          const SizedBox(height: 6),
          // SAID IN EVERY CASE, WHATEVER FAILED.
          //
          // A market that cannot be loaded and a market with nobody in it look
          // the same on a screen, and only one of them means the pipeline is
          // gone. This sentence is what separates them, so it cannot live
          // inside individual branches where a new branch quietly omits it —
          // which is exactly what happened when this screen learned to tell
          // faults apart.
          Text('Nothing has changed and nothing was lost.',
              style: text.bodySmall?.copyWith(color: Ob.inkMuted)),
          if (reference != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              reference,
              style: text.bodySmall?.copyWith(
                color: Ob.inkMuted,
                fontFamily: 'JetBrainsMono',
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
