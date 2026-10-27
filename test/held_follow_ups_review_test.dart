import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orchestrate_app/core/theme/workspace_theme.dart';
import 'package:orchestrate_app/core/today/client_today.dart';
import 'package:orchestrate_app/features/client/screens/today_screen.dart';

import 'support/held_follow_ups_fixture.dart';

/// Review pictures of held follow-ups on Today, for the founder. Runs only when
/// ORCH_HELD_SHOTS names a folder to write them to.
void main() {
  final dir = Platform.environment['ORCH_HELD_SHOTS'];
  setUpAll(loadAppFonts);

  Future<void> shot(WidgetTester tester, Size size, String name, {bool open = false}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    ClientToday.instance.seed(emptyToday);
    final key = GlobalKey();
    final pad = size.width < 600 ? 16.0 : 40.0;
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Ws.data,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 28, pad, 0),
              child: TodayScreen(heldFollowUps: FakeHeldFollowUps(heldFixture)),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    if (open) {
      await tester.tap(find.text('Read the first note').first);
      await tester.pumpAndSettle();
    }
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
    ClientToday.instance.seed(null);
  }

  testWidgets('desktop 1440x900', (t) => shot(t, const Size(1440, 900), 'today_held_1440x900'), skip: dir == null);
  testWidgets('desktop 1440x900, one read in full', (t) => shot(t, const Size(1440, 900), 'today_held_1440x900_open', open: true), skip: dir == null);
  testWidgets('phone 390x844', (t) => shot(t, const Size(390, 844), 'today_held_390x844'), skip: dir == null);
  testWidgets('phone 390x844, one read in full', (t) => shot(t, const Size(390, 844), 'today_held_390x844_open', open: true), skip: dir == null);
}
