import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orchestrate_app/app/routing/app_router.dart';
import 'package:orchestrate_app/core/attention/client_attention.dart';
import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/market/client_market.dart';
import 'package:orchestrate_app/core/relationships/client_relationships.dart';

/// A WORKSPACE IS NOT SOMETHING YOU BUY YOUR WAY INTO.
///
/// A gate used to redirect any organisation without an active or trialing
/// subscription to `/app/subscribe` from everywhere outside a twelve-route
/// allow-list. Today, Market, Relationships and Inbound were all unreachable —
/// so a business that had signed up, verified its email and finished setup
/// could not see the workspace it had just built.
///
/// It was worse on iOS, where every purchase CTA is hidden for App Store
/// §3.1.1: an iPhone user with no plan was redirected to a screen telling them
/// to go and use the website.
///
/// Four questions, and only the first two may decide whether someone reaches
/// their workspace. These pin that.
void main() {
  /// Signed in through `applyAuthResponse` — the same path a real login takes.
  /// Seeding the preference store directly would test a door nobody uses.
  Future<void> signIn({
    required bool setupCompleted,
    required String subscriptionStatus,
  }) async {
    SharedPreferences.setMockInitialValues({});
    // Cleared first. `applyAuthResponse` merges forward from the previous
    // session by design, so without this a later case inherits an earlier
    // one's completed setup and the gate under test never fires.
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
      'setup': {'setupCompleted': setupCompleted},
      'commercial': {'status': subscriptionStatus},
    });

    // After sign-in, not before: each seed stamps the client id it was seeded
    // for, and one seeded against an empty session is discarded and refetched.
    // Seeded as "already answered" so no screen reaches for the network — the
    // question here is where the router sends a person, and a repository
    // failing in a test harness is a different layer's noise.
    ClientMarket.instance.seed(null, error: 'not asked in this test');
    ClientRelationships.instance.seed(null, error: 'not asked in this test');
    ClientAttention.instance.seed(null, error: 'not asked in this test');
  }

  /// Mounts the router only. Screens fetch from the network as soon as they
  /// build, so anything they throw is swallowed deliberately: this file asks
  /// where a person is sent, not whether the destination could load its data.
  Future<GoRouter> mount(WidgetTester tester) async {
    final r = router;
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    await tester.pump();
    tester.takeException();
    return r;
  }

  String location(GoRouter r) =>
      r.routerDelegate.currentConfiguration.uri.toString();

  /// A signed-in client whose setup is done and who has never paid.
  Future<void> signedInWithoutPlan({String subscriptionStatus = 'none'}) =>
      signIn(setupCompleted: true, subscriptionStatus: subscriptionStatus);

  testWidgets('a new organisation with no plan reaches its workspace',
      (tester) async {
    await signedInWithoutPlan();
    final r = await mount(tester);

    for (final destination in <String>[
      '/client/today',
      '/client/market',
      '/client/relationships',
      '/client/inbound',
      '/client/business',
    ]) {
      r.go(destination);
      await tester.pump();
      tester.takeException();
      expect(location(r), destination,
          reason: '$destination must not redirect to checkout — a workspace '
              'that requires payment to enter was never the customer\'s');
    }
  });

  testWidgets('a lapsed organisation keeps everything it built', (tester) async {
    // The distinction that matters: a business that operated Orchestrate and
    // stopped paying is not a stranger. Its history is still its own.
    for (final lapsed in <String>['canceled', 'expired', 'past_due', 'paused']) {
      await signedInWithoutPlan(subscriptionStatus: lapsed);
      final r = await mount(tester);

      r.go('/client/relationships');
      await tester.pump();
      tester.takeException();
      expect(location(r), '/client/relationships',
          reason: '$lapsed must not hide the relationships they built');

      r.go('/client/today');
      await tester.pump();
      tester.takeException();
      expect(location(r), '/client/today');
    }
  });

  testWidgets('plan and billing stay reachable in every state', (tester) async {
    // Never gated, in any direction. An organisation that cannot reach billing
    // cannot fix the thing being complained about.
    for (final status in <String>['none', 'canceled', 'past_due', 'active']) {
      await signedInWithoutPlan(subscriptionStatus: status);
      final r = await mount(tester);

      r.go('/account/plan');
      await tester.pump();
      tester.takeException();
      expect(location(r), '/account/plan', reason: 'billing must be reachable ($status)');
    }
  });

  testWidgets('setup is still required before the workspace, and payment is not',
      (tester) async {
    // The one gate that stays. Orchestrate genuinely cannot present a coherent
    // workspace before it knows what the business is — that is product
    // onboarding, which is a different authority from commercial activation.
    await signIn(setupCompleted: false, subscriptionStatus: 'none');
    final r = await mount(tester);

    r.go('/client/market');
    await tester.pump();
      tester.takeException();
    expect(location(r).startsWith('/app/setup'), isTrue,
        reason: 'onboarding still gates; checkout no longer does');
  });

  testWidgets('nothing routes anyone to checkout any more', (tester) async {
    await signedInWithoutPlan();
    final r = await mount(tester);

    for (final destination in <String>[
      '/client/today',
      '/client/market',
      '/client/relationships',
      '/client/business',
      '/account/plan',
    ]) {
      r.go(destination);
      await tester.pump();
      tester.takeException();
      expect(location(r).contains('subscribe'), isFalse,
          reason: 'no destination may bounce a signed-in business to checkout');
    }
  });
}
