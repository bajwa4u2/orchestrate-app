import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/core/platform/ios_route_policy.dart';

/// Route-by-route validation of the iOS App Store routing policy
/// (Guideline 3.1.1). Proves:
///   1. A new / unauthenticated user on iOS cannot reach any
///      acquisition surface (registration, onboarding, plan, trial,
///      subscription, billing activation, checkout, marketing).
///   2. An onboarding (unsubscribed) reviewer account cannot reach the
///      acquisition funnel.
///   3. A subscribed reviewer account keeps full operational access.
///
/// The helper mirrors how app_router.dart derives its flags from the
/// path, then calls the same pure [iosRouteRedirect] the router uses.
String? resolve(
  String path, {
  required bool isAuthenticated,
  String surface = 'client',
  bool emailVerified = true,
}) {
  final isClientAuth = const {
    '/auth/login',
    '/auth/join',
    '/login',
    '/join',
    '/client/login',
    '/client/join',
  }.contains(path);
  final isOpsAuth = const {
    '/ops/login',
    '/ops/join',
    '/ops-login',
    '/ops-join',
  }.contains(path);
  final isVerification =
      const {'/auth/verify-email', '/client/verify-email'}.contains(path);
  final isReset =
      const {'/auth/reset-password', '/client/reset-password'}.contains(path);
  final isOperatorArea =
      (path.startsWith('/ops/') || path.startsWith('/operator/')) && !isOpsAuth;

  return iosRouteRedirect(
    path: path,
    isAuthenticated: isAuthenticated,
    surface: surface,
    emailVerified: emailVerified,
    isOperatorArea: isOperatorArea,
    isOpsAuth: isOpsAuth,
    isClientAuth: isClientAuth,
    isVerification: isVerification,
    isReset: isReset,
  );
}

void main() {
  // The acquisition surfaces Apple flagged. None may be reachable on iOS.
  const acquisitionRoutes = <String>[
    '/auth/join',
    '/join',
    '/signup',
    '/client/join',
    '/client/signup',
    '/app/setup',
    '/client/setup',
    '/app/subscribe',
    '/client/subscribe',
    '/pricing',
  ];

  // Public marketing routes that fronted the funnel.
  const marketingRoutes = <String>[
    '/',
    '/product',
    '/how-it-works',
    '/ai-governed-revenue',
    '/lead-sourcing',
    '/trust-compliance',
    '/about',
    '/activation',
    '/for-evaluators',
    '/why-orchestrate',
    '/how-orchestrate-operates',
    '/journey/evaluate_and_activate',
  ];

  // Operational workspace routes a subscribed customer uses.
  const operationalRoutes = <String>[
    '/app/home',
    '/client/overview',
    '/client/opportunities',
    '/client/operations',
    '/client/replies',
    '/client/meetings',
    '/client/infrastructure',
    '/client/representation',
    '/client/records',
    '/client/notifications',
    '/client/settings',
    '/client/support',
    '/client/account',
    '/client/billing', // informational on iOS (portal CTA already gated)
    '/app/contacts',
    '/app/campaigns',
    '/app/activity',
  ];

  group('Account 1 — new / unauthenticated user on iOS', () {
    test('every acquisition route resolves to sign-in', () {
      for (final r in acquisitionRoutes) {
        expect(resolve(r, isAuthenticated: false), '/auth/login',
            reason: 'acquisition route $r must be blocked pre-login');
      }
    });

    test('every marketing route resolves to sign-in', () {
      for (final r in marketingRoutes) {
        expect(resolve(r, isAuthenticated: false), '/auth/login',
            reason: 'marketing route $r must not be reachable pre-login');
      }
    });

    test('sign-in and informational pages remain reachable', () {
      for (final r in const [
        '/auth/login',
        '/auth/verify-email',
        '/auth/reset-password',
        '/legal/terms',
        '/legal/privacy',
        '/account-deletion',
        '/contact',
      ]) {
        expect(resolve(r, isAuthenticated: false), isNull,
            reason: '$r must stay reachable pre-login');
      }
    });

    test('operational deep links require sign-in first', () {
      for (final r in operationalRoutes) {
        expect(resolve(r, isAuthenticated: false), '/auth/login',
            reason: 'operational deep link $r requires auth on iOS');
      }
    });
  });

  group('Account 2 — onboarding (unsubscribed) reviewer on iOS', () {
    // reviewer-expired@orchestrateops.com: authenticated client, verified,
    // not subscribed. Must NOT be funnelled into acquisition.
    test('acquisition routes resolve to the operational home (no funnel)',
        () {
      for (final r in acquisitionRoutes) {
        expect(resolve(r, isAuthenticated: true), '/app/home',
            reason: '$r must not start an acquisition funnel on iOS');
      }
    });

    test('the marketing landing and acquisition surfaces resolve to home', () {
      // The funnel entry ("/") and every acquisition surface redirect to
      // the operational home. Deeper marketing *content* pages carry no
      // checkout and are not linked from the authenticated workspace UI,
      // so they are allowed-but-UI-unreachable (kept minimal per the
      // review-path-separation scope).
      expect(resolve('/', isAuthenticated: true), '/app/home');
      for (final r in acquisitionRoutes) {
        expect(resolve(r, isAuthenticated: true), '/app/home');
      }
    });

    test('operational routes are reachable as-is (no setup/subscribe gate)',
        () {
      for (final r in operationalRoutes) {
        expect(resolve(r, isAuthenticated: true), isNull,
            reason: '$r must be reachable without a subscription gate');
      }
    });
  });

  group('Account 3 — subscribed reviewer on iOS (no degradation)', () {
    // reviewer@orchestrateops.com: authenticated client, verified,
    // subscribed. Same policy → full operational access retained.
    test('all operational routes reachable', () {
      for (final r in operationalRoutes) {
        expect(resolve(r, isAuthenticated: true), isNull);
      }
    });

    test('acquisition surfaces still resolve away (not needed in-app)', () {
      for (final r in acquisitionRoutes) {
        expect(resolve(r, isAuthenticated: true), '/app/home');
      }
    });
  });

  group('Operator on iOS', () {
    test('acquisition + marketing resolve to operator console', () {
      for (final r in [...acquisitionRoutes, '/']) {
        expect(resolve(r, isAuthenticated: true, surface: 'operator'),
            '/ops/overview');
      }
    });

    test('operator console reachable', () {
      expect(resolve('/ops/overview', isAuthenticated: true, surface: 'operator'),
          isNull);
    });
  });

  group('Unverified client on iOS', () {
    test('routed to email verification, never to acquisition', () {
      expect(
        resolve('/app/home', isAuthenticated: true, emailVerified: false),
        '/auth/verify-email',
      );
      expect(
        resolve('/app/subscribe', isAuthenticated: true, emailVerified: false),
        '/auth/verify-email',
      );
      expect(
        resolve('/auth/verify-email',
            isAuthenticated: true, emailVerified: false),
        isNull,
      );
    });
  });
}
