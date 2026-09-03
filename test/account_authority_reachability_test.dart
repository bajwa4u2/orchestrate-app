import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/authority/client_authority.dart';
import 'package:orchestrate_app/features/client/widgets/standing_authority.dart';

/// CAN A PERSON ACTUALLY REACH THE THING THEY ARE BEING TOLD TO DO.
///
/// On a real production client the standing card, the blocker and the empty
/// state together run past the fold on an ordinary laptop — the actions that
/// resolve the blocker sit below it. A blocker whose remedy cannot be reached
/// is worse than no blocker: it tells someone what is wrong and then hides the
/// only thing that would fix it.
///
/// Live browser verification could not settle this — the extension served a
/// stale frame after the first paint — so it is settled here, in the real
/// widget tree, at the height the screenshot was taken at.
void main() {
  testWidgets('the blocker and its remedy are both reachable below the fold',
      (tester) async {
    // The Google Play Review Account as production actually has it: a legacy
    // communication-only grant, nobody named, one blocker.
    ClientAuthority.instance.seed(const AuthorityProjection(
      businessName: 'Google Play Review Account',
      legalNameOnRecord: true,
      organizationEstablished: false,
      recognisedPeople: 0,
      underReview: false,
      organizationMeaning:
          'Your business has not yet named anyone who may make agreement or '
          'financial decisions.',
      youAreRecognised: false,
      describedAs: null,
      areas: [],
      youMeaning: 'Your business has not recognised you as able to decide for '
          'it. Being a member of this workspace is not the same thing.',
      orchestrateDelegated: ['EXTERNAL_COMMUNICATION'],
      orchestrateEverGranted: true,
      orchestrateIsLegacyCommunicationOnly: true,
      orchestrateMeaning: 'Orchestrate may communicate on your behalf. It may '
          'not agree to anything or handle money.',
      missing: [
        MissingStep(
          key: 'ORGANIZATION_AUTHORITY',
          say: 'Nobody is named as able to make decisions for the business.',
          because:
              'Agreements and invoices are not acted on because someone is '
              'signed in.',
        ),
      ],
    ));
    addTearDown(() => ClientAuthority.instance.seed(null));

    // The viewport the production screenshot was taken at, minus the shell
    // header — the height a person on a laptop actually has.
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var resolved = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // The account layer's own frame is a ListView; this reproduces the
          // scrollable it provides, with a tail long enough to push the
          // actions past the fold as they are in production.
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              StandingAuthority(onResolve: resolved.add),
              const SizedBox(height: 400),
              FilledButton(
                onPressed: () {},
                child: const Text('Name yourself as authorised'),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text('Invite someone'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // The premise: the remedy really is off-screen to begin with.
    expect(find.text('Name yourself as authorised').hitTestable(), findsNothing,
        reason: 'this test is pointless if the action was visible all along');

    // And a person can get to it.
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(find.text('Name yourself as authorised').hitTestable(), findsOneWidget);
    expect(find.text('Invite someone').hitTestable(), findsOneWidget);

    // The blocker's own button works where it sits.
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pump();
    await tester.tap(find.text('Sort this out'));
    expect(resolved, ['ORGANIZATION_AUTHORITY']);
  });
}
