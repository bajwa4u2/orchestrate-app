/// iOS App Store routing policy (App Store Guideline 3.1.1).
///
/// The iOS build is an operational client workspace for *existing*
/// customers only. The entire customer-acquisition journey — account
/// registration / create workspace, onboarding/setup, plan selection,
/// trial selection, subscription & billing activation, external checkout,
/// and the public commercial/marketing site — is unreachable on iOS.
/// Commercial acquisition and billing live on the web platform.
///
/// This file is the single source of truth for that policy. It is kept
/// free of Flutter / session / I/O dependencies so it can be unit-tested
/// route-by-route. The router consults it only when the running build is
/// the native iOS App Store binary (`isIosAppStorePlatform`), so web /
/// Android / desktop routing is completely unchanged.
library;

/// Routes that constitute the customer-acquisition / onboarding journey.
/// Unreachable on iOS.
const Set<String> kIosAcquisitionRoutes = <String>{
  // registration / create workspace
  '/auth/join',
  '/join',
  '/signup',
  '/client/join',
  '/client/signup',
  // onboarding / setup
  '/app/setup',
  '/client/setup',
  // plan / trial / subscription activation
  '/app/subscribe',
  '/client/subscribe',
  // commercial acquisition marketing
  '/pricing',
};

/// The only routes an *unauthenticated* iOS user may reach: the
/// operational sign-in surface (+ email verification / password reset),
/// the operator sign-in, and legally/operationally required
/// informational pages. Everything else — the public marketing site and
/// every acquisition surface — resolves to operational sign-in.
const Set<String> kIosUnauthenticatedAllowedRoutes = <String>{
  '/auth/login',
  '/auth/verify-email',
  '/auth/reset-password',
  '/login',
  '/forgot-password',
  '/reset-password',
  '/verify-email',
  '/client/login',
  '/client/verify-email',
  '/client/reset-password',
  '/ops/login',
  '/ops/join',
  '/ops-login',
  '/ops-join',
  '/account-deletion',
  '/contact',
  '/intake',
  '/terms',
  '/privacy',
  '/legal/terms',
  '/legal/privacy',
  '/legal/billing',
  '/legal/refunds',
  '/legal/acceptable-use',
  '/legal/service-agreement',
  '/legal/deliverability',
  '/legal/mailbox-access',
  '/legal/ai-usage',
  '/legal/credentials',
  '/legal/reply-monitoring',
  '/legal/suppression',
  '/legal/providers',
  '/legal/abuse',
  '/legal/retention',
};

/// Pure iOS routing decision. Returns the redirect target for the iOS
/// build, or `null` to allow the route as-is.
///
/// This is the *complete* iOS policy: when the caller is on iOS it
/// short-circuits the web onboarding/subscription gates entirely, so an
/// unsubscribed / onboarding account is never funnelled toward
/// `/app/setup` → `/app/subscribe` → external checkout.
///
/// Reachable on iOS:
///   • unauthenticated → sign-in (+ verify/reset) and informational
///     pages only (see [kIosUnauthenticatedAllowedRoutes]);
///   • authenticated client → the operational workspace (home,
///     opportunities, operations, replies, meetings, infrastructure,
///     representation, records, settings, and read-only billing/account);
///   • authenticated operator → the operator console.
///
/// Callers must guard with `isIosAppStorePlatform`.
String? iosRouteRedirect({
  required String path,
  required bool isAuthenticated,
  required String surface,
  required bool emailVerified,
  required bool isOperatorArea,
  required bool isOpsAuth,
  required bool isClientAuth,
  required bool isVerification,
  required bool isReset,
}) {
  if (!isAuthenticated) {
    if (isOperatorArea) return '/ops/login';
    if (isVerification || isReset) return null;
    // Sign-in + informational pages only; the marketing site and every
    // acquisition surface (including '/') resolve to operational sign-in.
    if (kIosUnauthenticatedAllowedRoutes.contains(path)) return null;
    return '/auth/login';
  }

  if (surface == 'operator') {
    if (isOpsAuth || path == '/') return '/ops/overview';
    if (path.startsWith('/app/')) return '/ops/overview';
    if (path.startsWith('/auth/')) return '/ops/overview';
    if (path.startsWith('/client/')) return '/ops/overview';
    // Keep operators out of the acquisition/marketing funnel too.
    if (kIosAcquisitionRoutes.contains(path)) return '/ops/overview';
    return null;
  }

  if (surface == 'client') {
    if (!emailVerified) {
      if (isVerification || isReset) return null;
      return '/auth/verify-email';
    }
    // Existing customers — subscribed or not — land in the operational
    // workspace. No setup/subscribe funnel. Acquisition surfaces, the
    // auth/marketing entry points, and the operator area resolve home;
    // every other (operational) client route is allowed as-is.
    if (kIosAcquisitionRoutes.contains(path) ||
        isClientAuth ||
        isOpsAuth ||
        path == '/' ||
        path.startsWith('/ops/')) {
      return '/client/today';
    }
    return null;
  }

  return null;
}
