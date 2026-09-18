import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/commercial/client_capabilities.dart';
import 'package:orchestrate_app/core/market/client_market.dart';
import 'package:orchestrate_app/core/readiness/standing_conditions.dart';
import 'package:orchestrate_app/features/client/screens/market_screen.dart';

/// WHAT A NEW BUSINESS WITHOUT A PLAN IS TOLD, ACROSS SURFACES.
///
/// Four surfaces said something untrue to a workspace with no plan: Business
/// called every blocker "Sending is held" and sent every one to mailbox
/// settings; Market pointed at a screen that could not resolve it, then would
/// have said "Searching your market" about a search that is refused. These pin
/// the corrected readings.
void main() {
  const planReason = 'Ongoing operation needs an active plan. Your workspace, '
      'your setup and anything already recorded stay exactly as they are.';

  group('one reader for standing conditions', () {
    final eligibility = {
      'bucket': 'client_action_required',
      'blockers': [
        {
          'code': 'AUTHORIZATION_MISSING',
          'label': 'Authorization required',
          'detail': 'Representation authorization is required before outbound outreach can send.',
          'resolutionRoute': '/client/representation',
          'resolutionCta': 'Authorize representation',
        },
        {
          'code': 'PLAN_ACTIVATION_REQUIRED',
          'label': 'Plan activation required',
          'detail': planReason,
          'resolutionRoute': '/client/billing',
          'resolutionCta': 'Activate a plan',
        },
        {
          'code': 'MAILBOX_MISSING',
          'label': 'Mailbox missing',
          'detail': 'No sending mailbox of yours is connected yet.',
          'resolutionRoute': '/client/infrastructure',
          'resolutionCta': 'Connect mailbox',
        },
      ],
    };

    test('each condition keeps its own name and destination', () {
      final c = standingConditionsFrom(eligibility);
      expect(c.map((x) => x.title), [
        'Authorization required',
        'Plan activation required',
        'Mailbox missing',
      ]);
      expect(c.map((x) => x.route), [
        '/client/representation',
        '/client/billing',
        '/client/infrastructure',
      ]);
      // The plan is never sent to mailbox settings.
      expect(c[1].route, isNot('/client/infrastructure'));
      expect(c.where((x) => x.title == 'Sending is held'), isEmpty);
    });

    test('what the grant leaves outstanding excludes the grant itself', () {
      final remaining = standingConditionsFrom(eligibility)
          .where((x) => !representationConditionCodes.contains(x.code))
          .map((x) => x.title);
      expect(remaining, ['Plan activation required', 'Mailbox missing']);
    });

    test('an unnamed blocker is not called a sending problem', () {
      final c = standingConditionsFrom({
        'blockers': [
          {'code': 'X', 'detail': 'held'}
        ]
      });
      expect(c.single.title, isNot(contains('Sending')));
      expect(c.single.route, isNull, reason: 'no destination is guessed');
    });

    test('a stack trace is not shown to a client', () {
      final c = standingConditionsFrom({
        'blockers': [
          {'code': 'ELIGIBILITY_EVALUATION_FAILED', 'label': 'Eligibility evaluation failed',
            'detail': 'at Object.<anonymous> (/app/dist/src/x.service.js:12)'}
        ]
      });
      expect(c.single.detail, contains('fault on our side'));
    });
  });

  group('Market, empty, for a business without a plan', () {
    MarketView emptyView({BusinessIntent? intent}) => MarketView(
          intent: intent,
          coverage: const MarketCoverage(
            discovering: true,
            geographyNeedsConfirmation: false,
            areasChecked: 0,
            areasKnown: 0,
            lastCheckedAt: null,
            note: null,
          ),
          candidates: const [],
          excludedWithoutIdentity: 0,
          excludedArtifacts: 0,
          excludedNote: null,
          counts: const MarketCounts(
            total: 0, needsReview: 0, pursuing: 0, alreadyRelated: 0, insufficientEvidence: 0),
        );

    CapabilityProjection caps({required bool research}) => CapabilityProjection(
          entitlement: const Entitlement(
            state: EntitlementState.none,
            source: EntitlementSource.none,
            says: 'Your workspace is set up.',
            because: 'Nothing has been activated for this organisation yet.',
            isPayingCustomer: false,
          ),
          capabilities: [
            CapabilityVerdict(
              capability: Capabilities.researchCounterparties,
              permitted: research,
              code: research ? null : 'PLAN_ACTIVATION_REQUIRED',
              why: research ? null : planReason,
              resolution: research ? null : 'Activate from Plan & billing in your account.',
            ),
          ],
          model: const [],
          note: '',
        );

    const stated = BusinessIntent(
      capability: 'Commercial roofing repair',
      outcome: '',
      buyerSituation: '',
      triggers: [],
      says: 'You told Orchestrate what you offer: Commercial roofing repair',
    );

    Future<void> render(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MarketScreen())));
      await tester.pump();
    }

    tearDown(() {
      ClientMarket.instance.seed(null);
      ClientCapabilities.instance.seed(null);
    });

    testWidgets('no offer: the pointer leads somewhere that resolves it', (tester) async {
      ClientCapabilities.instance.seed(caps(research: false));
      ClientMarket.instance.seed(emptyView());
      await render(tester);
      expect(find.text('Your business has not said what it sells.'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Describe what you sell'), findsOneWidget);
    });

    testWidgets('research refused: says so, never "Searching your market"', (tester) async {
      ClientCapabilities.instance.seed(caps(research: false));
      ClientMarket.instance.seed(emptyView(intent: stated));
      await render(tester);
      expect(find.text('Your market is not being searched.'), findsOneWidget);
      expect(find.text('This needs an active plan'), findsOneWidget);
      expect(find.text(planReason), findsOneWidget);
      expect(find.text('Searching your market.'), findsNothing);
    });

    testWidgets('control: research permitted still reads as searching', (tester) async {
      ClientCapabilities.instance.seed(caps(research: true));
      ClientMarket.instance.seed(emptyView(intent: stated));
      await render(tester);
      expect(find.text('Searching your market.'), findsOneWidget);
      expect(find.text('Your market is not being searched.'), findsNothing);
    });
  });
}
