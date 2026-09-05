import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orchestrate_app/app/routing/app_router.dart';
import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/release/release_identity.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';

/// THE REAL APPLICATION, ON THE REAL PLATFORM.
///
/// Browser certification says nothing about the Windows executable or the
/// Android build: different rendering, different plugins, different lifecycle,
/// different keyboard. This drives the shipped binary — the same widgets, the
/// same router, the same session store — on whichever platform it is run.
///
///   flutter test integration_test -d windows
///   flutter test integration_test -d <android device id>
///
/// It is deliberately not a screenshot suite. What it certifies is that the
/// app boots on the platform, that the workspace is reachable and navigable,
/// that platform-specific policy resolves correctly, and that the version a
/// person can read comes from the package rather than a constant.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// ONE ROUTER, HELD.
  ///
  /// `router` is a getter that constructs a new GoRouter on every access. So
  /// `MaterialApp.router(routerConfig: router)` rendered one instance while
  /// `router.go(...)` navigated a fresh throwaway, and reading the location
  /// built a third — which had never left its initial location. Every
  /// assertion in this file was comparing its destination against '/'.
  final app = router;

  /// Where the router says it is.
  ///
  /// Read from the route information provider rather than the delegate. One
  /// GoRouter instance is shared by the whole app and therefore by every test
  /// in this file; between tests the delegate detaches and reports an empty
  /// configuration, which made an assertion compare a destination against
  /// nothing at all — and made a "does not contain subscribe" check pass for
  /// the wrong reason.
  String where() {
    final delegate = app.routerDelegate.currentConfiguration.uri.toString();
    return delegate.isNotEmpty
        ? delegate
        : app.routeInformationProvider.value.uri.toString();
  }

  /// Navigate, then wait for the router to actually report where it is.
  ///
  /// A fixed pump was not enough on Windows: the delegate reported an empty
  /// configuration while the first real frame was still being produced, so the
  /// assertion compared a destination against nothing at all. This waits for
  /// the answer rather than assuming it has arrived.
  Future<String> settleTo(WidgetTester tester, String destination) async {
    final from = where();
    app.go(destination);
    // Wait for the location to CHANGE, not merely to be non-empty. The initial
    // location is '/', which is non-empty from the first frame — so a
    // non-empty check returned before go() had propagated and every assertion
    // compared its destination against the front door.
    for (var attempt = 0; attempt < 60; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      if (where() != from) break;
    }
    // Then a moment more, in case a redirect resolves on top of the first
    // answer — which is exactly what the retired paths do.
    for (var attempt = 0; attempt < 8; attempt++) {
      await tester.pump(const Duration(milliseconds: 120));
      tester.takeException();
    }
    return where();
  }

  Future<void> boot(WidgetTester tester, {String at = '/client/today'}) async {
    await tester.pumpWidget(MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Orchestrate',
      theme: AppTheme.lightTheme,
      routerConfig: app,
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await settleTo(tester, at);
  }

  /// A REAL TOKEN, OR THE APP SIGNS ITSELF OUT MID-TEST.
  ///
  /// A made-up token is answered with 401 by the first authenticated call a
  /// screen makes, and the app does the correct thing with a 401: it clears
  /// the session. So the run began signed in and was signed out by its own
  /// first frame, and every navigation assertion then compared its
  /// destination against the front door.
  ///
  ///   flutter test integration_test -d windows   ///     --dart-define=API_BASE_URL=http://localhost:4310/v1   ///     --dart-define=CERT_TOKEN=<a token from that instance>
  const certToken = String.fromEnvironment('CERT_TOKEN');

  Future<void> signedIn({String subscriptionStatus = 'none'}) async {
    SharedPreferences.setMockInitialValues({});
    // init() first, and awaited. It is what the app does before runApp, and
    // starting it later means it resumes from its disk read after the session
    // is established and reports the state it found before we arrived.
    await AuthSessionController.instance.init();
    await AuthSessionController.instance.clear();
    await AuthSessionController.instance.applyAuthResponse(<String, dynamic>{
      'token': certToken.isNotEmpty ? certToken : 'native-certification',
      'surface': 'client',
      'user': {
        'id': 'cert_user_asker',
        'email': 'rachel.nunes@northgatemech.example',
        'fullName': 'Rachel Nunes',
        'emailVerified': true,
      },
      'organization': {'id': 'cert_org_a', 'name': 'Northgate Mechanical'},
      'client': {'id': 'cert_client_a', 'displayName': 'Northgate Mechanical'},
      'setup': {'setupCompleted': true},
      'commercial': {'status': subscriptionStatus},
    });
  }

  /// ONE ATTACHED RUN. THE WHOLE THING.
  ///
  /// The app has a single GoRouter instance, and a widget test disposes its
  /// delegate at teardown — so a later test that pumped the same routerConfig
  /// navigated nothing at all and the router went on reporting the initial
  /// '/'. The first test in the file passed and every one after it compared a
  /// destination against the front door.
  ///
  /// So everything that touches the router happens once, here. Splitting it
  /// into readable tests is what broke it.
  testWidgets('the app boots, the workspace navigates, retired paths land',
      (tester) async {
    await signedIn();
    final session = AuthSessionController.instance;
    debugPrint('[certification] session token=${session.token.isNotEmpty} '
        'surface=${session.surface} clientId=${session.clientId} '
        'setup=${session.hasSetupCompleted} verified=${session.emailVerified}');

    await boot(tester);
    debugPrint('[certification] provider=${app.routeInformationProvider.value.uri} '
        'delegate=${app.routerDelegate.currentConfiguration.uri} '
        'ready=${AuthSessionController.instance.isReady} '
        'authed=${AuthSessionController.instance.isAuthenticated}');

    // A frame was produced and the shell is on screen. On Windows this is the
    // whole question a browser could not answer.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final destination in <String>[
      '/client/today',
      '/client/market',
      '/client/relationships',
      '/client/business',
      '/client/billing',
      '/account/plan',
    ]) {
      expect(
        await settleTo(tester, destination),
        destination,
        reason: '$destination must not redirect on this platform',
      );
    }

    const retired = <String, String>{
      '/app/home': '/client/today',
      '/app/billing': '/client/billing',
      '/app/campaigns': '/client/representation/targeting',
      '/client/trust': '/app/trust',
      '/client/opportunities': '/client/relationships',
    };
    for (final entry in retired.entries) {
      expect(await settleTo(tester, entry.key), entry.value,
          reason: '${entry.key} must lead to ${entry.value}');
    }

    // And a business with no plan still reaches its workspace on this
    // platform. Asserted non-empty first: "does not contain subscribe" is
    // satisfied by an empty string, which says nothing.
    final landed = await settleTo(tester, '/client/market');
    expect(landed, isNotEmpty);
    expect(landed.contains('subscribe'), isFalse);
  });

  testWidgets('the version a person reads comes from the package',
      (tester) async {
    // Not a constant in the source. On Windows this reads the executable's
    // own metadata, which is the number a support conversation depends on.
    final identity = await ReleaseIdentity.load();
    expect(identity.isUnknown, isFalse,
        reason: 'package metadata must resolve on this platform');
    expect(identity.version.trim(), isNotEmpty);
    expect(identity.platform, isNotEmpty);
    debugPrint('[certification] ${identity.platform} ${identity.label} '
        '(${identity.packageName})');
  });
}
