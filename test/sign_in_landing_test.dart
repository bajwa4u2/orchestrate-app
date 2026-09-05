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
    expect(complete.contains("_route('/app/setup')"), isTrue);
  });

  test('the legacy home and its billing page are retired, not orphaned', () {
    for (final legacy in <String>['/app/home', '/app/billing']) {
      final at = router.indexOf("path: '$legacy'");
      expect(at, greaterThan(-1), reason: '$legacy must still resolve');
      // Redirected rather than rendered — the paths are in old links.
      expect(router.substring(at, at + 200).contains('redirect:'), isTrue,
          reason: '$legacy must not render the legacy screen');
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
    const retired = <String, String>{
      '/app/campaigns': '/client/representation/targeting',
      '/app/activity': '/client/relationships',
      '/app/mailbox': '/client/infrastructure',
      '/app/newsletter': '/client/business',
    };
    retired.forEach((from, to) {
      final at = router.indexOf("path: '$from'");
      expect(at, greaterThan(-1), reason: '$from must still resolve');
      expect(router.substring(at, at + 220).contains("'$to'"), isTrue,
          reason: '$from must lead to $to');
    });
    for (final gone in <String>[
      'lib/features/client/screens/campaigns_screen.dart',
      'lib/features/client/screens/client_activity_screen.dart',
      'lib/features/client/screens/client_newsletter_screen.dart',
    ]) {
      expect(File(gone).existsSync(), isFalse, reason: '$gone is retired');
    }
  });

  /// The screens that stayed are the ones the Business hub actually opens.
  test('the linked /app surfaces are not retired by mistake', () {
    for (final kept in <String>['/app/trust', '/app/evidence', '/app/artifacts',
        '/app/branding', '/app/setup', '/app/subscribe']) {
      final at = router.indexOf("path: '$kept'");
      expect(at, greaterThan(-1), reason: '$kept must exist');
      // builder: or pageBuilder: — the workspace routes were converted to
      // NoTransitionPage so the content area stops animating between screens.
      // What matters here is that they render rather than redirect.
      // Bounded by the next route, not by a character count — a fixed window
      // spilled into the following GoRoute, which is a redirect, and read as
      // this one having been retired.
      final next = router.indexOf('GoRoute(', at);
      final decl = router.substring(at, next == -1 ? at + 260 : next);
      expect(decl.contains('uilder:'), isTrue,
          reason: '$kept is a real surface and must still render');
      expect(decl.contains('redirect:'), isFalse,
          reason: '$kept must not have been retired');
    }
  });

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
