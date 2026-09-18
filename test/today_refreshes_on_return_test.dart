import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orchestrate_app/core/today/client_today.dart';
import 'package:orchestrate_app/data/repositories/client/client_today_repository.dart';
import 'package:orchestrate_app/features/client/screens/today_screen.dart';

/// Returning to Today must ask again.
///
/// Today painted its cached answer on return and never asked the server again,
/// so a business that had just authorised representation came back and was
/// still told "Authorization required". Found filming Getting Started on a
/// fresh workspace. The cached answer may paint first; it must not be the last
/// word.
void main() {
  testWidgets('a cached Today is refreshed when the screen is entered', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // What Today knew before the person left: authorisation still missing.
    ClientToday.instance.seed(const TodayState(
      alerts: [],
      workflow: {},
      eligibility: {
        'bucket': 'client_action_required',
        'blockers': [
          {
            'code': 'AUTHORIZATION_MISSING',
            'label': 'Authorization required',
            'detail': 'Representation authorization is required before outbound outreach can send.',
          },
        ],
      },
      recentMessages: [],
      replies: [],
      unavailable: {},
    ));
    expect(ClientToday.instance.hasAnswer, isTrue);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TodayScreen())));
    await tester.pump();

    // Let the (unreachable, in tests) sources answer so the refresh completes.
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    expect(find.text('Authorization required'), findsNothing,
        reason: 'the stale answer must be replaced by the refreshed one');
    ClientToday.instance.seed(null);
  });
}
