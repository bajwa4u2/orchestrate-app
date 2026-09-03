import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/authority/client_authority.dart';
import 'package:orchestrate_app/features/client/widgets/standing_authority.dart';

/// THE AUTHORITY STATES, RENDERED AND READ.
///
/// A projection that is correct on the wire and misleading on the screen is
/// still a business being told the wrong thing, so these render each state a
/// person can actually be in and assert the words that come out.
///
/// Two of these states production has never been in. That is the point: the
/// first business to establish canonical authority should not be the first
/// reader of the sentence it is shown.
///
/// Each case prints what a person would read, so the states can be inspected
/// rather than only asserted.
void main() {
  AuthorityProjection make({
    String business = 'Northwind Freight LLC',
    bool legalName = true,
    bool established = false,
    int recognisedPeople = 0,
    bool underReview = false,
    String orgMeaning = '',
    bool youRecognised = false,
    String? describedAs,
    String youMeaning = '',
    List<AreaStanding> areas = const [],
    List<String> delegated = const [],
    bool everGranted = false,
    bool legacyOnly = false,
    String orchMeaning = '',
    List<MissingStep> missing = const [],
    Submission submission = const Submission(
      state: SubmissionState.notSubmitted, since: null, asserted: null,
      operatorAsked: null, refusedBecause: null, meaning: '',
    ),
  }) {
    return AuthorityProjection(
      businessName: business,
      legalNameOnRecord: legalName,
      submission: submission,
      organizationEstablished: established,
      recognisedPeople: recognisedPeople,
      underReview: underReview,
      organizationMeaning: orgMeaning,
      youAreRecognised: youRecognised,
      describedAs: describedAs,
      areas: areas.isEmpty ? _threeAreas() : areas,
      youMeaning: youMeaning,
      orchestrateDelegated: delegated,
      orchestrateEverGranted: everGranted,
      orchestrateIsLegacyCommunicationOnly: legacyOnly,
      orchestrateMeaning: orchMeaning,
      missing: missing,
    );
  }

  Future<void> render(WidgetTester tester, String name) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StandingAuthority(onResolve: _noop),
          ),
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

  tearDown(() => ClientAuthority.instance.seed(null));

  testWidgets('1. nobody named — the business has authorised no one', (tester) async {
    ClientAuthority.instance.seed(make(
      orgMeaning: 'Your business has not yet named anyone who may make '
          'agreement or financial decisions.',
      youMeaning: 'Your business has not recognised you as able to decide for '
          'it. Being a member of this workspace is not the same thing.',
      orchMeaning: 'Orchestrate has not been authorised to act for this business.',
      missing: const [
        MissingStep(
          key: 'ORGANIZATION_AUTHORITY',
          say: 'Nobody is named as able to make decisions for the business.',
          because: 'Agreements and invoices are not acted on because someone '
              'is signed in.',
        ),
      ],
    ));
    await render(tester, 'nobody named');

    expect(find.textContaining('has not yet named anyone'), findsOneWidget);
    // Tenancy is not authority, and the screen says so in words.
    expect(find.textContaining('member of this workspace is not the same thing'),
        findsOneWidget);
    // The blocker states what and why, and offers the way out.
    expect(find.textContaining('Nobody is named'), findsOneWidget);
    expect(find.textContaining('not acted on because someone is signed in'),
        findsOneWidget);
    expect(find.text('Sort this out'), findsOneWidget);
    // Nothing congratulatory, nothing scored.
    expect(find.textContaining('%'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('2. under review — waiting on us asks nothing of them', (tester) async {
    ClientAuthority.instance.seed(make(
      underReview: true,
      orgMeaning: 'We are reviewing what your business sent.',
      youMeaning: 'Your business has not recognised you as able to decide for it.',
      orchMeaning: 'Orchestrate has not been authorised to act for this business.',
      // Deliberately empty: someone already waiting on us is asked for nothing.
      missing: const [],
    ));
    await render(tester, 'under review');

    expect(find.textContaining('We are reviewing'), findsOneWidget);
    expect(find.text('Sort this out'), findsNothing);
  });

  testWidgets('3. established, but not you', (tester) async {
    ClientAuthority.instance.seed(make(
      established: true,
      recognisedPeople: 2,
      orgMeaning: 'Your business has named who may make these decisions.',
      youMeaning: 'Your business has not recognised you as able to decide for '
          'it. Being a member of this workspace is not the same thing.',
      missing: const [
        MissingStep(
          key: 'YOU_NOT_RECOGNISED',
          say: 'You are not one of the recognised people.',
          because: 'You can still work here; you cannot personally approve '
              'consequential acts.',
        ),
      ],
    ));
    await render(tester, 'established, not you');

    expect(find.textContaining('has named who may make these decisions'),
        findsOneWidget);
    expect(find.textContaining('You are not one of the recognised people'),
        findsOneWidget);
    // Not framed as being locked out of the product.
    expect(find.textContaining('You can still work here'), findsOneWidget);
  });

  testWidgets('4. recognised for communication only — the other two are shown as absent',
      (tester) async {
    ClientAuthority.instance.seed(make(
      established: true,
      recognisedPeople: 1,
      youRecognised: true,
      describedAs: 'Operations Director',
      orgMeaning: 'Your business has named who may make these decisions.',
      youMeaning: 'Your business has recognised you for the areas below.',
      areas: [
        _area(AuthorityArea.communication, 'Communication', act: true),
        _area(AuthorityArea.contractual, 'Agreements'),
        _area(AuthorityArea.financial, 'Invoices and payments'),
      ],
    ));
    await render(tester, 'communication only');

    // All three areas appear. An area that is simply missing from the list
    // reads as an oversight; an area shown as not held reads as an answer.
    expect(find.textContaining('Communication'), findsWidgets);
    expect(find.textContaining('Agreements'), findsWidgets);
    expect(find.textContaining('Invoices and payments'), findsWidgets);
    expect(find.textContaining('not yours to approve'), findsWidgets);
    // A job title is recorded and governs nothing, and the screen says which.
    expect(find.textContaining('carries no authority by itself'), findsOneWidget);
  });

  testWidgets('5. recognised with the three powers kept separate', (tester) async {
    ClientAuthority.instance.seed(make(
      established: true,
      recognisedPeople: 1,
      youRecognised: true,
      orgMeaning: 'Your business has named who may make these decisions.',
      youMeaning: 'Your business has recognised you for the areas below.',
      areas: [
        // Holds it, may not let Orchestrate do it, may not appoint anyone.
        _area(AuthorityArea.communication, 'Communication', act: true),
        // Holds it and may pass it on, but may not delegate to software.
        _area(AuthorityArea.contractual, 'Agreements',
            act: true, recognise: true),
        _area(AuthorityArea.financial, 'Invoices and payments',
            act: true, delegate: true),
      ],
    ));
    await render(tester, 'three powers, separately');

    expect(find.textContaining('you may approve these'), findsWidgets);
    expect(find.textContaining('you may recognise others'), findsOneWidget);
    expect(find.textContaining('you may let Orchestrate do it'), findsOneWidget);
  });

  testWidgets('6. the legacy grant — production\'s actual state', (tester) async {
    ClientAuthority.instance.seed(make(
      // Six businesses look exactly like this: Orchestrate may send email,
      // and nobody has been named to decide anything.
      legacyOnly: true,
      everGranted: true,
      delegated: const ['EXTERNAL_COMMUNICATION'],
      orgMeaning: 'Your business has not yet named anyone who may make '
          'agreement or financial decisions.',
      youMeaning: 'Your business has not recognised you as able to decide for it.',
      orchMeaning: 'Orchestrate may communicate on your behalf. It may not '
          'agree to anything or handle money.',
      missing: const [
        MissingStep(
          key: 'ORGANIZATION_AUTHORITY',
          say: 'Nobody is named as able to make decisions for the business.',
          because: 'Agreements and invoices are not acted on because someone '
              'is signed in.',
        ),
      ],
    ));
    await render(tester, 'legacy grant only');

    // The two systems are reported as what they are, side by side, and the
    // delegation is never allowed to read as organizational authority.
    expect(find.textContaining('may not agree to anything or handle money'),
        findsOneWidget);
    expect(find.textContaining('has not yet named anyone'), findsOneWidget);
  });

  testWidgets('7. authority could not be read — nothing is assumed', (tester) async {
    ClientAuthority.instance.seed(null, error: StateError('network'));
    await render(tester, 'authority unavailable');

    expect(find.textContaining('could not check what you may do'), findsOneWidget);
    // Unknown is not permitted, and the screen says that outright.
    expect(find.textContaining('left everything that needs authority unavailable'),
        findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });


  // ── The six submission states, which used to be two ───────────────────
  //
  // Before this, a refusal, an unanswered operator question, and never having
  // submitted at all produced the same silence. Someone whose designation was
  // refused would have waited indefinitely for an answer they had already been
  // given.
  for (final (state, expectOnScreen) in <(SubmissionState, String)>[
    (SubmissionState.submitted, 'Your submission is with us'),
    (SubmissionState.moreEvidenceRequested, 'We need something more from you'),
    (SubmissionState.admitted, 'Your submission was admitted'),
    (SubmissionState.refused, 'Your submission was not admitted'),
    (SubmissionState.superseded, 'Replaced by a later submission'),
  ]) {
    testWidgets('submission state ${state.wire} says so', (tester) async {
      ClientAuthority.instance.seed(make(
        submission: Submission(
          state: state,
          since: DateTime(2026, 9, 1),
          asserted: 'Agreements on behalf of Northwind Freight LLC',
          operatorAsked: state == SubmissionState.moreEvidenceRequested
              ? 'Send the board resolution naming you, or a signed letter on '
                  'company letterhead.'
              : null,
          refusedBecause: state == SubmissionState.refused
              ? 'The reference you gave points at a document we cannot see.'
              : null,
          meaning: 'meaning from the backend',
        ),
      ));
      await render(tester, 'submission ${state.wire}');

      expect(find.text(expectOnScreen), findsOneWidget);
      // The operator's own words survive, verbatim, in both directions.
      if (state == SubmissionState.moreEvidenceRequested) {
        expect(find.textContaining('board resolution naming you'), findsOneWidget);
      }
      if (state == SubmissionState.refused) {
        expect(find.textContaining('points at a document we cannot see'),
            findsOneWidget);
        // A refusal that reads as still-pending is the failure this prevents.
        expect(find.textContaining('with us'), findsNothing);
      }
      // What was claimed is shown beside what became of it.
      expect(find.textContaining('Agreements on behalf of'), findsOneWidget);
    });
  }

  testWidgets('never submitted says nothing at all', (tester) async {
    ClientAuthority.instance.seed(make());
    await render(tester, 'never submitted');
    // No submission card, because there is no submission. An empty one would
    // be a form pretending to be a status.
    expect(find.textContaining('Your submission'), findsNothing);
    expect(find.textContaining('Replaced by'), findsNothing);
  });

  testWidgets('every state fits, phone through desktop', (tester) async {
    // The longest sentences in the whole surface, at the narrowest width the
    // product supports. Authority text is written for clarity rather than for
    // fitting, so this is where it would break first.
    ClientAuthority.instance.seed(make(
      established: true,
      recognisedPeople: 1,
      youRecognised: true,
      describedAs: 'Managing Member and Authorised Signatory',
      orgMeaning: 'Your business has named who may make these decisions.',
      youMeaning: 'Your business has recognised you for the areas below.',
      areas: [
        _area(AuthorityArea.communication, 'Communication',
            act: true, delegate: true, recognise: true),
        _area(AuthorityArea.contractual, 'Agreements',
            act: true, delegate: true, recognise: true),
        _area(AuthorityArea.financial, 'Invoices and payments',
            act: true, delegate: true, recognise: true),
      ],
      orchMeaning: 'Orchestrate may communicate on your behalf. It may not '
          'agree to anything or handle money.',
      missing: const [
        MissingStep(
          key: 'BUSINESS_LEGAL_NAME',
          say: 'Your business needs its legal name on record.',
          because: 'Someone can only be recognised as authorised to act for a '
              'named business.',
        ),
      ],
    ));

    for (final size in const [
      Size(360, 900),   // phone
      Size(768, 1024),  // tablet
      Size(1440, 900),  // desktop
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StandingAuthority(onResolve: _noop),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'authority must render without overflow at ${size.width}px');
      expect(find.textContaining('you may approve these'), findsWidgets);
      expect(find.textContaining('legal name on record'), findsOneWidget);
      debugPrint('  ok  ${size.width.toInt()}x${size.height.toInt()} — no overflow');
    }
  });
}

void _noop(String _) {}

AreaStanding _area(
  AuthorityArea area,
  String label, {
  bool act = false,
  bool delegate = false,
  bool recognise = false,
}) =>
    AreaStanding(
      area: area,
      label: label,
      canAct: act,
      canAuthoriseOrchestrate: delegate,
      canRecogniseOthers: recognise,
    );

List<AreaStanding> _threeAreas() => [
      _area(AuthorityArea.communication, 'Communication'),
      _area(AuthorityArea.contractual, 'Agreements'),
      _area(AuthorityArea.financial, 'Invoices and payments'),
    ];
