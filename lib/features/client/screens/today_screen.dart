import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/attention/client_attention.dart';
import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/auth/return_path.dart';
import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/market/client_market.dart';
import 'package:orchestrate_app/core/readiness/owner_readiness.dart';
import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/core/today/client_today.dart';
import 'package:orchestrate_app/core/today/yes_count.dart';
import 'package:orchestrate_app/core/ui/ob_widgets.dart';
import 'package:orchestrate_app/data/repositories/client/client_attention_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_authority_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_money_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_today_repository.dart';

/// TODAY (DD-26, board S07): "N things need your yes."
///
/// The one question an owner opens Orchestrate to answer is what is waiting
/// for them. So Today leads with exactly that, as cards they can act on where
/// they stand, and everything that is moving without them sits below, quieter.
///
/// Stage 1 builds the yes-cards from what the server already knows:
///   * businesses found in the market that nobody has decided on yet,
///   * readiness items that only the owner can resolve,
///   * work waiting on the owner (mail to place, companies to reach).
/// Stage 2 adds drafts (first notes, proposals, invoices) from a server queue.
///
/// Nothing here is counted or phrased locally beyond joining those answers.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

/// One thing waiting for the owner's yes, whatever its source.
class _YesCard {
  const _YesCard({
    this.done = false,
    required this.name,
    required this.ask,
    this.detail,
    this.reached,
    this.eyebrow,
    this.figure,
    this.primaryIsMoney = false,
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.onSecondary,
  });

  /// One of the four owner steps, already done: shown quietly, no button.
  final bool done;
  final String name;
  final String ask;
  final String? detail;

  /// Position on the path to paid; null when this is not about a customer.
  final int? reached;
  final String? eyebrow;

  /// An amount, shown green because it is money.
  final String? figure;

  /// An invoice's approval is a money act, and its button says so in green.
  final bool primaryIsMoney;
  final String primary;
  final VoidCallback onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
}

class _TodayScreenState extends State<TodayScreen> {
  final ClientToday _today = ClientToday.instance;
  final ClientAttention _attention = ClientAttention.instance;
  final ClientMarket _market = ClientMarket.instance;
  final _money = ClientMoneyRepository();
  final _authority = ClientAuthorityRepository();
  List<WaitingDecision> _waiting = const [];
  MoneyView? _moneyView;
  bool _moneyKnown = false;
  final Set<String> _deciding = {};
  String? _decisionFailure;

  @override
  void initState() {
    super.initState();
    _today.addListener(_changed);
    _attention.addListener(_changed);
    _market.addListener(_changed);
    // Paint what is known, and ask again underneath: returning to Today
    // must never show yesterday's answer as today's. A load already in flight
    // is not started twice.
    if (!_today.isLoading) {
      _load();
    }
  }

  @override
  void dispose() {
    _today.removeListener(_changed);
    _attention.removeListener(_changed);
    _market.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await Future.wait<void>([
      _today.refresh().then((_) {}).catchError((_) {}),
      _attention.refresh().then((_) {}).catchError((_) {}),
      _market.refresh().then((_) {}).catchError((_) {}),
      _authority.waiting().then((w) {
        _waiting = w;
      }).catchError((_) {}),
      _money.fetch().then((m) {
        _moneyView = m;
        _moneyKnown = true;
      }).catchError((_) {
        _moneyKnown = false;
      }),
    ]);
    if (mounted) setState(() {});
  }

  /// A decision on an agreement or invoice that stopped at the owner's limit.
  Future<void> _decideWaiting(WaitingDecision w, bool approve) async {
    setState(() {
      _deciding.add(w.id);
      _decisionFailure = null;
    });
    try {
      final result = await _authority.decide(w.id, approve: approve);
      if (!mounted) return;
      final says = (result['message'] ?? result['reason'] ?? '').toString();
      if (result['ok'] == true) {
        setState(() => _waiting = _waiting.where((x) => x.id != w.id).toList());
        if (says.isNotEmpty) {
          ScaffoldMessenger.maybeOf(context)
              ?.showSnackBar(SnackBar(content: Text(says)));
        }
      } else {
        setState(() => _decisionFailure =
            says.isEmpty ? 'That decision was not recorded.' : says);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _decisionFailure =
            'Your decision could not be recorded just now. Try again in a moment.');
      }
    } finally {
      if (mounted) setState(() => _deciding.remove(w.id));
    }
  }

  Future<void> _decide(Candidate c, PursuitDisposition d) async {
    setState(() {
      _deciding.add(c.key);
      _decisionFailure = null;
    });
    try {
      final result = await _market.setPursuit(key: c.key, disposition: d);
      if (result['ok'] != true && mounted) {
        setState(() => _decisionFailure =
            (result['says'] ?? result['message'] ?? 'That decision was not recorded.')
                .toString());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _decisionFailure =
            'Your decision on ${c.name} could not be recorded just now. Try again in a moment.');
      }
    } finally {
      if (mounted) setState(() => _deciding.remove(c.key));
    }
  }

  List<_YesCard> _cards() {
    final cards = <_YesCard>[];
    final session = AuthSessionController.instance;
    // Agreements and invoices waiting at the owner's limit come first: they
    // are the decisions closest to money.
    for (final w in _waiting) {
      final busy = _deciding.contains(w.id);
      final named = (w.counterparty ?? '').trim().isNotEmpty;
      cards.add(_YesCard(
        name: named ? w.counterparty! : w.whatIsWaiting,
        // Where it sits on the path: a first note is the Wrote step, a
        // proposal is Agree, an invoice is Invoice.
        reached: w.isNote ? 1 : w.isAgreement ? 3 : w.isInvoice ? 4 : null,
        eyebrow: 'WAITING FOR YOUR YES',
        figure: w.valueCents == null
            ? null
            : moneyLabel(w.valueCents!, currencyCode: w.currencyCode ?? 'USD'),
        ask: !w.youCanDecide
            ? w.whoCanDecide
            : w.isNote
                ? 'Send this first note?'
                : w.isAgreement
                    ? 'Send the proposal?'
                    : w.isInvoice
                        ? 'Send the invoice?'
                        : named
                            ? w.whatIsWaiting
                            : 'Approve just this one?',
        detail: w.isNote && (w.draftSubject ?? '').isNotEmpty
            ? '"${w.draftSubject}"  ${w.draftBody ?? ''}'
            : w.whyItStopped,
        primaryIsMoney: w.isInvoice && w.youCanDecide,
        primary: !w.youCanDecide
            ? 'Who can decide'
            : busy
                ? 'Saving…'
                : w.isNote
                    ? 'Approve and send'
                    : w.isInvoice
                        ? 'Approve and invoice'
                        : 'Approve',
        onPrimary: !w.youCanDecide
            ? () => context.go('/account/people')
            : busy
                ? () {}
                : () => _decideWaiting(w, true),
        secondary: w.youCanDecide ? 'Hold' : null,
        onSecondary:
            w.youCanDecide && !busy ? () => _decideWaiting(w, false) : null,
      ));
    }
    if (!session.hasSetupCompleted) {
      cards.add(_YesCard(
        name: 'Finish getting ready',
        ask: '',
        detail: 'Everything you typed is kept. Nothing is sent while you set up.',
        primary: 'Continue',
        onPrimary: () => context.go('/client/setup'),
      ));
    }
    // The four things only the owner can do, each still open one a card.
    // All four stay in view until all four are done, so the owner sees how
    // far they are; a done one is quiet and has no button.
    final steps = session.hasSetupCompleted
        ? ownerStepsFrom(_today.state?.eligibility)
        : const <OwnerStep>[];
    final allDone = steps.every((s) => s.done);
    for (final step in allDone ? const <OwnerStep>[] : steps) {
      cards.add(_YesCard(
        done: step.done,
        name: step.title,
        ask: '',
        detail: step.line,
        primary: step.cta,
        onPrimary: () => context.go(step.route),
      ));
    }
    for (final item in _today.state?.needsYou ?? const <TodayItem>[]) {
      // Already a card above, in fewer words.
      if (ownerStepBlockerCodes.contains(item.code)) continue;
      final meeting = item.category == 'meeting';
      cards.add(_YesCard(
        name: item.title,
        ask: '',
        detail: meeting && item.meta != null ? item.meta : item.detail,
        primary: meeting
            ? 'Open'
            : (item.cta ?? '').isEmpty
                ? 'Open'
                : item.cta!,
        onPrimary: () => context.go(meeting
            ? '/client/relationships'
            : setupRouteFor(item.route)),
      ));
    }
    for (final c in _market.view?.needsReview ?? const <Candidate>[]) {
      final busy = _deciding.contains(c.key);
      cards.add(_YesCard(
        name: c.name,
        reached: 1,
        ask: 'Worth writing to?',
        detail: c.whyItMatters ?? c.certaintyMeans,
        primary: busy ? 'Saving…' : 'Yes, pursue',
        onPrimary: busy ? () {} : () => _decide(c, PursuitDisposition.pursuing),
        secondary: 'Not now',
        onSecondary: busy ? null : () => _decide(c, PursuitDisposition.holding),
      ));
    }
    final owed = _attention.needsYou;
    final contactWork = owed.where((i) => i.isAboutContact).toList();
    final inbound = owed.where((i) => !i.isAboutContact).toList();
    if (contactWork.isNotEmpty) {
      cards.add(_YesCard(
        name: contactWork.length == 1
            ? (contactWork.first.counterparty ?? 'A company you chose')
            : '${contactWork.length} companies you chose',
        reached: 1,
        ask: contactWork.length == 1
            ? contactWork.first.title
            : 'Cannot be reached yet',
        detail: contactWork.length == 1
            ? contactWork.first.why
            : 'Orchestrate does not yet have a contact it can responsibly use for them.',
        primary: 'Look',
        onPrimary: () => context.go('/client/inbound'),
      ));
    }
    if (inbound.isNotEmpty) {
      cards.add(_YesCard(
        name: 'Your inbox',
        eyebrow: 'TO PLACE',
        ask: inbound.length == 1
            ? 'A message arrived that we could not place'
            : '${inbound.length} messages arrived that we could not place',
        detail: inbound.first.why,
        primary: 'Look',
        onPrimary: () => context.go('/client/inbound'),
      ));
    }
    return cards;
  }

  static const _words = [
    'Nothing', 'One thing', 'Two things', 'Three things', 'Four things',
    'Five things', 'Six things', 'Seven things', 'Eight things',
    'Nine things', 'Ten things'
  ];

  @override
  Widget build(BuildContext context) {
    final loading = _today.isLoading && !_today.hasAnswer;
    final cards = _cards();
    // Published for the rail's amber count beside Today.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_today.hasAnswer) {
        todayYesCount.value = cards.where((c) => !c.done).length;
      }
    });
    // A done owner step is on screen but is not something that needs a yes.
    final n = cards.where((c) => !c.done).length;
    final shownCount = cards.length;
    final lead = n < _words.length ? _words[n] : '$n things';
    final now = DateTime.now();
    final phone = Workspace.sizeOf(context, MediaQuery.sizeOf(context).width).isPhone;

    return RefreshIndicator(
      color: Ob.ink,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_dateLine(now), style: Ob.body(14, color: Ob.inkMuted)),
                  const SizedBox(height: 6),
                  loading
                      ? ObHeadline('Today', size: phone ? 34 : 44)
                      : n == 0
                          ? ObHeadline('Nothing needs your yes.', size: phone ? 34 : 44)
                          : ObHeadline('$lead ${n == 1 ? 'needs' : 'need'} your ',
                              accent: 'yes.', size: phone ? 34 : 44),
                ],
              ),
              if ((_today.state?.inFlight ?? const []).isNotEmpty)
                Text('Everything else is moving on its own.',
                    style: Ob.body(14, color: Ob.inkMuted)),
            ],
          ),
          if (_today.state?.incompleteBecause != null) ...[
            const SizedBox(height: 12),
            Text(_today.state!.incompleteBecause!,
                style: Ob.body(13.5, color: Ob.inkMuted)),
          ],
          if (_decisionFailure != null) ...[
            const SizedBox(height: 12),
            Text(_decisionFailure!, style: Ob.body(14, color: Ob.refused)),
          ],
          const SizedBox(height: 24),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                  child: CircularProgressIndicator(color: Ob.ink, strokeWidth: 2)),
            )
          else if (shownCount == 0)
            _quiet(_today.state)
          else
            LayoutBuilder(builder: (context, c) {
              var cols = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
              // Four cards fill two rows of two (or one row of four), never
              // three and one left alone.
              if (cols == 3 && shownCount == 4) cols = c.maxWidth >= 1240 ? 4 : 2;
              final shown = cards.take(cols == 1 ? 6 : (cols == 4 ? 4 : cols * 2)).toList();
              // Cards in a row share one height, so their buttons line up.
              return Column(children: [
                for (var r = 0; r < shown.length; r += cols) ...[
                  if (r > 0) const SizedBox(height: 18),
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (var i = r; i < r + cols; i++) ...[
                        if (i > r) const SizedBox(width: 18),
                        Expanded(
                          child: i < shown.length
                              ? _Card(card: shown[i])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ]),
                  ),
                ],
              ]);
            }),
          if (n > 6) ...[
            const SizedBox(height: 12),
            Text('${n - 6} more waiting. Decide on these first and the rest '
                'move up.',
                style: Ob.body(14, color: Ob.inkMuted)),
          ],
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, c) {
            final moving = _MovingPanel(state: _today.state);
            final month = _MonthPanel(view: _moneyView, known: _moneyKnown);
            if (c.maxWidth < 760) {
              return Column(children: [moving, const SizedBox(height: 18), month]);
            }
            return IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 2, child: moving),
                const SizedBox(width: 18),
                Expanded(child: month),
              ]),
            );
          }),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  /// Said on a true answer only: null and false both fall through to the
  /// plain quiet state, because an unknown is not "ready".
  Widget _quiet(TodayState? s) {
    if (s != null && s.executionReady == true) {
      return const QuietState(
        message: 'Your setup is complete.',
        hint: 'New businesses appear in Market as Orchestrate finds them; '
            'anything that needs your decision will wait here.',
      );
    }
    return const QuietState(
      message: 'Nothing is waiting for you.',
      hint: 'Anything that needs your decision will appear here.',
    );
  }

  static String _dateLine(DateTime d) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year} · '
        '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.card});
  final _YesCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Ob.radiusPanel),
        color: card.done ? Ob.paper : Ob.card,
        border: card.done ? Border.all(color: Ob.line) : null,
        boxShadow: card.done ? null : Ob.liftLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(card.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ob.name(21)),
            ),
            if (card.figure != null) ...[
              const SizedBox(width: 10),
              MoneyText(card.figure!),
            ],
          ]),
          if (card.reached != null) ...[
            const SizedBox(height: 14),
            PathBar(reached: card.reached!, waitingOnYes: true),
          ] else if (card.eyebrow != null) ...[
            const SizedBox(height: 14),
            Text(card.eyebrow!, style: Ob.eyebrow(color: Ob.yesDeep)),
          ],
          if (card.ask.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(card.ask, style: Ob.strong(15)),
          ],
          if ((card.detail ?? '').isNotEmpty) ...[
            SizedBox(height: card.ask.isEmpty ? 8 : 6),
            Text(card.detail!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Ob.body(14.5)),
          ],
          const SizedBox(height: 18),
          const Spacer(),
          if (card.done)
            Row(children: [
              const Icon(Icons.check_circle, size: 20, color: Ob.ink),
              const SizedBox(width: 8),
              Text('Done', style: Ob.strong(14.5)),
            ])
          else
          Row(children: [
            Expanded(
              child: FilledButton(
                style: card.primaryIsMoney
                    ? FilledButton.styleFrom(backgroundColor: Ob.money)
                    : null,
                onPressed: card.onPrimary,
                child: Text(card.primary, overflow: TextOverflow.ellipsis),
              ),
            ),
            if (card.secondary != null) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: card.onSecondary,
                child: Text(card.secondary!),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

class _MovingPanel extends StatelessWidget {
  const _MovingPanel({required this.state});
  final TodayState? state;

  @override
  Widget build(BuildContext context) {
    final items = [
      ...?state?.inFlight,
      ...?state?.changed,
    ].take(6).toList();
    return ObCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Moving on its own', style: Ob.strong(14, color: Ob.inkSoft)),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
                state?.changedButNotRecently == true
                    ? 'Nothing has changed in the last few days. Earlier activity '
                        'is on the customers it belongs to.'
                    : 'Nothing is in motion yet. Work Orchestrate does for you '
                        'will show here as it happens.',
                style: Ob.body(14))
          else
            for (final item in items)
              InkWell(
                onTap: () => context.go(
                    withReturnTo('/client/relationships', '/client/today')),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: item.title, style: Ob.strong(14)),
                          if ((item.detail ?? '').isNotEmpty)
                            TextSpan(text: '  ${item.detail}', style: Ob.body(14)),
                        ])),
                      ),
                      if ((item.meta ?? '').isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(item.meta!, style: Ob.body(13, color: Ob.inkMuted)),
                      ],
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _MonthPanel extends StatelessWidget {
  const _MonthPanel({required this.view, required this.known});
  final MoneyView? view;
  final bool known;

  @override
  Widget build(BuildContext context) {
    final t = view?.totals;
    final cc = view?.currencyCode ?? 'USD';
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: Ob.ink,
        borderRadius: BorderRadius.circular(Ob.radiusPanel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This month', style: Ob.body(14, color: Ob.onInkMuted)),
          const SizedBox(height: 10),
          if (t == null || t.isEmpty)
            Text(
                known || view != null
                    ? 'No money has moved yet. When a customer agrees and pays, '
                        'it shows here.'
                    : 'Money appears here as customers agree and pay.',
                style: Ob.body(14.5, color: Ob.onInk))
          else ...[
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(moneyLabel(t.paidThisMonthCents, currencyCode: cc),
                      style: Ob.figure(36, color: Ob.moneyOnInk)),
                ),
              ),
              const SizedBox(width: 8),
              Text('paid', style: Ob.body(14, color: Ob.onInkMuted)),
            ]),
            const SizedBox(height: 8),
            if (t.invoicedDueCents > 0)
              _line(moneyLabel(t.invoicedDueCents, currencyCode: cc), 'invoiced, due'),
            if (t.proposedCount > 0)
              _line('${t.proposedCount}',
                  t.proposedCount == 1 ? 'proposal waiting' : 'proposals waiting'),
          ],
          const SizedBox(height: 14),
          InkWell(
            onTap: () => context.go('/client/money'),
            child: Text('Open Money',
                style: Ob.body(14, color: Ob.moneyOnInk, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _line(String figure, String label) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(figure, style: Ob.figure(22, color: Ob.onInk)),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: Ob.body(14, color: Ob.onInkMuted))),
        ]),
      );
}
