import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/commercial/commercial_model.dart';
import '../../../core/theme/ob.dart';
import '../../../core/ui/ob_widgets.dart';
import '../../../data/repositories/client/client_money_repository.dart'
    show moneyLabel;
import '../../../data/repositories/public_repository.dart';

/// DIRECTION B, PUBLIC (DD-26, boards S01–S04).
///
/// Three pages, one argument: Orchestrate carries a customer from being found
/// to being paid, and the owner only says yes. Every number on these pages is
/// either live from the server (`/public/lifecycle`, `/public/overview`,
/// `/public/pricing`) or inside a card labelled as an example. None is typed
/// here as a fact.

/// Live public numbers, read once per page.
class PublicLive {
  PublicLive({this.lifecycle = const {}, this.overview = const {}, this.pricing});

  final Map<String, dynamic> lifecycle;
  final Map<String, dynamic> overview;
  final CommercialModel? pricing;
  final DateTime readAt = DateTime.now();

  int? n(String key) {
    final v = lifecycle[key] ?? overview[key];
    return v is num ? v.toInt() : null;
  }

  String? get monthly => pricing?.offerFor('MONTHLY')?.priceLabel;
  String? get annual => pricing?.offerFor('ANNUAL')?.priceLabel;

  static Future<PublicLive> load() async {
    final repo = PublicRepository();
    final r = await Future.wait<dynamic>([
      repo.fetchLifecycle().catchError((_) => <String, dynamic>{}),
      repo.fetchOverview().catchError((_) => <String, dynamic>{}),
      repo
          .fetchPricing()
          .then<CommercialModel?>((m) => m)
          .catchError((_) => null),
    ]);
    return PublicLive(
      lifecycle: Map<String, dynamic>.from(r[0] as Map),
      overview: Map<String, dynamic>.from(r[1] as Map),
      pricing: r[2] as CommercialModel?,
    );
  }
}

/// Loads [PublicLive] and hands it to [builder]; renders without it while it
/// arrives, because nothing on these pages may wait on a number to be read.
class PublicLiveBuilder extends StatefulWidget {
  const PublicLiveBuilder({super.key, required this.builder});
  final Widget Function(BuildContext, PublicLive?) builder;

  @override
  State<PublicLiveBuilder> createState() => _PublicLiveBuilderState();
}

class _PublicLiveBuilderState extends State<PublicLiveBuilder> {
  static PublicLive? _cache;
  PublicLive? _live = _cache;

  @override
  void initState() {
    super.initState();
    PublicLive.load().then((v) {
      _cache = v;
      if (mounted) setState(() => _live = v);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _live);
}

String _clock(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${m[d.month - 1]} ${d.day}, ${d.year} · $h:${d.minute.toString().padLeft(2, '0')} '
      '${d.hour < 12 ? 'AM' : 'PM'}';
}

/// The example amount used on every public board. An illustration, labelled
/// as one wherever it appears; formatted rather than typed so it can never
/// be mistaken for a price.
final String exampleProposal = moneyLabel(480000);

// ── Front door (S01, S02) ────────────────────────────────────────────

class FrontDoorScreen extends StatelessWidget {
  const FrontDoorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicLiveBuilder(builder: (context, live) {
      return LayoutBuilder(builder: (context, c) {
        final phone = c.maxWidth < 760;
        final wide = c.maxWidth >= 1040;
        final hero = _Hero(live: live, phone: phone);
        final stage = _Stage(live: live, phone: phone);
        return Padding(
          padding: EdgeInsets.symmetric(vertical: phone ? 28 : 56),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(flex: 11, child: hero),
                  const SizedBox(width: 56),
                  Expanded(flex: 10, child: stage),
                ])
              else ...[
                hero,
                const SizedBox(height: 32),
                stage,
              ],
              const SizedBox(height: 44),
              _LiveStrip(live: live, phone: phone),
            ],
          ),
        );
      });
    });
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.live, required this.phone});
  final PublicLive? live;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final monthly = live?.monthly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FROM FIRST MESSAGE TO PAID INVOICE', style: Ob.eyebrow()),
        const SizedBox(height: 18),
        ObHeadline('New customers, followed through to ',
            accent: 'paid.', accentColor: Ob.money, size: phone ? 40 : 64),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
              phone
                  ? 'Found, written to from your own email, carried to an '
                      'agreement and a paid invoice. You only say yes.'
                  : 'Orchestrate finds businesses that need you, writes to them '
                      'from your own email, and moves each one to an agreement '
                      'and a paid invoice. It prepares every step. You only say yes.',
              style: Ob.body(phone ? 17 : 19)),
        ),
        const SizedBox(height: 26),
        Wrap(spacing: 12, runSpacing: 10, children: [
          FilledButton(
            onPressed: () => context.go('/auth/register'),
            child: const Text('Start with your business'),
          ),
          OutlinedButton(
            onPressed: () => context.go('/how-it-works'),
            child: const Text('See one customer, start to paid'),
          ),
        ]),
        if (monthly != null) ...[
          const SizedBox(height: 16),
          Text(
              'From $monthly a month for your whole business, the '
              'early-onboarding price · cancel any time',
              style: Ob.body(14, color: Ob.inkMuted)),
        ],
      ],
    );
  }
}

/// The layered stage: an example customer waiting for a yes, and what was
/// held back, live. The tilt belongs to the front door alone.
class _Stage extends StatelessWidget {
  const _Stage({required this.live, required this.phone});
  final PublicLive? live;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final held = live?.n('suppressed');
    final card = Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Ob.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Ob.liftHigh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('EXAMPLE CUSTOMER', style: Ob.eyebrow()),
                const SizedBox(height: 6),
                Text('Kestrel Surveying', style: Ob.name(24)),
              ]),
            ),
            const ObPill('Waiting for your yes', tone: PillTone.yes),
          ]),
          const SizedBox(height: 18),
          const PathBar(reached: 3, waitingOnYes: true, height: 8, showLabels: true),
          const SizedBox(height: 18),
          Text('Orchestrate prepared', style: Ob.body(13, color: Ob.inkMuted)),
          const SizedBox(height: 4),
          Text('Send the survey proposal: $exampleProposal, start October 14',
              style: Ob.strong(16)),
          const SizedBox(height: 6),
          Text(
              'From the call on Tuesday. It goes from your own address the '
              'moment you approve, and the invoice follows the signature.',
              style: Ob.body(14)),
          const SizedBox(height: 16),
          // Drawn as the real buttons look, but inert: this is an example.
          IgnorePointer(
            child: ExcludeSemantics(
              child: Row(children: [
                Expanded(
                  child: FilledButton(
                      onPressed: () {}, child: const Text('Approve and send')),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () {}, child: const Text('Edit first')),
              ]),
            ),
          ),
        ],
      ),
    );
    final heldCard = held == null
        ? null
        : Container(
            width: 220,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Ob.ink,
              borderRadius: BorderRadius.circular(18),
              boxShadow: Ob.lift,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('HELD BACK', style: Ob.eyebrow(color: Ob.onInkMuted)),
              const SizedBox(height: 6),
              Text('$held', style: Ob.figure(34, color: Ob.onInk)),
              const SizedBox(height: 4),
              Text('sends stopped before they could hurt a reputation',
                  style: Ob.body(13, color: Ob.onInkMuted)),
            ]),
          );
    if (phone) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        card,
        if (heldCard != null) ...[const SizedBox(height: 14), heldCard],
      ]);
    }
    return Semantics(
      label: 'Example: a customer waiting for your yes',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40, right: 12),
        child: Stack(clipBehavior: Clip.none, children: [
          Transform.rotate(angle: -1.5 * math.pi / 180, child: card),
          if (heldCard != null)
            Positioned(
              right: -12,
              bottom: -52,
              child: Transform.rotate(angle: 2 * math.pi / 180, child: heldCard),
            ),
        ]),
      ),
    );
  }
}

class _LiveStrip extends StatelessWidget {
  const _LiveStrip({required this.live, required this.phone});
  final PublicLive? live;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final l = live;
    if (l == null || l.n('leads') == null) return const SizedBox.shrink();
    final cells = <(String, String)>[
      ('${l.n('leads')}', 'businesses found'),
      ('${l.n('opportunities') ?? 0}', 'qualified'),
      ('${l.n('dispatch') ?? 0}', "sent from owners' email"),
      ('${l.n('replies') ?? 0}', 'replies'),
      ('${l.n('meetings') ?? 0}', 'meetings handed off'),
      ('${l.n('invoices') ?? 0}', 'invoiced so far'),
    ];
    final enquiries = l.n('inquiriesReceived');
    final liveCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  const BoxDecoration(color: Ob.ink, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('Live', style: Ob.strong(13)),
        ]),
        const SizedBox(height: 4),
        Text(
            '${_clock(l.readAt)}${enquiries == null ? '' : '\n$enquiries enquiries received'}',
            style: Ob.body(12, color: Ob.inkMuted)),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Ob.card,
        borderRadius: BorderRadius.circular(Ob.radiusPanel),
      ),
      child: Wrap(
        spacing: phone ? 22 : 40,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (v, label) in cells)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v, style: Ob.figure(phone ? 24 : 30)),
              Text(label, style: Ob.body(13, color: Ob.inkMuted)),
            ]),
          liveCell,
        ],
      ),
    );
  }
}

// ── One customer, start to paid (S03) ────────────────────────────────

class OneCustomerScreen extends StatelessWidget {
  const OneCustomerScreen({super.key});

  static final _steps = <(String, String, String, String, bool)>[
    ('DAY 1 · FOUND', 'A surveying firm that needs what you do',
        'Hiring a site manager, three new projects listed, 12 miles away. Fits the market you described.',
        'Orchestrate did this', false),
    ('DAY 2 · WROTE', 'A short note, from your own email',
        'Drafted for them, checked before it could leave. It went out from your address, as you.',
        'You said yes', true),
    ('DAY 5 · REPLIED', '"Can you do a call on Tuesday?"',
        'The reply was read, understood as interest, and a time was offered. The call landed in your calendar.',
        'Orchestrate did this', false),
    ('DAY 9 · AGREE', 'A proposal with the terms from the call',
        '$exampleProposal, start October 14. Signed by Kestrel on day 11. What was agreed stays in the record.',
        'You said yes', true),
    ('DAY 16 · INVOICE', 'Work delivered, invoice sent',
        'The invoice matched the agreement to the dollar. It went out when you confirmed the work was done.',
        'You said yes', true),
  ];

  @override
  Widget build(BuildContext context) {
    return PublicLiveBuilder(builder: (context, live) {
      return LayoutBuilder(builder: (context, c) {
        final phone = c.maxWidth < 760;
        final cols = c.maxWidth >= 1100 ? 3 : (c.maxWidth >= 700 ? 2 : 1);
        final w = (c.maxWidth - 16 * (cols - 1)) / cols;
        return Padding(
          padding: EdgeInsets.symmetric(vertical: phone ? 28 : 56),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ONE CUSTOMER, START TO PAID · EXAMPLE', style: Ob.eyebrow()),
              const SizedBox(height: 16),
              ObHeadline('How Kestrel Surveying became $exampleProposal ',
                  accent: 'paid.', accentColor: Ob.money, size: phone ? 36 : 56),
              const SizedBox(height: 14),
              Text(
                  'Six steps, nineteen days. Orchestrate did the work in each '
                  'one. The owner said yes three times.',
                  style: Ob.body(18)),
              const SizedBox(height: 32),
              Wrap(spacing: 16, runSpacing: 16, children: [
                for (var i = 0; i < _steps.length; i++)
                  SizedBox(width: w, child: _StepCard(step: _steps[i], reached: i + 1)),
                SizedBox(
                  width: w,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Ob.money,
                      borderRadius: BorderRadius.circular(Ob.radiusPanel),
                      boxShadow: const [
                        BoxShadow(color: Color(0x4715803D), blurRadius: 48, offset: Offset(0, 24)),
                      ],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('DAY 19 · PAID', style: Ob.eyebrow(color: Ob.moneySoft)),
                      const SizedBox(height: 10),
                      Text(exampleProposal, style: Ob.figure(40, color: Ob.card)),
                      const SizedBox(height: 10),
                      Text(
                          'Paid in full. Kestrel stays in your record for the '
                          'next job, with everything that was said and agreed.',
                          style: Ob.body(14.5, color: Ob.moneySoft)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 22),
              Text(
                  'An illustrated example. Each step shows what Orchestrate '
                  'does and where the owner decides.',
                  style: Ob.body(14, color: Ob.inkMuted)),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => context.go('/auth/register'),
                child: Text(live?.monthly == null
                    ? 'Start with your business'
                    : 'Start with your business · from ${live!.monthly} a month'),
              ),
            ],
          ),
        );
      });
    });
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.reached});
  final (String, String, String, String, bool) step;
  final int reached;

  @override
  Widget build(BuildContext context) {
    final (day, title, body, who, owner) = step;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Ob.card,
        borderRadius: BorderRadius.circular(Ob.radiusPanel),
        border: owner ? Border.all(color: Ob.yes, width: 2) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(day, style: Ob.eyebrow()),
        const SizedBox(height: 10),
        PathBar(reached: reached - (owner ? 1 : 0), waitingOnYes: owner),
        const SizedBox(height: 14),
        Text(title, style: Ob.name(19)),
        const SizedBox(height: 6),
        Text(body, style: Ob.body(14)),
        const SizedBox(height: 12),
        ObPill(who, tone: owner ? PillTone.yes : PillTone.plain),
      ]),
    );
  }
}

// ── Pricing (S04) ────────────────────────────────────────────────────

class PricingBScreen extends StatelessWidget {
  const PricingBScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicLiveBuilder(builder: (context, live) {
      return LayoutBuilder(builder: (context, c) {
        final phone = c.maxWidth < 760;
        final wide = c.maxWidth >= 1040;
        final monthly = live?.pricing?.offerFor('MONTHLY');
        final annual = live?.pricing?.offerFor('ANNUAL');
        String? perMonth;
        String? free;
        if (annual != null) {
          perMonth = CommercialOffer.fromJson(
                  {'amountUsdCents': (annual.amountUsdCents / 12).round()})
              .priceLabel
              .replaceAll('.00', '');
        }
        if (monthly != null && annual != null && monthly.amountUsdCents > 0) {
          final months = ((monthly.amountUsdCents * 12 - annual.amountUsdCents) /
                  monthly.amountUsdCents)
              .round();
          if (months == 1) free = 'One month free';
          if (months > 1) free = '${months == 2 ? 'Two' : months} months free';
        }
        Widget priceCard(String cadence, String? amount, String unit, String note,
                {bool dark = false, String? badge}) =>
            Container(
              width: phone ? double.infinity : 240,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: dark ? Ob.ink : Ob.card,
                borderRadius: BorderRadius.circular(Ob.radiusCard),
                boxShadow: dark ? Ob.liftHigh : Ob.lift,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(cadence,
                      style: Ob.body(13, color: dark ? Ob.onInkMuted : Ob.inkMuted)),
                  const Spacer(),
                  if (badge != null)
                    Text(badge,
                        style: Ob.body(13, color: Ob.moneyOnInk, weight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(amount ?? '—',
                          style: Ob.figure(40, color: dark ? Ob.onInk : Ob.ink)),
                      const SizedBox(width: 6),
                      Text(unit,
                          style: Ob.body(14, color: dark ? Ob.onInkMuted : Ob.inkMuted)),
                    ]),
                const SizedBox(height: 6),
                Text(note,
                    style: Ob.body(13, color: dark ? Ob.onInkMuted : Ob.inkMuted)),
              ]),
            );
        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PRICING', style: Ob.eyebrow()),
            const SizedBox(height: 16),
            ObHeadline('One price for your whole business. ',
                accent: 'Everyone included.',
                accentColor: Ob.money,
                size: phone ? 38 : 60),
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Text(
                  'No seats to count. Ordinary use is included; only unusually '
                  'heavy use costs more, counted in businesses researched and '
                  'messages sent. Setting up your workspace is free, so you see '
                  'what Orchestrate finds before you pay.',
                  style: Ob.body(18)),
            ),
            const SizedBox(height: 22),
            _earlyPrice(),
            const SizedBox(height: 16),
            Wrap(spacing: 14, runSpacing: 14, children: [
              priceCard('Monthly', monthly?.priceLabel, '/ month', 'Cancel any time'),
              priceCard('Yearly', annual?.priceLabel, '/ year',
                  perMonth == null ? 'Paid yearly' : '$perMonth a month, paid yearly',
                  dark: true, badge: free),
            ]),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => context.go('/auth/register'),
              child: const Text('Set up free, pay when you are ready'),
            ),
          ],
        );
        final right = Container(
          padding: const EdgeInsets.fromLTRB(34, 32, 34, 32),
          decoration: BoxDecoration(
            color: Ob.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: Ob.liftHigh,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                monthly == null
                    ? 'What it does for you each month'
                    : 'What ${monthly.priceLabel} does for you each month',
                style: Ob.name(26)),
            const SizedBox(height: 10),
            for (final (n, t, b) in const [
              ('01', 'Finds businesses that need you',
                  'In the market you describe, checked for fit before you see them.'),
              ('02', 'Writes to them from your own email',
                  'Your address, your domain, kept deliverable. Nothing leaves without your yes.'),
              ('03', 'Reads the replies and follows up',
                  'Interest becomes a meeting in your calendar. Silence gets a timely nudge.'),
              ('04', 'Turns the call into an agreement',
                  'A proposal with the terms you discussed, kept in the record once signed.'),
              ('05', 'Invoices and records payment',
                  'The invoice matches what was agreed. You see what is paid and what is due.'),
            ])
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Ob.line))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 40, child: Text(n, style: Ob.figure(14, color: Ob.inkMuted))),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t, style: Ob.strong(15.5)),
                      const SizedBox(height: 3),
                      Text(b, style: Ob.body(14)),
                    ]),
                  ),
                ]),
              ),
          ]),
        );
        return Padding(
          padding: EdgeInsets.symmetric(vertical: phone ? 28 : 56),
          child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: left),
                  const SizedBox(width: 64),
                  Expanded(child: right),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  left,
                  const SizedBox(height: 32),
                  right,
                ]),
        );
      });
    });
  }

  Widget _earlyPrice() => Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: Ob.ink,
              borderRadius: BorderRadius.circular(Ob.radiusPill),
            ),
            child: Text('EARLY-ONBOARDING PRICE',
                style: Ob.body(12, color: Ob.onInk, weight: FontWeight.w600)
                    .copyWith(letterSpacing: 0.4)),
          ),
          Text(
              'Starting prices for the first businesses to join. They will rise later.',
              style: Ob.body(14)),
        ],
      );
}
