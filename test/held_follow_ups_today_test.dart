import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orchestrate_app/core/today/client_today.dart';
import 'package:orchestrate_app/data/repositories/client/client_held_follow_ups_repository.dart';
import 'package:orchestrate_app/features/client/screens/today_screen.dart';
import 'package:orchestrate_app/core/theme/workspace_theme.dart';

import 'support/held_follow_ups_fixture.dart';

/// Follow-ups Orchestrate holds wait on Today for the owner's yes (26 Oct 2026).
void main() {
  setUpAll(loadAppFonts);

  Future<FakeHeldFollowUps> pumpToday(WidgetTester tester, List<HeldFollowUp> items) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ClientToday.instance.seed(emptyToday);
    final repo = FakeHeldFollowUps(items);
    await tester.pumpWidget(MaterialApp(theme: Ws.data, home: Scaffold(body: TodayScreen(heldFollowUps: repo))));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    addTearDown(() => ClientToday.instance.seed(null));
    return repo;
  }

  testWidgets('each held follow-up is a yes-card with the plain reason and the first note', (tester) async {
    await pumpToday(tester, heldFixture);
    expect(find.text('Write to them again?'), findsNWidgets(heldFixture.length));
    expect(find.text('Kestrel Civil Works'), findsOneWidget);
    expect(find.textContaining('not sure this is the right moment'), findsWidgets);
    expect(find.textContaining('County road work this spring'), findsOneWidget);
    expect(find.textContaining('confidence'), findsNothing);
  });

  testWidgets('Follow up sends that one and the card goes', (tester) async {
    final repo = await pumpToday(tester, heldFixture);
    await tester.tap(find.text('Follow up').first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(repo.sent, [heldFixture.first.id]);
    expect(find.text('Write to them again?'), findsNWidgets(heldFixture.length - 1));
  });

  testWidgets("Don't send ends that one", (tester) async {
    final repo = await pumpToday(tester, heldFixture);
    await tester.tap(find.text("Don't send").first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(repo.declined, [heldFixture.first.id]);
    expect(repo.sent, isEmpty);
  });

  testWidgets('a refusal from the server is said, and the card stays', (tester) async {
    final repo = await pumpToday(tester, heldFixture);
    repo.refuse = 'Only someone who may approve what is sent in your business’s name can decide this.';
    await tester.tap(find.text('Follow up').first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.textContaining('Only someone who may approve'), findsOneWidget);
    expect(find.text('Write to them again?'), findsNWidgets(heldFixture.length));
  });

  testWidgets('nothing held: no follow-up card at all', (tester) async {
    await pumpToday(tester, const []);
    expect(find.text('Write to them again?'), findsNothing);
    expect(find.text('FOLLOW-UP'), findsNothing);
  });
}
