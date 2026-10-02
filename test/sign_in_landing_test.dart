import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WHERE SIGNING IN ACTUALLY PUTS YOU.
///
/// The router's gates were corrected so a business without a plan reaches its
/// workspace. The login screen kept its own copy of the decision and overruled
/// them at the one moment that matters — so every client who signed in without
/// an active subscription was sent to checkout, and everyone else was sent to
/// /app/home: the pre-reconstruction home, rendered inside the new shell with
/// none of its four destinations selected. A page that cannot say where it is.
///
/// The workspace-entry tests never caught it because they drive the router
/// directly. Nothing exercised the screen that runs after a real sign-in.
void main() {
  final login =
      File('lib/features/auth/screens/client_login_screen.dart').readAsStringSync();
  final router = File('lib/app/routing/app_router.dart').readAsStringSync();

  test('signing in lands in the workspace', () {
    final complete = login.substring(login.indexOf('_completeClientAccess('));
    expect(complete.contains("context.go(returnTo ?? '/client/today')"), isTrue);
    expect(complete.contains("'/app/home'"), isFalse);
  });

  test('the login screen does not keep its own subscription gate', () {
    final complete = login.substring(
      login.indexOf('_completeClientAccess('),
      login.indexOf('Future<void> requestPasswordReset()'),
    );
    expect(
      complete.contains('normalizedSubscriptionStatus'),
      isFalse,
      reason: 'payment is a different authority from reaching the workspace',
    );
    expect(complete.contains("'/app/subscribe'"), isFalse);
    // The gate that stays: Orchestrate cannot present a coherent workspace
    // before it knows what the business is.
    // The gate is the same gate; only its spelling was made canonical.
    expect(complete.contains("_route('/client/setup')"), isTrue);
  });

  test('the legacy home and its billing page are retired, not orphaned', () {
    // Once redirected for old links; retired outright on 2 Oct 2026, when no
    // client yet depended on one.
    for (final legacy in <String>['/app/home', '/app/billing']) {
      expect(router.contains("path: '$legacy'"), isFalse, reason: '$legacy is retired');
    }
    expect(router.contains('ClientHomeScreen'), isFalse);
    expect(
      File('lib/features/client/screens/client_workspace_screen.dart').existsSync(),
      isFalse,
      reason: 'the retired screen is deleted, not left unreachable',
    );
  });

  /// AND THE OTHER ORPHANS FOUND ALONGSIDE IT.
  ///
  /// Retiring the legacy home surfaced a whole family of /app/* client screens
  /// the reconstructed IA links to from nowhere. Two of them were worse than
  /// stale: /app/campaigns told a business "Billing: ACTIVE" when it had no
  /// subscription at all, and /app/newsletter was a placeholder whose entire
  /// content was that controls might exist later.
  test('the orphaned legacy client screens are retired', () {
    // /app/campaigns pointed at /client/representation/targeting, which
    // pointed back at /app/campaigns. Each half was defensible alone and the
    // pair rendered nothing: every arrival bounced until the workspace
    // reported no surface was available. Both now land on business identity,
    // which is where the targeting editor actually lives.
    //
    // The destination is pinned here because retirement means arriving
    // somewhere real, not merely resolving. That a destination exists at all,
    // and that no redirect returns to its own origin, is checked across the
    // whole table in router_redirect_integrity_test.
    const retired = <String, String>{
      // DD-34: straight to the new homes, never through a retired page.
      '/app/campaigns': '/client/setup?step=want',
      '/app/activity': '/client/relationships',
      '/app/mailbox': '/client/setup?step=email',
      '/app/newsletter': '/client/today',
    };
    // Retired outright on 2 Oct 2026: not routed at all, and each former
    // destination is still a real page.
    retired.forEach((from, to) {
      expect(router.contains("path: '$from'"), isFalse, reason: '$from is retired');
      expect(router.contains("path: '${to.split('?').first}'"), isTrue,
          reason: '$to must still be a page');
    });
    for (final gone in <String>[
      'lib/features/client/screens/campaigns_screen.dart',
      'lib/features/client/screens/client_activity_screen.dart',
      'lib/features/client/screens/client_newsletter_screen.dart',
    ]) {
      expect(File(gone).existsSync(), isFalse, reason: '$gone is retired');
    }
  });

  // The /app surfaces the Business hub opened (trust, evidence, artifacts,
  // branding, subscribe) are now retired on purpose (DD-34); the guard in
  // navigation_promises_test holds each to its new home.

  test('nothing else points at the retired home', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      if (source.contains("go('/app/home')") || source.contains("go('/app/billing')")) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
