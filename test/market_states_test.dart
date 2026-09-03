import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/market/client_market.dart';
import 'package:orchestrate_app/features/client/screens/market_screen.dart';

/// THE MARKET STATES, RENDERED AND READ.
///
/// Production holds 215 discovered rows, 88,568 qualification decisions and
/// 79,705 signals. None of those numbers is a product. What a business arrives
/// asking is who deserves attention now and why, so these render the states a
/// person can actually be in and assert the words that come out.
///
/// Each case prints what would be read, so the states can be inspected rather
/// than only asserted.
void main() {
  Candidate candidate({
    String key = 'trainwell.com',
    String name = 'trainwell',
    Certainty certainty = Certainty.evidenced,
    PursuitDisposition disposition = PursuitDisposition.unreviewed,
    bool hasRelationship = false,
    String? why = 'Client provides Commercial execution → More qualified '
        'conversations. Prospect appears to need demand and pipeline to make the '
        'new hires productive — Observed signal: "trainwell: Insurance Sales '
        'Coach" (hiring). Confidence 71%.',
    String? strength = 'STRONG',
    int evidenceCount = 2,
    List<String> reasons = const [],
    int representations = 1,
  }) =>
      Candidate(
        key: key,
        name: name,
        domain: key,
        geography: 'United States',
        contactName: 'Dana Reyes',
        contactRole: 'Head of Sales',
        hasRelationship: hasRelationship,
        relationshipId: hasRelationship ? 'rel-1' : null,
        whyItMatters: why,
        opportunityStrength: strength,
        opportunityConfidence: 71,
        certainty: certainty,
        certaintyMeans: switch (certainty) {
          Certainty.evidenced => 'Backed by something we actually observed.',
          Certainty.thin => 'Something was observed, but not much of it.',
          Certainty.insufficient =>
            'We have not observed enough to say much. Treat this as a lead to '
                'check, not a finding.',
          Certainty.stale => 'What we observed has aged. It may no longer be true.',
        },
        evidenceCount: evidenceCount,
        newestEvidenceAt: DateTime.now().subtract(const Duration(days: 3)),
        decision: 'ACCEPT',
        decidedAt: DateTime.now(),
        reasons: reasons,
        disposition: disposition,
        dispositionMeans: switch (disposition) {
          PursuitDisposition.unreviewed =>
            'Nobody has decided anything about this one yet.',
          PursuitDisposition.pursuing =>
            'Your business decided this is worth effort. Nothing has been sent.',
          PursuitDisposition.holding => 'Worth keeping in view, not now.',
          PursuitDisposition.declined =>
            'Your business decided against pursuing this.',
        },
        dispositionNote: null,
        discoveredRepresentations: representations,
      );

  const intent = BusinessIntent(
    capability: 'Commercial execution',
    outcome: 'More qualified conversations',
    buyerSituation: 'Revenue growth through outbound',
    triggers: ['Hiring sales staff', 'Market expansion'],
    says: 'You help businesses with commercial execution, so they get more '
        'qualified conversations. The people who need that are usually dealing '
        'with revenue growth through outbound.',
  );

  MarketView view(
    List<Candidate> candidates, {
    BusinessIntent? withIntent = intent,
    int withoutIdentity = 0,
    int artifacts = 0,
    String? note,
  }) =>
      MarketView(
        intent: withIntent,
        candidates: candidates,
        excludedWithoutIdentity: withoutIdentity,
        excludedArtifacts: artifacts,
        excludedNote: note,
        counts: MarketCounts(
          total: candidates.length,
          needsReview: candidates.where((c) => c.needsReview).length,
          pursuing: candidates
              .where((c) => c.disposition == PursuitDisposition.pursuing)
              .length,
          alreadyRelated: candidates.where((c) => c.hasRelationship).length,
          insufficientEvidence: candidates
              .where((c) => c.certainty == Certainty.insufficient)
              .length,
        ),
      );

  Future<void> render(WidgetTester tester, String name) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MarketScreen())),
    );
    await tester.pump();
    final read = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText())
        .whereType<String>()
        .where((t) => t.trim().isNotEmpty);
    debugPrint('\n──── $name ────');
    for (final line in read) {
      debugPrint('  $line');
    }
  }

  tearDown(() => ClientMarket.instance.seed(null));

  testWidgets('1. the surface opens with what the business sells', (tester) async {
    ClientMarket.instance.seed(view([candidate()]));
    await render(tester, 'default');

    // "Worth pursuing" needs an object, and it is the first thing on screen.
    expect(find.text('What you are looking for'), findsOneWidget);
    expect(find.textContaining('more qualified conversations'), findsOneWidget);
    expect(find.textContaining('hiring sales staff'), findsOneWidget);

    // And not with accounting numbers about a database.
    expect(find.textContaining('215'), findsNothing);
    expect(find.textContaining('signals'), findsNothing);
    expect(find.textContaining('score'), findsNothing);
    expect(find.textContaining('campaigns'), findsNothing);
  });

  testWidgets('2. a high-evidence candidate leads with why, not with a number',
      (tester) async {
    ClientMarket.instance.seed(view([candidate()]));
    await render(tester, 'high evidence');

    expect(find.text('WORTH A LOOK'), findsOneWidget);
    expect(find.text('trainwell'), findsOneWidget);
    // The rationale, verbatim, naming offer and observation.
    expect(find.textContaining('Commercial execution'), findsWidgets);
    expect(find.textContaining('Insurance Sales Coach'), findsOneWidget);
    // Certainty is a word, never colour alone.
    expect(find.textContaining('evidenced'), findsOneWidget);
  });

  testWidgets('3. a weak candidate says so rather than being ranked',
      (tester) async {
    ClientMarket.instance.seed(view([
      candidate(
        key: 'quietco.test', name: 'Quiet Co',
        certainty: Certainty.insufficient, why: null, strength: null,
        evidenceCount: 0,
      ),
    ]));
    await render(tester, 'weak evidence');

    // Not beside the evidenced ones — that would imply a finding where there
    // is only a name.
    expect(find.text('WORTH A LOOK'), findsNothing);
    expect(find.textContaining('Nothing new needs your judgement'), findsOneWidget);
    expect(find.textContaining('Show 1 we know little about'), findsOneWidget);

    await tester.tap(find.textContaining('Show 1 we know little about'));
    await tester.pump();
    expect(find.text('Quiet Co'), findsOneWidget);
    expect(find.textContaining('not observed enough'), findsOneWidget);
    expect(find.textContaining('a lead to check, not a finding'), findsOneWidget);
  });

  testWidgets('4. stale evidence is not presented as current', (tester) async {
    ClientMarket.instance.seed(view([
      candidate(key: 'lastspring.test', name: 'Last Spring Ltd',
          certainty: Certainty.stale),
    ]));
    await render(tester, 'stale');

    // A stale candidate with a stated commercial reason is still the best
    // thing in this market — every observation in production is months old, so
    // withholding these would leave the surface empty and useless. It stays in
    // view, and the row leads with the staleness rather than with a rationale
    // that would read as a live reason to act today.
    expect(find.text('WORTH A LOOK'), findsOneWidget);
    expect(find.text('Last Spring Ltd'), findsOneWidget);
    expect(find.textContaining('has aged'), findsOneWidget);
    expect(find.textContaining('may no longer be true'), findsOneWidget);
    // The rationale is not shown as the reason on the row.
    expect(find.textContaining('Insurance Sales Coach'), findsNothing);
    // And 'aged' is a word, not just a colour.
    expect(find.textContaining('aged'), findsWidgets);
  });

  testWidgets('5. a decided candidate is separated from an undecided one',
      (tester) async {
    ClientMarket.instance.seed(view([
      candidate(),
      candidate(key: 'acme.test', name: 'Acme', disposition: PursuitDisposition.pursuing),
      candidate(key: 'beta.test', name: 'Beta', disposition: PursuitDisposition.holding),
    ]));
    await render(tester, 'decided');

    expect(find.text('WORTH A LOOK'), findsOneWidget);
    expect(find.text('YOU HAVE DECIDED'), findsOneWidget);
    expect(find.textContaining('worth pursuing'), findsOneWidget);
    expect(find.textContaining('keep in view'), findsOneWidget);
  });

  testWidgets('6. a counterparty with a relationship is handed onward',
      (tester) async {
    ClientMarket.instance.seed(view([
      candidate(key: 'appliedsystems.com', name: 'Applied Systems',
          hasRelationship: true),
    ]));
    await render(tester, 'already related');

    expect(find.text('ALREADY A RELATIONSHIP'), findsOneWidget);
    expect(find.textContaining('relationship'), findsWidgets);
    // Not duplicated as an ordinary untouched candidate.
    expect(find.text('WORTH A LOOK'), findsNothing);
  });

  testWidgets('7. no business intent is its own empty state', (tester) async {
    ClientMarket.instance.seed(view(const [], withIntent: null));
    await render(tester, 'no intent');

    // Distinct from "nobody found yet" — telling a business discovery found
    // nothing, when in fact they never said what they sell, would be wrong.
    expect(find.textContaining('has not said what it sells'), findsOneWidget);
    expect(find.textContaining('nothing to judge a counterparty against'),
        findsOneWidget);
  });

  testWidgets('8. nobody found yet is a different empty state', (tester) async {
    ClientMarket.instance.seed(view(const []));
    await render(tester, 'nobody yet');

    expect(find.textContaining('Nobody has been found yet'), findsOneWidget);
    expect(find.textContaining('has not said what it sells'), findsNothing);
  });

  testWidgets('9. what was left out is stated, not hidden', (tester) async {
    ClientMarket.instance.seed(view(
      [candidate()],
      withoutIdentity: 26,
      artifacts: 3,
      note: 'Some discovered records could not be shown as companies: either no '
          'website was recorded for them, or what was found was a directory '
          'listing rather than a business.',
    ));
    await render(tester, 'exclusions');

    expect(find.textContaining('could not be shown as companies'), findsOneWidget);
  });

  testWidgets('10. market unavailable is not zero candidates', (tester) async {
    ClientMarket.instance.seed(null, error: StateError('network'));
    await render(tester, 'unavailable');

    expect(find.textContaining('could not load your market'), findsOneWidget);
    // A failure rendering as an empty market would tell a business its
    // pipeline had vanished.
    expect(find.textContaining('Nothing has changed and nothing was lost'),
        findsOneWidget);
    expect(find.textContaining('Nobody has been found yet'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('11. counterparty identity is semantically readable', (tester) async {
    ClientMarket.instance.seed(view([candidate()]));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MarketScreen())),
    );
    await tester.pump();

    // Chapter A shipped two defects that were visible on canvas and absent to
    // anything that read the screen. Identity, why and judgement must all be
    // reachable as text.
    final semantics = tester.getSemantics(find.text('trainwell'));
    expect(semantics.label, contains('trainwell'));
    expect(find.textContaining('trainwell.com'), findsWidgets);
    expect(find.textContaining('evidenced'), findsOneWidget);
  });

  testWidgets('12. every state fits, phone through desktop', (tester) async {
    ClientMarket.instance.seed(view([
      candidate(),
      candidate(key: 'acme.test', name: 'Acme Manufacturing Group Limited',
          disposition: PursuitDisposition.pursuing),
      candidate(key: 'appliedsystems.com', name: 'Applied Systems',
          hasRelationship: true),
      candidate(key: 'quietco.test', name: 'Quiet Co',
          certainty: Certainty.insufficient, why: null, strength: null),
    ]));

    for (final size in const [
      Size(360, 900),
      Size(768, 1024),
      Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MarketScreen())),
      );
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'market must render without overflow at ${size.width}px');
      expect(find.text('WORTH A LOOK'), findsOneWidget);
      debugPrint('  ok  ${size.width.toInt()}x${size.height.toInt()} — no overflow');
    }
  });
}
