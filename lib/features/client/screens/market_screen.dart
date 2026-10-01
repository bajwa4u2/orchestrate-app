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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MarketHeader(view: _market.view),
        const SizedBox(height: 22),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    final failure = _market.error;
    if (failure != null) {
      return _Unavailable(error: failure, onRetry: () => _market.refresh());
    }
    final view = _market.view;
    if (view == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

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
      //
      // This said "Business is where that is set" and offered no way there.
      // Worse, nothing on Business could set it: intent was read only from a
      // table no customer-facing screen writes. The server now reads the
      // offer from Business identity's "Offer / service description", and the
      // button goes to that field's screen.
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
      // Geography is the market setup records, so setup is where it is set.
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
      //
      // Discovery requires an active plan. Without one the sweep is refused
      // and records nothing, so the branches below would say "Discovery is
      // paused" or, once a profile exists, "Searching your market" — forever,
      // about a search that is not happening. The commercial authority's own
      // reason and resolution are shown instead, with the way to act on them.
      if (ClientCapabilities.instance
              .refusalFor(Capabilities.researchCounterparties) !=
          null) {
        return ListView(
          padding: EdgeInsets.zero,
          children: const [
            QuietState(message: 'Your market is not being searched.'),
            CommercialBoundary(capability: Capabilities.researchCounterparties),
          ],
        );
      }

      if (view.excludedWithoutIdentity > 0 || view.excludedArtifacts > 0) {
        return QuietState(
          message: 'Nothing found so far could be shown as a company.',
          hint: view.excludedNote ?? '',
        );
      }

      if (!coverage.discovering) {
        return const QuietState(
          message: 'Discovery is paused for your market.',
          hint: 'Nothing is being looked for right now.',
        );
      }

      if (!coverage.hasSearched) {
        return const QuietState(
          message: 'Searching your market.',
          hint: 'Businesses appear here as they are found.',
        );
      }

      // Searched, and genuinely nothing yet. Bounded by what was covered, so
      // it never claims more than it checked.
      return QuietState(
        message: 'No businesses matching your market found yet.',
        hint: coverage.areasKnown > 0
            ? '${coverage.areasChecked} of ${coverage.areasKnown} areas in '
                'your market have been checked so far. Discovery continues.'
            : 'Discovery continues.',
      );
    }

    final review = view.needsReview;
    final decided = view.decided;
    final quiet = view.notEnoughKnown;
    final related = view.alreadyRelated;

    // DD-26 (board S09): cards a person can decide on where they stand. The
    // order is the server's; nothing here re-ranks. Built in full rather than
    // lazily: what was set aside must be on the page, not only on a scroll.
    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view.coverage.note != null && view.coverage.discovering)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(view.coverage.note!,
                style: Ob.body(13.5, color: Ob.inkMuted)),
          ),
        if (_decisionFailure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(_decisionFailure!,
                style: Ob.body(14, color: Ob.refused)),
          ),
        if (review.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: ObCard(
              child: Text(
                  'Nothing new needs your judgement. New businesses appear '
                  'here as Orchestrate finds them.',
                  style: Ob.body(15, color: Ob.ink)),
            ),
          )
        else ...[
          const _Section('Worth a look', first: true),
          _Grid(children: [
            for (final c in review)
              _CandidateCard(
                candidate: c,
                busy: _deciding.contains(c.key),
                onOpen: _open,
                onDecide: _decide,
              ),
          ]),
        ],
        if (decided.isNotEmpty) ...[
          const _Section('You have decided'),
          _Grid(children: [
            for (final c in decided)
              _CandidateCard(candidate: c, busy: false, onOpen: _open),
          ]),
        ],
        if (related.isNotEmpty) ...[
          const _Section('Already your customers'),
          _Grid(children: [
            for (final c in related)
              _CandidateCard(candidate: c, busy: false, onOpen: _open),
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
            _Grid(children: [
              for (final c in quiet)
                _CandidateCard(candidate: c, busy: false, onOpen: _open),
            ]),
        ],
        if (view.excludedNote != null &&
            (view.excludedWithoutIdentity + view.excludedArtifacts) > 0) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Ob.ink,
              borderRadius: BorderRadius.circular(Ob.radiusCard),
            ),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 18, color: Ob.onInkMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${view.excludedWithoutIdentity + view.excludedArtifacts} set aside',
                            style: Ob.body(16,
                                color: Ob.onInk, weight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(view.excludedNote!,
                            style: Ob.body(14, color: Ob.onInkMuted)),
                      ],
                    ),
                  ),
                ]),
          ),
        ],
        const SizedBox(height: 24),
      ],
      ),
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

/// "Businesses that need you", what the business sells, and the counts the
/// server gave. Counts are the server's, never recomputed here.
class _MarketHeader extends StatelessWidget {
  const _MarketHeader({required this.view});
  final MarketView? view;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final phone =
        Workspace.sizeOf(context, MediaQuery.sizeOf(context).width).isPhone;
    Widget tile(String n, String label, {bool dark = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: dark ? Ob.ink : Ob.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n, style: Ob.figure(24, color: dark ? Ob.onInk : Ob.ink)),
            Text(label,
                style: Ob.body(12, color: dark ? Ob.onInkMuted : Ob.inkMuted)),
          ]),
        );
    final tiles = v != null && v.counts.total > 0
        ? Wrap(spacing: 10, runSpacing: 10, children: [
            tile('${v.counts.total}', 'found'),
            tile('${v.counts.needsReview}', 'worth a look'),
            tile('${v.counts.pursuing}', 'pursuing', dark: true),
          ])
        : null;
    final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ObHeadline('Businesses that need you', size: phone ? 32 : 44),
              if (v?.intent != null) ...[
                const SizedBox(height: 6),
                Text(v!.intent!.says, style: Ob.body(15, color: Ob.inkSoft)),
                if (v.intent!.triggers.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                      'We watch for: '
                      '${v.intent!.triggers.join(', ').toLowerCase()}.',
                      style: Ob.body(13.5, color: Ob.inkMuted)),
                ],
              ],
            ],
          );
    return LayoutBuilder(builder: (context, c) {
      if (tiles == null) return title;
      if (c.maxWidth < 900) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          title,
          const SizedBox(height: 14),
          tiles,
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: title),
        const SizedBox(width: 24),
        tiles,
      ]);
    });
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.first = false});
  final String title;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 26, bottom: 12),
        child: Text(title, style: Ob.name(21)),
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

/// One business, on a card: who, why now, where, and the owner's decision.
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
    final reason = switch (c.certainty) {
      Certainty.evidenced ||
      Certainty.thin =>
        c.whyItMatters ?? c.certaintyMeans,
      Certainty.stale || Certainty.insufficient => c.certaintyMeans,
    };
    // Never green: green is money. Certainty is said as a word.
    final pill = c.hasRelationship
        ? const ObPill('Customer', tone: PillTone.ink)
        : ObPill(c.certainty.label,
            tone: c.certainty == Certainty.evidenced
                ? PillTone.ink
                : PillTone.plain);
    final where = [
      if ((c.geography ?? '').isNotEmpty) c.geography!,
      if (c.domain.isNotEmpty) c.domain,
    ].join(' · ');
    final decide = onDecide;
    return InkWell(
      onTap: () => onOpen(c),
      borderRadius: BorderRadius.circular(Ob.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Ob.card,
          borderRadius: BorderRadius.circular(Ob.radiusCard),
          boxShadow: decide != null ? Ob.lift : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(c.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ob.name(20)),
              ),
              const SizedBox(width: 8),
              pill,
            ]),
            const SizedBox(height: 10),
            Text(reason,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Ob.body(14)),
            if (where.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(where, style: Ob.body(13, color: Ob.inkMuted)),
            ],
            const SizedBox(height: 14),
            if (decide != null)
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () => decide(c, PursuitDisposition.pursuing),
                    child: Text(busy ? 'Saving…' : 'Yes, pursue'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed:
                      busy ? null : () => decide(c, PursuitDisposition.holding),
                  child: const Text('Not now'),
                ),
              ])
            else if (c.hasRelationship && c.relationshipId != null)
              OutlinedButton(
                onPressed: () =>
                    context.go('/client/relationships/${c.relationshipId}'),
                child: const Text('Open customer'),
              )
            else
              Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Ob.paper,
                  borderRadius: BorderRadius.circular(Ob.radiusControl),
                ),
                child: Text(c.disposition.label,
                    style: Ob.strong(14, color: Ob.inkSoft)),
              ),
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
