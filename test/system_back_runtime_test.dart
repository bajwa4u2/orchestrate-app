import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orchestrate_app/app/routing/app_router.dart';
import 'package:orchestrate_app/core/attention/client_attention.dart';
import 'package:orchestrate_app/core/commercial/client_capabilities.dart';
import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/market/client_market.dart';
import 'package:orchestrate_app/core/relationships/client_relationships.dart';

/// Does the system Back key actually reach the workspace?
///
/// `WorkspaceBack.parentOf` is unit-tested and correct, and PopScope is wired
/// into all three shells — and on a Pixel, Back still closed the app from
/// Business identity and from Workspace settings. Static reading could not
/// separate "the handler is wrong" from "the handler never runs", and the
/// device answer needed a signed-in session.
///
/// So this drives the real router with a real session and dispatches the same
/// pop the platform dispatches. It answers, without a device, whether the
/// workspace shell's PopScope is consulted at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> signIn() async {
    SharedPreferences.setMockInitialValues({});
    await AuthSessionController.instance.clear();
    await AuthSessionController.instance.applyAuthResponse(<String, dynamic>{
      'token': 'test-token',
      'surface': 'client',
      'user': {
        'id': 'u1',
        'email': 'owner@example.com',
        'fullName': 'An Owner',
        'emailVerified': true,
      },
      'organization': {'id': 'org-1', 'name': 'A Business'},
      'client': {'id': 'client-1', 'displayName': 'A Business'},
      'setup': {'setupCompleted': true},
      'commercial': {'status': 'active'},
    });
    ClientMarket.instance.seed(null, error: 'not asked in this test');
    ClientRelationships.instance.seed(null, error: 'not asked in this test');
    ClientAttention.instance.seed(null, error: 'not asked in this test');
    ClientCapabilities.instance.seed(null, error: 'not asked in this test');
  }

  String where(GoRouter r) =>
      r.routerDelegate.currentConfiguration.uri.path;

  testWidgets('system Back on a workspace surface goes up, not out',
      (tester) async {
    await signIn();
    final r = router;
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    await tester.pump();
    tester.takeException();

    r.go('/client/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    tester.takeException();
    expect(where(r), '/client/settings');

    // The same call the engine makes when Android delivers Back.
    final handled = await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    tester.takeException();

    expect(
      handled,
      isTrue,
      reason: 'nobody claimed Back, so Android would close the app',
    );
    expect(
      where(r),
      isNot('/client/settings'),
      reason: 'Back was claimed but the workspace did not move',
    );
  });

  testWidgets('system Back on the public site is already known to work',
      (tester) async {
    await AuthSessionController.instance.clear();
    SharedPreferences.setMockInitialValues({});
    final r = router;
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    await tester.pump();
    tester.takeException();

    r.go('/pricing');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    tester.takeException();

    final handled = await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    tester.takeException();

    expect(handled, isTrue);
    expect(where(r), '/');
  });
}
