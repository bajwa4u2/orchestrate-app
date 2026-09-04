import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/relationships/client_relationships.dart';
import 'package:orchestrate_app/data/repositories/client/client_engagement_repository.dart';
import 'package:orchestrate_app/features/client/widgets/engagement_panel.dart';
import 'package:orchestrate_app/features/client/screens/relationships_workspace_screen.dart';

/// THE RELATIONSHIP STATES, RENDERED AND READ.
///
/// Production holds 19 relationships across 2 clients, 409 events of which 390
/// are hard bounces, zero replies, zero confirmed deliveries and zero
/// engagements. Four exist only because a message bounced, and every one of the
/// nineteen was being reported as ACTIVE.
///
/// These render what a person would actually see, including the states
/// production has never been in — because a structure that only works on
/// today's data is not architecture.
void main() {
  RelationshipSummary summary({
    String id = 'r1',
    String name = 'DFW Crossdock Xpress',
    String key = 'dfwcrossdockxpress.com',
    RelationshipCondition condition = RelationshipCondition.active,
    String because = 'One message went out. Nothing has come back either way.',
    Reachability reachability = Reachability.unknown,
    String reachabilityBecause =
        'One message went out and no delivery evidence came back either way.',
    String? openEngagementId,
    int engagementCount = 0,
    int attention = 0,
  }) =>
      RelationshipSummary(
        id: id,
        counterparty: name,
        counterpartyKey: key,
        condition: condition,
        conditionMeans: 'There has been recent activity between you.',
        conditionBecause: because,
        reachability: reachability,
        reachabilityBecause: reachabilityBecause,
        lastEventAt: DateTime.now().subtract(const Duration(days: 2)),
        openEngagementId: openEngagementId,
        engagementCount: engagementCount,
        attention: attention,
      );

  RelationshipList list(List<RelationshipSummary> rows) => RelationshipList(
        relationships: rows,
        counts: {
          for (final c in RelationshipCondition.values)
            c: rows.where((r) => r.condition == c).length,
        },
        note: 'A relationship is durable commercial context between your '
            'business and a counterparty. It can hold no undertakings, one, or many.',
      );

  RelationshipDepth depth({
    String id = 'r1',
    String name = 'DFW Crossdock Xpress',
    RelationshipCondition condition = RelationshipCondition.active,
    String means = 'There has been recent activity on this relationship.',
    String because = 'A message was attempted recently and came back undelivered.',
    Reachability reachability = Reachability.failed,
    String reachabilityMeans = 'No confirmed reachability — the latest delivery '
        'attempt came back undelivered. Nothing has been shown to arrive.',
    String reachabilityBecause = 'The latest delivery attempt hard-bounced.',
    List<EngagementSummary> engagements = const [],
    String? currentEngagementId,
    List<RelationshipAttention> attention = const [],
    List<TimelineEntry> timeline = const [],
    bool weakProvenance = false,
    int eventCount = 2,
  }) =>
      RelationshipDepth(
        id: id,
        counterparty: name,
        counterpartyKey: 'dfwcrossdockxpress.com',
        condition: condition,
        conditionMeans: means,
        conditionBecause: because,
        reachability: reachability,
        reachabilityMeans: reachabilityMeans,
        reachabilityBecause: reachabilityBecause,
        origin: RelationshipOrigin(
          says: 'It began when your business first wrote to them.',
          at: DateTime.now().subtract(const Duration(days: 70)),
          provenanceIsWeak: weakProvenance,
        ),
        engagements: engagements,
        currentEngagementId: currentEngagementId,
        attention: attention,
        timeline: timeline,
        eventCount: eventCount,
        refusalReason: null,
      );

  TimelineEntry entry({
    String kind = 'FAILED_TO_REACH',
    String says = '386 messages came back undelivered.',
    int occurrences = 386,
    bool isCurrent = true,
  }) =>
      TimelineEntry(
        kind: kind,
        says: says,
        at: DateTime.now().subtract(const Duration(days: 72)),
        until: occurrences > 1
            ? DateTime.now().subtract(const Duration(days: 70))
            : null,
        occurrences: occurrences,
        consequence: 'EXTERNALLY_COMMUNICATED',
        isCurrent: isCurrent,
        engagementId: null,
      );

  EngagementSummary engagement({
    String id = 'e1',
    String state = 'OPEN',
    String? reference = 'Q4 pilot',
  }) =>
      EngagementSummary(
        id: id,
        reference: reference,
        state: state,
        openedAt: DateTime.now().subtract(const Duration(days: 20)),
        completedAt: state == 'COMPLETED' ? DateTime.now() : null,
        abandonedAt: state == 'ABANDONED' ? DateTime.now() : null,
      );

  setUp(() {
    // Every relationship renders the containment, so the default is a
    // relationship that holds nothing — which is also what production is.
    EngagementPanel.testRepository = _Undertakings(const []);
  });

  tearDown(() => EngagementPanel.testRepository = null);

  Future<void> render(
    WidgetTester tester,
    String name, {
    String? relationshipId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelationshipsWorkspaceScreen(relationshipId: relationshipId),
        ),
      ),
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

  tearDown(() => ClientRelationships.instance.seed(null));

  testWidgets('1. the list leads with the reason, not the label', (tester) async {
    ClientRelationships.instance.seed(list([summary()]));
    await render(tester, 'list');

    expect(find.text('DFW Crossdock Xpress'), findsOneWidget);
    // "Active" alone tells a business nothing. The reason travels with it.
    expect(find.textContaining('Nothing has come back either way'), findsOneWidget);
    expect(find.textContaining('active'), findsOneWidget);
    // Not another Market table.
    expect(find.textContaining('score'), findsNothing);
    expect(find.textContaining('stage'), findsNothing);
  });

  testWidgets('2. bounce-only shows both axes and conflates neither',
      (tester) async {
    ClientRelationships.instance.seed(list([
      summary(
        condition: RelationshipCondition.active,
        because: 'A message was attempted recently and came back undelivered.',
        reachability: Reachability.failed,
        reachabilityBecause: 'The latest delivery attempt hard-bounced.',
      ),
    ]));
    await render(tester, 'bounce-only in list');

    // A failed channel earns the top band — a person can change that outcome.
    expect(find.text('NEEDS A LOOK'), findsOneWidget);
    // Condition stays canonical. Reachability is its own word beside it, and
    // neither is allowed to stand in for the other.
    expect(find.textContaining('active'), findsOneWidget);
    expect(find.textContaining('no confirmed reachability'), findsOneWidget);
    expect(find.textContaining('came back undelivered'), findsOneWidget);
    // Nothing claims they responded.
    expect(find.textContaining('in touch'), findsNothing);
    expect(find.textContaining('replied'), findsNothing);
  });

  testWidgets('3. a healthy list has no attention band at all', (tester) async {
    ClientRelationships.instance.seed(list([
      summary(),
      summary(id: 'r2', name: 'BrightFarms', key: 'brightfarms.com'),
    ]));
    await render(tester, 'healthy list');

    expect(find.text('NEEDS A LOOK'), findsNothing);
    expect(find.text('RELATIONSHIPS'), findsOneWidget);
    // Nothing gets a banner for being fine.
    expect(find.textContaining('Everything is'), findsNothing);
    expect(find.textContaining('All good'), findsNothing);
  });

  testWidgets('4. depth shows condition and channel as two separate facts',
      (tester) async {
    ClientRelationships.instance.seed(
      list([summary()]),
      depth: {'r1': depth(timeline: [entry(occurrences: 1, says: 'A message came back undelivered.')])},
    );
    await render(tester, 'depth — active, channel failed', relationshipId: 'r1');

    // Condition is canonical and stays out of the channel's business.
    expect(find.textContaining('came back undelivered'), findsWidgets);
    // The channel gets its own heading and its own sentence.
    expect(find.text('No confirmed reachability'), findsOneWidget);
    expect(find.textContaining('Nothing has been shown to arrive'), findsOneWidget);
    // And nothing anywhere claims the recipient responded.
    expect(find.textContaining('written back'), findsNothing);
    // The first viewport is not counts.
    expect(find.textContaining('409'), findsNothing);
  });

  testWidgets('5. a healthy relationship stays quiet in depth', (tester) async {
    ClientRelationships.instance.seed(
      list([summary()]),
      depth: {
        'r1': depth(
          condition: RelationshipCondition.active,
          because: 'One message went out. Nothing has come back either way.',
          reachability: Reachability.unknown,
          reachabilityMeans: 'No confirmed reachability. Something was sent and '
              'no delivery evidence came back either way, so we cannot say '
              'whether it arrived.',
          reachabilityBecause:
              'One message went out and no delivery evidence came back either way.',
          timeline: [entry(kind: 'SENT', says: 'A message went out.', occurrences: 1)],
        ),
      },
    );
    await render(tester, 'depth — healthy', relationshipId: 'r1');

    expect(find.textContaining('Nothing has come back either way'), findsWidgets);
    // A calm condition is one line, not a card demanding the top of the page.
    expect(find.text('There has been recent activity on this relationship.'),
        findsNothing);
    // An unknown channel is stated plainly and does not alarm anyone.
    expect(find.text('No confirmed reachability'), findsNothing);
  });

  testWidgets('6. a relationship with no undertaking is still meaningful',
      (tester) async {
    ClientRelationships.instance.seed(
      list([summary()]),
      depth: {'r1': depth(timeline: [entry(occurrences: 1, says: 'A message went out.')])},
    );
    await render(tester, 'depth — no engagement', relationshipId: 'r1');

    // No void where an engagement would be. Durable context legitimately
    // exists before any undertaking begins, and most production relationships
    // are exactly here.
    expect(find.textContaining('No engagement'), findsNothing);
    expect(find.text('CURRENT UNDERTAKING'), findsNothing);
    expect(find.textContaining('What has happened'), findsOneWidget);
    expect(find.textContaining('Why this relationship exists'), findsOneWidget);
  });

  testWidgets('7. one open undertaking is contained, not a second domain',
      (tester) async {
    ClientRelationships.instance.seed(
      list([summary(openEngagementId: 'e1', engagementCount: 1)]),
      depth: {
        'r1': depth(
          condition: RelationshipCondition.inEngagement,
          means: 'There is an open piece of commercial work with them.',
          because: '1 open undertaking.',
          engagements: [engagement()],
          currentEngagementId: 'e1',
        ),
      },
    );
    EngagementPanel.testRepository = _Undertakings([
      _row(id: 'e1', purpose: 'Q4 pilot', state: 'OPEN'),
    ]);
    await render(tester, 'depth — one engagement', relationshipId: 'r1');
    await tester.pumpAndSettle();

    // Inside the relationship, under its own heading, and reached without
    // leaving the relationship. No route, no top-level list.
    expect(find.text('UNDERTAKINGS'), findsOneWidget);
    expect(find.text('Q4 pilot'), findsOneWidget);
    // It used to say the lifecycle was not built. It is built: the acts that
    // end an undertaking are here, on the undertaking, inside the relationship.
    expect(find.textContaining('not built yet'), findsNothing);
    expect(find.text('Open an undertaking'), findsOneWidget);
  });

  testWidgets('8. several undertakings, and only the open one is current',
      (tester) async {
    ClientRelationships.instance.seed(
      list([summary(openEngagementId: 'e1', engagementCount: 3)]),
      depth: {
        'r1': depth(
          condition: RelationshipCondition.inEngagement,
          because: '1 open undertaking.',
          engagements: [
            engagement(),
            engagement(id: 'e2', state: 'COMPLETED', reference: 'Pilot'),
            engagement(id: 'e3', state: 'ABANDONED', reference: 'Trial'),
          ],
          currentEngagementId: 'e1',
        ),
      },
    );
    EngagementPanel.testRepository = _Undertakings([
      _row(id: 'e1', purpose: 'Q4 pilot', state: 'OPEN'),
      _row(id: 'e2', purpose: 'Pilot', state: 'COMPLETED'),
      _row(id: 'e3', purpose: 'Trial', state: 'ABANDONED'),
    ]);
    await render(tester, 'depth — multiple engagements', relationshipId: 'r1');
    await tester.pumpAndSettle();

    expect(find.text('Q4 pilot'), findsOneWidget);
    // Ended ones are behind a fold — never dressed up as current.
    expect(find.text('Pilot'), findsNothing);
    expect(find.textContaining('Show 2 undertakings that have ended'),
        findsOneWidget);

    await tester.tap(find.textContaining('Show 2 undertakings that have ended'));
    await tester.pumpAndSettle();
    expect(find.text('Pilot'), findsOneWidget);
    expect(find.text('Trial'), findsOneWidget);
    expect(find.textContaining('does not end because an undertaking does'),
        findsWidgets);
  });

  testWidgets('9. 386 bounces read as one thing that happened', (tester) async {
    ClientRelationships.instance.seed(
      list([summary()]),
      depth: {'r1': depth(timeline: [entry()], eventCount: 386)},
    );
    await render(tester, 'depth — collapsed history', relationshipId: 'r1');

    expect(find.textContaining('What has happened (1)'), findsOneWidget);
    await tester.tap(find.textContaining('What has happened'));
    await tester.pump();
    expect(find.text('386 messages came back undelivered.'), findsOneWidget);
  });

  testWidgets('10. a superseded fact stays and stops being the answer',
      (tester) async {
    ClientRelationships.instance.seed(
      list([summary()]),
      depth: {
        'r1': depth(
          condition: RelationshipCondition.active,
          reachability: Reachability.confirmed,
          reachabilityMeans: 'Messages are getting through to them.',
          reachabilityBecause: 'Delivery was confirmed.',
          timeline: [
            entry(kind: 'REACHED', says: 'A message reached them.', occurrences: 1),
            entry(
              kind: 'FAILED_TO_REACH',
              says: 'A message came back undelivered.',
              occurrences: 1,
              isCurrent: false,
            ),
          ],
        ),
      },
    );
    await render(tester, 'depth — supersession', relationshipId: 'r1');

    await tester.tap(find.textContaining('What has happened'));
    await tester.pump();
    expect(find.text('A message reached them.'), findsOneWidget);
    expect(find.text('A message came back undelivered.'), findsOneWidget);
    // History explains how we got here; current truth explains what governs.
    expect(find.textContaining('A later record replaced this'), findsOneWidget);
    expect(find.textContaining('superseded'), findsOneWidget);
  });

  testWidgets('11. weak provenance is admitted, not hidden', (tester) async {
    ClientRelationships.instance.seed(
      list([summary()]),
      depth: {'r1': depth(weakProvenance: true)},
    );
    await render(tester, 'depth — weak provenance', relationshipId: 'r1');

    await tester.tap(find.textContaining('Why this relationship exists'));
    await tester.pump();
    expect(find.textContaining('first wrote to them'), findsOneWidget);
    // Every production row was created after the history it describes.
    expect(find.textContaining('created after the events it describes'),
        findsOneWidget);
  });

  testWidgets('12. attention is referenced, not rebuilt', (tester) async {
    ClientRelationships.instance.seed(
      list([summary(attention: 1)]),
      depth: {
        'r1': depth(
          attention: [
            RelationshipAttention(
              id: 'q1',
              subject: 'The Hartford Billing Status Alert',
              from: 'Alerts@agent.thehartford.com',
              receivedAt: DateTime.now(),
            ),
          ],
        ),
      },
    );
    await render(tester, 'depth — attention', relationshipId: 'r1');

    expect(find.text('WAITING ON SOMEONE'), findsOneWidget);
    expect(find.text('The Hartford Billing Status Alert'), findsOneWidget);
    expect(find.textContaining('has not been placed'), findsOneWidget);
  });

  testWidgets('13. the list could not be read — not zero relationships',
      (tester) async {
    ClientRelationships.instance.seed(null, error: StateError('network'));
    await render(tester, 'unavailable');

    expect(find.textContaining('could not load your relationships'), findsOneWidget);
    expect(find.textContaining('Nothing has changed and nothing was lost'),
        findsOneWidget);
    expect(find.textContaining('No relationships yet'), findsNothing);
  });

  testWidgets('14. counterparty and condition are semantically readable',
      (tester) async {
    ClientRelationships.instance.seed(list([summary()]));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RelationshipsWorkspaceScreen())),
    );
    await tester.pump();

    final semantics = tester.getSemantics(find.text('DFW Crossdock Xpress'));
    expect(semantics.label, contains('DFW'));
    // Condition is a word, not only a colour.
    expect(find.textContaining('active'), findsOneWidget);
  });

  testWidgets('15. every state fits, phone through desktop', (tester) async {
    ClientRelationships.instance.seed(
      list([
        summary(reachability: Reachability.failed),
        summary(id: 'r2', name: 'Acme Manufacturing Group Limited', key: 'acme.test'),
        summary(id: 'r3', name: 'BrightFarms', key: 'brightfarms.com', attention: 2),
      ]),
    );

    for (final size in const [
      Size(360, 900),
      Size(768, 1024),
      Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RelationshipsWorkspaceScreen())),
      );
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'relationships must render without overflow at ${size.width}px');
      expect(find.text('NEEDS A LOOK'), findsOneWidget);
      debugPrint('  ok  ${size.width.toInt()}x${size.height.toInt()} — no overflow');
    }
  });
}

Map<String, dynamic> _row({
  required String id,
  required String purpose,
  required String state,
}) =>
    {
      'id': id,
      'purpose': purpose,
      'state': state,
      'stateMeans': state == 'OPEN'
          ? 'This undertaking is under way.'
          : state == 'COMPLETED'
              ? 'This undertaking reached its conclusion.'
              : 'This undertaking stopped without reaching its conclusion.',
      'origin': 'CLIENT_DECISION',
      'originMeans': 'Your business decided this undertaking exists.',
      'openedAt': DateTime.now().toIso8601String(),
      'blocker': null,
      'needsAHuman': false,
    };

/// Stands in for the engagement authority so a relationship test asserts
/// containment rather than the behaviour of a failed network read.
class _Undertakings implements ClientEngagementRepository {
  _Undertakings(this.rows);

  final List<Map<String, dynamic>> rows;

  @override
  Future<RelationshipEngagements> forRelationship(String relationshipId) async =>
      RelationshipEngagements.fromJson({
        'relationshipId': relationshipId,
        'counterparty': 'DFW Crossdock Xpress',
        'says': rows.isEmpty
            ? 'No bounded undertaking has been established here yet.'
            : '${rows.where((r) => r['state'] == 'OPEN').length} of '
                '${rows.length} under way.',
        'engagements': rows,
      });

  @override
  Future<EngagementDetail?> detail(String engagementId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
