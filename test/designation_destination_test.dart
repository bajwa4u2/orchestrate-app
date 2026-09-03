import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orchestrate_app/app/routing/app_router.dart';
import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/auth/return_path.dart';

/// THE INVITED REPRESENTATIVE'S JOURNEY.
///
/// `ORCH_DESIGNATION_PATH` decides where an invitation email sends a real
/// person. Setting it while the journey is broken sends them to a dead link,
/// which is why the backend refuses to send at all while it is unset — an
/// invitation to do something you cannot do is a broken promise, not an
/// inconvenience.
///
/// So the destination is certified here before that variable is ever set. The
/// invited person is, by definition, not signed in and may belong to a business
/// that has not finished setup — the two conditions that used to bounce them.
void main() {
  const destination = '/account/people';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthSessionController.instance.clear();
    // The router declines to redirect until the session has loaded; without
    // this every case below would pass by doing nothing.
    await AuthSessionController.instance.init();
  });

  Future<GoRouter> mount(WidgetTester tester) async {
    final r = router;
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    await tester.pump();
    return r;
  }

  String location(GoRouter r) =>
      r.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('an unauthenticated arrival keeps where they were going',
      (tester) async {
    final r = await mount(tester);
    r.go(destination);
    await tester.pump();

    final at = Uri.parse(location(r));
    expect(at.path, '/auth/login', reason: 'they must prove who they are first');
    // The destination survives the bounce. Without this the whole journey ends
    // somewhere generic and the invitation is wasted.
    expect(readReturnTo(at.queryParameters), destination);
  });

  testWidgets('signing in lands on the page they were invited to',
      (tester) async {
    final r = await mount(tester);
    r.go(destination);
    await tester.pump();

    // They sign in. The destination is still on the URL they are sitting on.
    final carried = readReturnTo(Uri.parse(location(r)).queryParameters);
    await AuthSessionController.instance.applyAuthResponse({
      'token': 'test-token',
      'session': {'surface': 'client', 'clientId': 'c1', 'organizationId': 'o1'},
      'user': {'email': 'invited@example.test', 'emailVerified': true},
      'setup': {'completed': true},
    });
    r.go(carried!);
    await tester.pump();

    expect(Uri.parse(location(r)).path, destination);
  });

  testWidgets('an unfinished workspace does not bounce them to setup',
      (tester) async {
    // The condition that made this worth checking: authority lives outside the
    // setup gate precisely so an invited representative can establish it before
    // the business has finished configuring anything.
    await AuthSessionController.instance.applyAuthResponse({
      'token': 'test-token',
      'session': {'surface': 'client', 'clientId': 'c1', 'organizationId': 'o1'},
      'user': {'email': 'invited@example.test', 'emailVerified': true},
      'setup': {'completed': false},
    });
    final r = await mount(tester);
    r.go(destination);
    await tester.pump();

    expect(Uri.parse(location(r)).path, destination,
        reason: 'setup is a workspace condition, not an authority condition');
  });

  testWidgets('an unverified address detours and comes back', (tester) async {
    await AuthSessionController.instance.applyAuthResponse({
      'token': 'test-token',
      'session': {'surface': 'client', 'clientId': 'c1', 'organizationId': 'o1'},
      'user': {'email': 'invited@example.test', 'emailVerified': false},
      'setup': {'completed': true},
    });
    final r = await mount(tester);
    r.go(destination);
    await tester.pump();

    final at = Uri.parse(location(r));
    expect(at.path, '/auth/verify-email');
    // Sign-in is not always one hop, and the destination has to survive each.
    expect(readReturnTo(at.queryParameters), destination);
  });

  testWidgets('the destination cannot be pointed off-site', (tester) async {
    // An emailed link is attacker-reachable. A returnTo that could carry
    // someone through our sign-in to a site of its choosing would turn the
    // invitation into an open redirect.
    for (final hostile in const [
      'https://evil.test/steal',
      '//evil.test/steal',
      'javascript:alert(1)',
      '/account/people\nSet-Cookie: x',
    ]) {
      expect(readReturnTo({kReturnToParam: hostile}), isNull,
          reason: '$hostile must not be honoured');
    }
    expect(readReturnTo({kReturnToParam: destination}), destination);
  });
}
