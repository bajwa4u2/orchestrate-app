import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/data/repositories/client/client_engagement_repository.dart';
import 'package:orchestrate_app/features/client/widgets/engagement_panel.dart';

/// AN UNDERTAKING, AS A PERSON READS IT.
///
/// Production holds 19 relationships and 0 engagements. That is the state this
/// surface is most often in, and it is a legitimate one — contact,
/// correspondence and commercial context all exist without anybody having
/// taken on a bounded piece of work. A panel that renders that as an empty list
/// teaches a business it has a gap to fill.
///
/// The rest of these are the places where a client would be tempted to write
/// its own wording and quietly disagree with the authority that decided:
/// whether something was opened, whether it is finished, and why it was
/// refused. Each case prints what would be read, so the states can be inspected
/// rather than only asserted.
void main() {
  Future<void> mount(WidgetTester tester, _Canned canned) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EngagementPanel(
            relationshipId: 'rel-1',
            repository: canned,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a relationship with nothing taken on says so, and is not empty',
      (tester) async {
    final canned = _Canned(list: {
      'relationshipId': 'rel-1',
      'counterparty': 'Trainwell',
      'says': 'No bounded undertaking has been established here yet.',
      'engagements': const [],
    });
    await mount(tester, canned);

    // The server's sentence, verbatim. Not "No engagements", which reads as an
    // absence of something that ought to be there.
    expect(find.textContaining('No bounded undertaking has been established'),
        findsOneWidget);
    expect(find.textContaining('This is not a gap'), findsOneWidget);
    // And the way in is still offered, because having none is not a refusal.
    expect(find.text('Open an undertaking'), findsOneWidget);
  });

  testWidgets('the server decides whether a purpose says anything', (tester) async {
    final canned = _Canned(
      list: _listWith(const []),
      openResult: {
        'ok': false,
        'code': 'PURPOSE_REQUIRED',
        'reason': 'Say what the undertaking is, not who it is with — the '
            'relationship already says that, and two undertakings with the '
            'same counterparty would read identically.',
      },
    );
    await mount(tester, canned);

    await tester.tap(find.text('Open an undertaking'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Engagement with Trainwell');
    await tester.tap(find.text('Record it'));
    await tester.pumpAndSettle();

    // Rendered as written. Rewriting this into "Invalid purpose" would throw
    // away the only part of the response that tells someone what to type.
    expect(find.textContaining('not who it is with'), findsOneWidget);
    // The CODE is not customer copy. It used to be printed in monospace under
    // a sentence the person had just read in plain English — telling them
    // nothing they could act on and making a clear refusal look like an error
    // screen. It still travels in the payload, for support.
    expect(find.textContaining('PURPOSE_REQUIRED'), findsNothing);
  });

  testWidgets('a lapsed plan refuses here in the words of the commercial boundary',
      (tester) async {
    final canned = _Canned(
      list: _listWith(const []),
      openResult: {
        'ok': false,
        'code': 'PLAN_ACTIVATION_REQUIRED',
        'reason': 'Recording a commercial undertaking is ongoing use of '
            'Orchestrate, and your plan is not active.',
      },
    );
    await mount(tester, canned);

    await tester.tap(find.text('Open an undertaking'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Q4 fitness pilot');
    await tester.tap(find.text('Record it'));
    await tester.pumpAndSettle();

    // The commercial boundary and the authority boundary refuse differently
    // and are fixed differently. Only one of them is solved by paying.
    expect(find.textContaining('your plan is not active'), findsOneWidget);
    expect(find.textContaining('PLAN_ACTIVATION_REQUIRED'), findsNothing,
        reason: 'the reason is for the customer; the code is for us');
    expect(canned.opened, 1, reason: 'the refusal came from the server, not from here');
  });

  testWidgets('a retried admission does not claim it opened anything',
      (tester) async {
    final canned = _Canned(
      list: _listWith(const []),
      openResult: {
        'ok': true,
        'created': false,
        'note': 'This undertaking was already recorded. Nothing was duplicated.',
        'engagement': {'id': 'eng-1'},
      },
    );
    await mount(tester, canned);

    await tester.tap(find.text('Open an undertaking'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Q4 fitness pilot');
    await tester.tap(find.text('Record it'));
    await tester.pumpAndSettle();

    // Saying "opened" over an admission that created nothing teaches a person
    // the button does not work, and they press it again.
    expect(find.textContaining('already recorded'), findsOneWidget);
  });

  testWidgets('there is no WON anywhere a person can read', (tester) async {
    final canned = _Canned(
      list: _listWith([
        _engagement(
          id: 'eng-1',
          purpose: 'Q4 fitness pilot',
          state: 'COMPLETED',
          stateMeans: 'This undertaking reached its conclusion.',
        ),
      ]),
      detailJson: _detailFor('eng-1', state: 'COMPLETED'),
    );
    await mount(tester, canned);

    await tester.tap(find.textContaining('Show 1 undertaking that has ended'));
    await tester.pumpAndSettle();

    expect(find.textContaining('reached its conclusion'), findsOneWidget);
    // Commercial reality does not resolve into a funnel, and a terminal state
    // called WON forces every honest outcome into either a lie or LOST.
    expect(find.textContaining('Won'), findsNothing);
    expect(find.textContaining('Lost'), findsNothing);
    // And the relationship is not implied to be over.
    expect(find.textContaining('does not end because an undertaking does'),
        findsOneWidget);
  });

  testWidgets('a stale command is reported, not silently applied', (tester) async {
    final canned = _Canned(
      list: _listWith([
        _engagement(id: 'eng-1', purpose: 'Q4 fitness pilot', state: 'OPEN'),
      ]),
      detailJson: _detailFor('eng-1'),
      completeResult: {
        'ok': false,
        'code': 'ALREADY_COMPLETED',
        'reason': 'This undertaking was already completed. What happened to it '
            'is part of the record and is not rewritten by a later command.',
      },
    );
    await mount(tester, canned);

    await tester.tap(find.text('Q4 fitness pilot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('It reached its conclusion'));
    await tester.pumpAndSettle();

    // Two people see the same OPEN row. The second to act is told what
    // happened rather than overwriting the first.
    expect(find.textContaining('was already completed'), findsOneWidget);
    expect(find.textContaining('ALREADY_COMPLETED'), findsNothing,
        reason: 'the reason is for the customer; the code is for us');
  });

  testWidgets('stopping asks why, and says why it asks', (tester) async {
    final canned = _Canned(
      list: _listWith([
        _engagement(id: 'eng-1', purpose: 'Q4 fitness pilot', state: 'OPEN'),
      ]),
      detailJson: _detailFor('eng-1'),
    );
    await mount(tester, canned);

    await tester.tap(find.text('Q4 fitness pilot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('It stopped without concluding'));
    await tester.pumpAndSettle();

    // The requirement stated in the words of the rule behind it, rather than a
    // red asterisk on a field.
    expect(find.textContaining('indistinguishable from neglect'), findsOneWidget);
    expect(find.textContaining('Silence and elapsed time cannot end'),
        findsOneWidget);
    // And what stopping actually means for later.
    expect(find.textContaining('a new undertaking rather than this one reopening'),
        findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'They went in-house.');
    await tester.tap(find.text('Record that it stopped'));
    await tester.pumpAndSettle();

    expect(canned.abandonedWith, 'They went in-house.');
    // Re-read rather than patched: the server is the only thing that knows
    // what the act did.
    expect(canned.listReads, greaterThan(1));
  });

  testWidgets('a blocked undertaking is blocked, not ended', (tester) async {
    final canned = _Canned(
      list: _listWith([
        _engagement(
          id: 'eng-1',
          purpose: 'Q4 fitness pilot',
          state: 'OPEN',
          blocker: 'Every address for this counterparty has permanently failed.',
          needsAHuman: true,
        ),
      ]),
      detailJson: _detailFor('eng-1'),
    );
    await mount(tester, canned);

    expect(find.textContaining('permanently failed'), findsOneWidget);
    // A bounced address does not abandon a piece of work the business still
    // intends, so the lifecycle actions stay available.
    await tester.tap(find.text('Q4 fitness pilot'));
    await tester.pumpAndSettle();
    expect(find.text('It reached its conclusion'), findsOneWidget);
  });

  testWidgets('provenance is who said so, never a date', (tester) async {
    final canned = _Canned(
      list: _listWith([
        _engagement(id: 'eng-1', purpose: 'Q4 fitness pilot', state: 'OPEN'),
      ]),
      detailJson: _detailFor('eng-1'),
    );
    await mount(tester, canned);

    await tester.tap(find.text('Q4 fitness pilot'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your business decided this undertaking exists'),
        findsOneWidget);
    expect(find.textContaining('Recorded by Dana Reyes'), findsOneWidget);
    // Containment shown as an honest absence rather than hidden.
    expect(find.textContaining('None do yet'), findsOneWidget);
  });
}

Map<String, dynamic> _listWith(List<Map<String, dynamic>> engagements) => {
      'relationshipId': 'rel-1',
      'counterparty': 'Trainwell',
      'says': engagements.isEmpty
          ? 'No bounded undertaking has been established here yet.'
          : '${engagements.where((e) => e['state'] == 'OPEN').length} of '
              '${engagements.length} under way.',
      'engagements': engagements,
    };

Map<String, dynamic> _engagement({
  required String id,
  required String purpose,
  required String state,
  String stateMeans = 'This undertaking is under way.',
  String? blocker,
  bool needsAHuman = false,
}) =>
    {
      'id': id,
      'purpose': purpose,
      'state': state,
      'stateMeans': stateMeans,
      'origin': 'CLIENT_DECISION',
      'originMeans': 'Your business decided this undertaking exists.',
      'openedAt': DateTime.now().toIso8601String(),
      'completedAt': state == 'COMPLETED' ? DateTime.now().toIso8601String() : null,
      'abandonedAt': state == 'ABANDONED' ? DateTime.now().toIso8601String() : null,
      'blocker': blocker,
      'needsAHuman': needsAHuman,
    };

Map<String, dynamic> _detailFor(String id, {String state = 'OPEN'}) => {
      ..._engagement(id: id, purpose: 'Q4 fitness pilot', state: state),
      'relationshipId': 'rel-1',
      'counterparty': 'Trainwell',
      'counterpartyKey': 'trainwell.com',
      'admittedBy': 'Dana Reyes',
      'originNote': null,
      'abandonedReason': null,
      'downstream': {
        'agreements': 0,
        'obligations': 0,
        'invoices': 0,
        'says': 'Agreements, obligations and invoices belong to this '
            'undertaking when they exist. None do yet.',
      },
    };

class _Canned implements ClientEngagementRepository {
  _Canned({
    required this.list,
    this.detailJson,
    this.openResult,
    this.completeResult,

  });

  final Map<String, dynamic> list;
  final Map<String, dynamic>? detailJson;
  final Map<String, dynamic>? openResult;
  final Map<String, dynamic>? completeResult;


  int listReads = 0;
  int opened = 0;
  String? abandonedWith;

  @override
  Future<RelationshipEngagements> forRelationship(String relationshipId) async {
    listReads++;
    return RelationshipEngagements.fromJson(list);
  }

  @override
  Future<EngagementDetail?> detail(String engagementId) async =>
      detailJson == null ? null : EngagementDetail.fromJson(detailJson!);

  @override
  Future<EngagementCommandResult> open({
    required String relationshipId,
    required String purpose,
    String? originNote,
    String? admissionKey,
  }) async {
    opened++;
    return EngagementCommandResult.fromJson(
        openResult ?? {'ok': true, 'created': true, 'engagement': {'id': 'eng-1'}});
  }

  @override
  Future<EngagementCommandResult> complete(String engagementId) async =>
      EngagementCommandResult.fromJson(
          completeResult ?? {'ok': true, 'engagement': {'id': engagementId}});

  @override
  Future<EngagementCommandResult> abandon({
    required String engagementId,
    required String reason,
  }) async {
    abandonedWith = reason;
    return EngagementCommandResult.fromJson(
{'ok': true, 'engagement': {'id': engagementId}});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
