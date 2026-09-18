// A PERSON CAN LEAVE.
//
// Setup sits outside the client shell, correctly — it is a focused flow with
// its own header and its own journey rail, and nesting it in the workspace
// chrome produced two headers around one form. The cost was that it had no
// sidebar, and therefore no sign-out: somebody who signed in as the wrong
// account, or who simply did not want to continue, could close the tab or
// clear site data. That was the whole list.
//
// The header's one control now depends on whether a session exists. Signed
// out it offers the public site; signed in it offers the way out. These tests
// hold both halves, and the widths — because the bar that carries the control
// overflowed by 149 px on a phone, and a control that is off the screen is not
// an exit either.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orchestrate_app/app/routing/app_router.dart';
import 'package:orchestrate_app/core/auth/auth_session.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthSessionController.instance.clear();
    // The router declines to redirect until the session has loaded.
    await AuthSessionController.instance.init();
  });

  Future<void> signIn({required bool setupCompleted}) {
    return AuthSessionController.instance.applyAuthResponse({
      'token': 'test-token',
      'session': {'surface': 'client', 'clientId': 'c1', 'organizationId': 'o1'},
      'user': {'email': 'capture@example.test', 'emailVerified': true},
      // `setupCompleted` is the key the session actually reads.
      'setup': {'setupCompleted': setupCompleted},
    });
  }

  Future<GoRouter> mount(WidgetTester tester) async {
    final r = router;
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    await tester.pumpAndSettle();
    return r;
  }

  String location(GoRouter r) =>
      r.routerDelegate.currentConfiguration.uri.toString();

  group('the exit a signed-in person has from setup', () {
    testWidgets('setup offers sign out, not a link that bounces them back',
        (tester) async {
      await signIn(setupCompleted: false);
      final r = await mount(tester);
      r.go('/client/setup');
      await tester.pumpAndSettle();

      expect(location(r), '/client/setup');
      expect(find.text('Sign out'), findsOneWidget,
          reason: 'setup is outside the shell, so this is the only way out');
      // "Back to site" was a dead control here: the router sends an
      // authenticated client with unfinished setup from / straight back to
      // /client/setup, so the button returned them to where they already were.
      expect(find.text('Back to site'), findsNothing);
    });

    testWidgets('a signed-out visitor still gets the public site', (tester) async {
      final r = await mount(tester);
      r.go('/auth/login');
      await tester.pumpAndSettle();

      expect(find.text('Back to site'), findsOneWidget);
      expect(find.text('Sign out'), findsNothing,
          reason: 'there is no session to leave');
    });

    testWidgets('signing out clears the session and lands on sign in',
        (tester) async {
      await signIn(setupCompleted: false);
      final r = await mount(tester);
      r.go('/client/setup');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      // The server call cannot succeed in a test, and that is the case worth
      // holding: being unable to reach the server must never strand somebody
      // signed in on a machine they are trying to leave.
      expect(AuthSessionController.instance.isAuthenticated, isFalse);
      expect(location(r), '/auth/login');
    });

    testWidgets('and coming back does not resume the session', (tester) async {
      await signIn(setupCompleted: false);
      final r = await mount(tester);
      r.go('/client/setup');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      // Re-reading persisted state is what a fresh tab does.
      await AuthSessionController.instance.init();
      expect(AuthSessionController.instance.isAuthenticated, isFalse,
          reason: 'the stored session must be gone, not just forgotten in memory');

      r.go('/client/setup');
      await tester.pumpAndSettle();
      expect(location(r).startsWith('/auth/'), isTrue,
          reason: 'setup is not reachable again without signing in');
    });
  });

  group('setup fits the screen it is on', () {
    for (final size in <Size>[
      const Size(400, 900), // phone
      const Size(800, 600), // the default test viewport
      const Size(1440, 900), // desktop, the capture width
    ]) {
      testWidgets('no overflow at ${size.width.toInt()} wide', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await signIn(setupCompleted: false);
        final r = await mount(tester);
        r.go('/client/setup');
        await tester.pumpAndSettle();

        // A layout overflow throws during paint, so reaching here having
        // settled is the assertion. Named anyway, so a failure says what broke:
        // at 400 px the header ran off by 149 px and the industry field by 150.
        expect(location(r), '/client/setup');
        expect(tester.takeException(), isNull,
            reason: 'setup must render without overflow at ${size.width}');
      });
    }
  });
}
