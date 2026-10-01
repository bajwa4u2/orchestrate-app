// THE RETURN LEG, FROM THE URL THE BACKEND ACTUALLY BUILDS.
//
// Production sent people to a bare origin on a host that did not resolve, so a
// mailbox that genuinely connected ended at a browser DNS error. The backend is
// now configured to return to /client/oauth/return — which is what this app's
// own router comment always said it should do.
//
// These take the exact URLs `MailboxOAuthService.appReturnUrl()` emits — same
// route, same query parameters — and drive them through the real router. They
// are the app half of that contract. The provider and callback halves cannot be
// proven here; they need a real mailbox and a real consent.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orchestrate_app/app/routing/app_router.dart';
import 'package:orchestrate_app/core/attention/client_attention.dart';
import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/commercial/client_capabilities.dart';

/// ONE KNOWN EXCEPTION, NAMED — AND NOTHING ELSE.
///
/// The workspace nav rail overflows its row by 16 px in the test harness. It is
/// pre-existing (it reproduces on an unmodified checkout) and has nothing to do
/// with the OAuth return. `workspace_entry_test.dart` already swallows it with
/// a bare `takeException()`; this is the same concession made narrower, because
/// a bare one would also hide a real failure in the screen under test.
///
/// Whether it is live or only an artefact of the harness is genuinely unknown:
/// flutter_test measures text with a fixed-width test font, so 16 px here is
/// not evidence of 16 px in a browser. Recorded as a finding — not fixed here,
/// and not hidden here either.
void discardKnownShellOverflow(WidgetTester tester) {
  final error = tester.takeException();
  if (error == null) return;
  // Matched on the exact signature, not on the widget path: a FlutterError's
  // toString() is only the summary line, and the file reference lives in
  // diagnostics the harness prints but does not carry here. Pinning the pixel
  // count keeps this narrow — a different overflow, anywhere, still fails.
  final isKnownShellOverflow =
      error.toString().trim() == 'A RenderFlex overflowed by 16 pixels on the right.';
  if (!isKnownShellOverflow) {
    // ignore: only_throw_errors
    throw error;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthSessionController.instance.clear();
    await AuthSessionController.instance.init();
    await AuthSessionController.instance.applyAuthResponse({
      'token': 'test-token',
      'session': {'surface': 'client', 'clientId': 'c1', 'organizationId': 'o1'},
      'user': {'email': 'capture@example.test', 'emailVerified': true},
      // The return surface lives inside the workspace, and anyone connecting a
      // mailbox is past setup. The key is `setupCompleted` — `completed` is
      // silently ignored and reads as false, which sends every case to
      // /client/setup instead of the screen under test.
      'setup': {'setupCompleted': true},
    });
    // Seeded as already answered so no screen reaches for the network. What is
    // under test is what the return URL renders, not whether a repository can
    // load inside a harness.
    ClientAttention.instance.seed(null, error: 'not asked in this test');
    ClientCapabilities.instance.seed(null, error: 'not asked in this test');
  });

  Future<GoRouter> open(WidgetTester tester, String location) async {
    final r = router;
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    await tester.pumpAndSettle();
    r.go(location);
    await tester.pumpAndSettle();
    discardKnownShellOverflow(tester);
    return r;
  }

  String location(GoRouter r) =>
      r.routerDelegate.currentConfiguration.uri.toString();

  // DD-27: a mailbox connection belongs to setup's email step, which shows
  // the outcome in plain words; only Google Contacts keeps its own card.
  group('the destination the backend now redirects to', () {
    testWidgets('a successful Google connect returns to the email step',
        (tester) async {
      final r = await open(
        tester,
        '/client/oauth/return?status=success&provider=google'
        '&email=capture%40example.test&mailboxId=mbx_123',
      );
      final at = Uri.parse(location(r));
      expect(at.path, '/client/setup');
      expect(at.queryParameters['step'], 'email');
      expect(at.queryParameters['oauth'], 'success');
    });

    testWidgets('a declined consent returns to the email step with its reason',
        (tester) async {
      final r = await open(
        tester,
        '/client/oauth/return?status=error&provider=google&reason=access_denied',
      );
      final at = Uri.parse(location(r));
      expect(at.path, '/client/setup');
      expect(at.queryParameters['oauth'], 'error');
      expect(at.queryParameters['reason'], 'access_denied');
    });

    testWidgets('the contacts variant keeps its own card', (tester) async {
      await open(
        tester,
        '/client/oauth/return?status=success&provider=google_contacts',
      );
      expect(find.text('Google Contacts is connected.'), findsOneWidget);
      expect(find.text('Go to Customers'), findsOneWidget);
    });
  });
}
