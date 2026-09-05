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
