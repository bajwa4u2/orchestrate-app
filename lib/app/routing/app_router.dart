import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/features/auth/screens/client_login_screen.dart';
import 'package:orchestrate_app/features/auth/screens/ops_login_screen.dart';
import 'package:orchestrate_app/core/auth/return_path.dart';
import 'package:orchestrate_app/core/navigation/workspace_map.dart';
import 'package:orchestrate_app/features/client/screens/account_layer_screen.dart';
import 'package:orchestrate_app/features/client/screens/attention_screen.dart';
import 'package:orchestrate_app/features/client/screens/market_screen.dart';
import 'package:orchestrate_app/features/client/screens/relationships_workspace_screen.dart';
import 'package:orchestrate_app/features/client/screens/today_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_authorised_people_screen.dart';
import 'package:orchestrate_app/features/client/setup/one_path_setup_screen.dart';
import 'package:orchestrate_app/features/client/money/money_screen.dart';
import 'package:orchestrate_app/features/public/b/public_b.dart';
import 'package:orchestrate_app/features/client/screens/client_notifications_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_outreach_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_records_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_replies_screen.dart';
import 'package:orchestrate_app/features/client/screens/leads_screen.dart';
import 'package:orchestrate_app/features/operator/screens/inquiry_detail_screen.dart';
import 'package:orchestrate_app/features/operator/screens/audit_timeline_screen.dart';
import 'package:orchestrate_app/features/client/screens/meetings_screen.dart';
import 'package:orchestrate_app/features/client/screens/client_support_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_backend_surface_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_debug_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_governance_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_system_doctor_screen.dart';
import 'package:orchestrate_app/features/operator/screens/operator_workspace_screen.dart';
import 'package:orchestrate_app/features/public/screens/contact_screen.dart';
import 'package:orchestrate_app/features/public/screens/commercial_model_screen.dart';
import 'package:orchestrate_app/features/client/screens/oauth_return_screen.dart';
import 'package:orchestrate_app/features/public/screens/public_diagnostics_screen.dart';
import 'package:orchestrate_app/features/public/screens/public_content_screen.dart';
import 'package:orchestrate_app/features/public/widgets/execution_visual_chapters.dart';
import 'package:orchestrate_app/features/public/screens/public_home_screen.dart';
import 'package:orchestrate_app/app/shell/operator_shell.dart';
import 'package:orchestrate_app/app/shell/client_shell.dart';
import 'package:orchestrate_app/app/shell/public_shell.dart';
import 'package:orchestrate_app/features/ops_console/ops_work_queue_screen.dart';
import 'package:orchestrate_app/features/ops_console/ops_dispatch_screen.dart';
import 'package:orchestrate_app/features/ops_console/ops_transport_screen.dart';
import 'package:orchestrate_app/features/ops_console/ops_clients_screen.dart';
import 'package:orchestrate_app/features/ops_console/ops_campaigns_screen.dart';
import 'package:orchestrate_app/features/ops_console/ops_inventory_screen.dart';
import 'package:orchestrate_app/features/ops_console/ops_jobs_screen.dart';
import 'package:orchestrate_app/features/ops_console/ops_history_screen.dart';
import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/core/platform/billing_gate.dart';
import '../../features/feedback/feedback_screen.dart';
import '../../features/feedback/feedback_queue_screen.dart';
import 'package:orchestrate_app/features/ops_console/ops_authority_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _clientShellNavigatorKey = GlobalKey<NavigatorState>();
final _operatorShellNavigatorKey = GlobalKey<NavigatorState>();

const _clientCoreRoutes = <String>{
  '/app/home',
  '/app/campaigns',
  '/app/activity',
  '/app/mailbox',
  '/app/newsletter',
  '/app/branding',
  '/app/trust',
  '/app/evidence',
  '/app/artifacts',
  '/app/billing',
  '/app/account',
  '/app/setup',
  '/app/subscribe',
};

/// Operator surfaces that no longer exist.
///
/// Each was reachable only by typing a URL, so the only links to them are
/// bookmarks. They resolve to the work queue rather than to a dead end.
const _retiredOperatorSurfaces = <String>{
  '/ops/adaptation',
  // A SECOND MENU IS NOT A SURFACE.
  //
  // "System & tools" was a grid of twelve cards. Eight of them pointed at
  // routes retired with the rest of the estate and silently redirected here,
  // so pressing "Runtime Truth" landed on the work queue with no explanation.
  // The four that still resolved — audit history, message provenance, system
  // doctor, backend surfaces — are all in the sidebar already. It offered
  // nothing the navigation did not, plus eight dead ends, and it announced in
  // its own words that it supported no operational actions.
  '/ops/system',
  '/ops/overview',
  '/ops/cognition',
  '/ops/continuity',
  '/ops/runtime-truth',
  '/ops/trust-readiness',
  '/ops/platform-supervision',
  '/ops/governance/ai-approvals',
  '/ops/overview-legacy',
};

const _clientCanonicalRoutes = <String>{
  '/client',
  '/client/overview',
  '/client/setup',
  '/client/subscribe',
  '/client/workspace',
  // New operational IA — these are the canonical paths.
  '/client/relationships',
  '/client/operations',
  '/client/opportunities',
  '/client/infrastructure',
  '/client/representation',
  // The reconstructed workspace: three destinations plus the account layer.
  '/client/today',
  '/client/market',
  // Inbound is an Attention view reached from Today, not a top-level
  // destination. Quarantine is a system condition, not a product domain a
  // business should have to learn the name of.
  '/client/inbound',
  '/client/business',
  '/client/authorised-people',
  '/account',
  '/account/people',
  '/account/plan',
  '/account/security',
  // Legacy paths kept so deep links keep resolving via redirects.
  '/client/contacts',
  '/client/leads',
  '/client/outreach',
  '/client/mailbox',
  '/client/business-identity',
  '/client/campaign',
  '/client/campaign/targeting',
  '/client/campaigns',
  '/client/replies',
  '/client/meetings',
  '/client/billing',
  '/client/records',
  '/client/invoices',
  '/client/receipts',
  '/client/agreements',
  '/client/statements',
  '/client/reminders',
  '/client/notifications',
  '/client/support',
  '/client/settings',
  '/client/account',
  '/client/help',
  '/client/trust',
  '/client/oauth/return',
};

// Imperative public navigation uses `push` so browser Back traverses the
// visitor's real journey. GoRouter 14 defaults to keeping imperative pushes
// out of the web address bar; enable its canonical web URL projection at the
// router authority so the visible page and durable URL cannot diverge.
/// A router.
///
/// Deliberately NOT a cached singleton. Caching it here made the whole test
/// suite share one GoRouter across tests, so a second test pumping the app got
/// the first one's disposed router — green alone, red in the suite. The app
/// holds its own instance for its own lifetime instead, which is where that
/// stability belongs.
GoRouter get router => _buildRouter();

/// Where the Android system Back key goes when there is nothing to pop.
///
/// SYSTEM BACK USED TO CLOSE THE APP FROM ANY PAGE.
///
/// Found on a physical Pixel. Public navigation is `go`, which replaces rather
/// than pushes, so there was no Flutter route to pop: opening the menu, tapping
/// Pricing and pressing Back left Orchestrate entirely, from the marketing site
/// and from the sign in page both. On a phone Back is the primary way people
/// move, so this was every visitor's second gesture.
///
/// A BackButtonDispatcher was the obvious fix and it is the wrong one — proven
/// on the device, where it never ran at all. Android asks the app whether it
/// handles Back BEFORE delivering it, and Flutter answers from the route
/// stack: one route deep, it registers a null callback and the OS closes the
/// task without Dart hearing anything. Logcat says so directly, `CoreBackPreview
/// ... Setting back callback null`. The app has to claim Back in advance, which
/// is what PopScope does and a dispatcher cannot.
///
/// So [UpBackHandler] wraps each shell, and Back means "up": it resolves the
/// parent surface and goes there. The target is always checked against the
/// canonical route registry above, so this can never strand somebody on an
/// unregistered path — with no known parent it falls back to the section home.
/// At a section home, and at the public front door, [parentOf] answers null,
/// PopScope lets the pop through, and Back keeps its real meaning of leaving.
class WorkspaceBack {
  const WorkspaceBack._();

  static const clientHome = '/client/today';

  /// The surface above [path], or null when leaving the app is correct.
  ///
  /// Inside the workspace this asks [semanticParentOf], which is the map the
  /// visible return already uses. Deliberately not a second opinion: the
  /// on-screen Back and the system Back have to agree about what contains a
  /// surface, or the same gesture means two things depending on where a
  /// person's thumb lands.
  static String? parentOf(String path) {
    if (path.isEmpty || path == '/') return null; // The public front door.
    if (path.startsWith('/auth')) return '/';

    if (path.startsWith('/client') || path.startsWith('/account')) {
      if (isAreaLanding(path)) {
        // A landing carries no return on screen either. Today is where the
        // workspace begins, so Back leaves; the other landings go there.
        return path == clientHome ? null : clientHome;
      }
      return semanticParentOf(path) ?? clientHome;
    }

    return '/'; // /pricing, /product, /trust and the rest of the public site.
  }
}

/// Claims the Android Back gesture for [path] so it goes up instead of out.
///
/// PopScope alone was not enough, and the device proved it twice.
///
/// Flutter tells Android whether the app handles Back by calling
/// `setFrameworkHandlesBack`, and that is computed from the ROOT navigator's
/// route. PublicShell and AuthShell sit directly in root-navigator pages, so
/// their PopScope reaches that computation and Back works. ClientShell is a
/// ShellRoute shell above a NESTED navigator, and its PopScope does not — so
/// the engine was told the app does not handle Back, and Android closed the
/// task without ever asking Dart. That is why the first repair, a
/// BackButtonDispatcher, was never called either: nothing was being delivered
/// to call it with.
///
/// An in-process test cannot see this. `handlePopRoute` reaches the framework
/// directly, so the workspace passes there and fails on a phone.
///
/// So this reports for itself. It states plainly that it handles Back whenever
/// the surface has somewhere above it, and answers the pop when it arrives.
/// PopScope stays for the shells where it already works; whichever mechanism
/// fires first, both resolve to the same parent, and only one can fire per
/// press.
class UpBackHandler extends StatefulWidget {
  const UpBackHandler({super.key, required this.path, required this.child});

  final String path;
  final Widget child;

  @override
  State<UpBackHandler> createState() => _UpBackHandlerState();
}

class _UpBackHandlerState extends State<UpBackHandler>
    with WidgetsBindingObserver {
  String? get _up => WorkspaceBack.parentOf(widget.path);

  bool? _reported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Tell the engine whether Back belongs to us on this surface.
  ///
  /// AFTER THE FRAME, NOT DURING IT.
  ///
  /// The root Navigator calls setFrameworkHandlesBack itself whenever routes
  /// change, and it runs after initState — so saying this any earlier was
  /// simply overwritten, and Back went on closing the app. Re-asserted once
  /// the frame the Navigator was reacting to has finished.
  ///
  /// At a landing it stays false on purpose, so Back keeps its real meaning
  /// and leaves the app rather than trapping somebody on the home surface.
  void _report() {
    final handles = _up != null;
    if (_reported == handles) return;
    _reported = handles;
    SystemNavigator.setFrameworkHandlesBack(handles);
  }

  @override
  Future<bool> didPopRoute() async {
    final up = _up;
    if (up == null) return false; // Nothing above this: let Android leave.
    if (!mounted) return false;
    context.go(up);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final up = _up;
    // Re-asserted every build, because the Navigator re-decides this for its
    // own reasons and last writer wins. Guarded so it only reaches the engine
    // when the answer actually changed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _report();
    });
    return PopScope(
      canPop: up == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || up == null) return;
        context.go(up);
      },
      child: widget.child,
    );
  }
}

GoRouter _buildRouter() {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: AuthSessionController.instance,
  redirect: (context, state) {
    final session = AuthSessionController.instance;
    if (!session.isReady) return null;

    final path = state.uri.path;

    // A BOOKMARK TO A RETIRED SURFACE STILL LANDS SOMEWHERE USEFUL.
    //
    // The hidden operator estate was reachable only by URL, so every link to it
    // that exists is a bookmark or a pasted address. Letting those fall through
    // to the not-found page strands a person on a bare screen with no
    // navigation and no way back — the deep-link dead end this workspace is
    // being rebuilt to remove.
    //
    // One prefix rule rather than twenty-one redirect routes, so retiring the
    // next thing is a single line here.
    if (_retiredOperatorSurfaces.any((p) => path == p || path.startsWith('$p/'))) {
      return '/ops/work';
    }

    final isClientAuth = <String>{
      '/auth/login',
      '/auth/join',
      '/auth/register',
      '/login',
      '/join',
      '/client/login',
      '/client/join',
    }.contains(path);
    final isOpsAuth = <String>{
      '/ops/login',
      '/ops/join',
      '/ops-login',
      '/ops-join',
    }.contains(path);
    final isVerification =
        <String>{'/auth/verify-email', '/client/verify-email'}.contains(path);
    final isReset = <String>{'/auth/reset-password', '/client/reset-password'}
        .contains(path);
    final isSetup = <String>{'/app/setup', '/client/setup'}.contains(path);
    final isSubscribe =
        <String>{'/app/subscribe', '/client/subscribe'}.contains(path);
    // The account layer describes the business's relationship with
    // Orchestrate and governs what the workspace may do. Authenticated like
    // everything else, and deliberately outside the setup and subscription
    // gates below — those are workspace conditions, and an invited
    // representative must be able to establish authority before the workspace
    // is fully configured.
    final isAccountLayer = path == '/account' || path.startsWith('/account/');
    final isClientArea = _clientCoreRoutes.contains(path) ||
        _clientCanonicalRoutes.contains(path) ||
        isAccountLayer ||
        path.startsWith('/app/');
    final isOperatorArea =
        (path.startsWith('/ops/') || path.startsWith('/operator/')) &&
            !isOpsAuth;

    // iOS ROUTES LIKE EVERYWHERE ELSE. THE SPECIAL CASE IS GONE.
    //
    // There used to be a branch here that short-circuited everything below on
    // the App Store binary: registration, setup, plan selection, subscription
    // and the whole public site were unreachable, and an unauthenticated iOS
    // visitor resolved to sign-in no matter what they opened.
    //
    // It was written for Guideline 3.1.1 at a time when the app could not take
    // a payment, so any route toward a plan ended at a web checkout — and
    // sending someone out to pay is the thing 3.1.1 forbids. Blocking the
    // routes was a blunt way to guarantee nobody could be funnelled there.
    //
    // In-app purchase is wired now and the store rail is open, so the reason
    // has gone. What is left is the cost: a person could not create an account
    // on iPhone, and an App Reviewer could not either, which is its own
    // rejection. The product must behave the same everywhere.
    //
    // 3.1.1 is still enforced, by the control that actually states it:
    // `externalPurchaseAllowed` is false in a store build, so no surface
    // offers an external checkout or a "manage billing on our website" link.
    // That is narrower and truer than hiding the routes.

    if (!session.isAuthenticated) {
      if (isOperatorArea) return '/ops/login';
      if (isVerification || isReset) return null;
      // A direct setup/subscribe deep link is acquisition intent, not an
      // existing-user sign-in intent. Start account creation first so the
      // visitor can establish access and carry the selected setup context
      // into onboarding.
      if (isSetup || isSubscribe) {
        return _clientRoute('/auth/register', returnTo: path);
      }
      if (isClientArea || isSetup || isSubscribe) {
        // WHERE THEY WERE TRYING TO GO.
        //
        // This carried only plan/tier/trial, so every deep link into the
        // workspace died here: you signed in and arrived somewhere generic
        // with no trace of why you had come. An emailed link asking someone
        // to do a specific thing could never land them on it.
        return _clientRoute('/auth/login', returnTo: path);
      }
      return null;
    }

    if (session.surface == 'operator') {
      if (isOpsAuth || path == '/') return '/ops/work';
      if (path.startsWith('/app/')) return '/ops/work';
      if (path.startsWith('/auth/')) return '/ops/work';
      if (path.startsWith('/client/')) return '/ops/work';
      return null;
    }

    if (session.surface == 'client') {
      if (!session.emailVerified) {
        if (isVerification || isReset) return null;
        return _clientRoute('/auth/verify-email',
            // Sign-in is not always one hop. Carried across each one, or the
            // last hop lands them nowhere in particular.
            returnTo: readReturnTo(state.uri.queryParameters) ?? path);
      }

      final setupAllowed = <String>{
        '/app/setup',
        '/app/home',
        '/app/billing',
        '/app/account',
        '/client/setup',
        '/client/overview',
        '/client/billing',
        '/client/account',
        '/client/settings',
      };
      if (!session.hasSetupCompleted) {
        if (setupAllowed.contains(path) || isAccountLayer) return null;
        // ONE CANONICAL SETUP ROUTE: /client/setup.
        //
        // Both paths reached the same screen, and the two halves of the
        // product disagreed about which to use — this redirect sent people to
        // /app/setup while Today sent them to /client/setup. Same surface, two
        // identities, and a walkthrough could not tell anyone where they were.
        //
        // /client/setup wins because every other surface a client reaches is
        // spelled /client/..., and setup is the first one they ever see.
        // /app/setup is kept as a redirect so existing links, invitation
        // emails and any saved deep link still resolve.
        return _clientRoute('/client/setup');
      }

      // SUBSCRIPTION IS NOT A DOOR.
      //
      // A gate used to sit here: any organisation whose subscription was not
      // active or trialing was redirected to /app/subscribe from everywhere
      // outside a twelve-route allow-list. Today, Market, Relationships and
      // Inbound were all unreachable without a plan, so a business that had
      // signed up, verified, and finished setup could not see the workspace it
      // had just built.
      //
      // It was worse than an inconvenience on mobile. The iOS binary hides
      // every purchase CTA for App Store §3.1.1 and shows "plan management is
      // available via the web platform" — so an iPhone user with no plan was
      // redirected to a screen that told them to go and use a different device.
      //
      // Four questions, and only the first two may decide whether a person
      // reaches their workspace:
      //
      //   authenticated?            — here
      //   member of an organisation? — here
      //   commercially entitled?     — the server, at the capability boundary
      //   authorised to act?         — Chapter A, at the consequence boundary
      //
      // The last two refuse an ACTION and explain themselves. They never refuse
      // a PLACE. A workspace that disappears when a card expires was never the
      // customer's, and identity does not depend on the payment rail — web,
      // Apple or Google.
      //
      if (isClientAuth ||
          isVerification ||
          isReset ||
          // Setup is no longer bounced once complete: it is also the
          // "where everything stands" place the Setup link opens (DD-26).
          (isSetup && path == '/app/setup') ||
          // NOT isSubscribe. Being signed in is the precondition for
          // activating, not a reason to be sent away from it — and this
          // redirect made the activation screen unreachable by everyone who
          // could use it. Nothing routes anyone here; it is chosen from
          // Billing, and iOS still refuses the route through its own policy.
          path == '/') {
        // WHERE THEY WERE TRYING TO GO, HONOURED HERE.
        //
        // This redirect fires the moment a session exists, before the login
        // screen's own navigation runs — so it, not the screen, is the
        // authority on where an authenticated person lands. Returning a bare
        // home discarded the destination sitting in the very URL being
        // redirected away from, which is why signing in from a deep link
        // still arrived nowhere in particular.
        return readReturnTo(state.uri.queryParameters) ?? '/client/today';
      }
      // Today, directly. This pointed at /app/home, which now only redirects
      // here — an operator path bouncing twice through a retired page.
      if (isOpsAuth || path.startsWith('/ops/')) return '/client/today';
    }

    return null;
  },
  routes: [
    GoRoute(
        path: '/ops/login',
        builder: (context, state) => const OpsLoginScreen()),
    GoRoute(
        path: '/ops/join',
        builder: (context, state) => const OpsLoginScreen(createMode: true)),
    GoRoute(path: '/ops-login', redirect: (context, state) => '/ops/login'),
    GoRoute(path: '/ops-join', redirect: (context, state) => '/ops/join'),
    GoRoute(
        path: '/auth/login',
        builder: (context, state) => const ClientLoginScreen()),
    GoRoute(
        path: '/auth/join',
        redirect: (context, state) => _clientRoute('/auth/register')),
    GoRoute(
        path: '/auth/register',
        builder: (context, state) => const ClientLoginScreen(createMode: true)),
    GoRoute(
        path: '/auth/verify-email',
        builder: (context, state) =>
            const ClientLoginScreen(verificationMode: true)),
    GoRoute(
        path: '/auth/reset-password',
        builder: (context, state) => const ClientLoginScreen(resetMode: true)),
    GoRoute(
        path: '/login',
        redirect: (context, state) => _alias(state, '/auth/login')),
    GoRoute(
        path: '/join',
        redirect: (context, state) => _alias(state, '/auth/join')),
    GoRoute(
        path: '/signup',
        redirect: (context, state) => _alias(state, '/auth/join')),
    GoRoute(
        path: '/forgot-password',
        redirect: (context, state) => _alias(state, '/auth/reset-password')),
    GoRoute(
        path: '/reset-password',
        redirect: (context, state) => _alias(state, '/auth/reset-password')),
    GoRoute(
        path: '/verify-email',
        redirect: (context, state) => _alias(state, '/auth/verify-email')),
    GoRoute(
        path: '/client/login',
        redirect: (context, state) => _alias(state, '/auth/login')),
    GoRoute(
        path: '/client/join',
        redirect: (context, state) => _alias(state, '/auth/join')),
    GoRoute(
        path: '/client/signup',
        redirect: (context, state) => _alias(state, '/auth/join')),
    GoRoute(
        path: '/client/verify-email',
        redirect: (context, state) => _alias(state, '/auth/verify-email')),
    GoRoute(
        path: '/client/reset-password',
        redirect: (context, state) => _alias(state, '/auth/reset-password')),
    GoRoute(path: '/operator', redirect: (context, state) => '/ops/overview'),
    GoRoute(
        path: '/app/command', redirect: (context, state) => '/ops/overview'),
    GoRoute(
        path: '/app/pipeline', redirect: (context, state) => '/ops/contacts'),
    GoRoute(
        path: '/app/inquiries', redirect: (context, state) => '/ops/inquiries'),
    GoRoute(
        path: '/app/inquiries/:id',
        redirect: (context, state) =>
            '/ops/inquiries/${state.pathParameters['id'] ?? ''}'),
    GoRoute(
        path: '/app/execution', redirect: (context, state) => '/ops/campaigns'),
    GoRoute(
        path: '/app/execution/campaigns',
        redirect: (context, state) => '/ops/campaigns'),
    GoRoute(
        path: '/app/execution/replies',
        redirect: (context, state) => '/ops/activity'),
    GoRoute(
        path: '/app/execution/meetings',
        redirect: (context, state) => '/ops/activity'),
    GoRoute(path: '/app/clients', redirect: (context, state) => '/ops/clients'),
    GoRoute(
        path: '/app/revenue', redirect: (context, state) => '/ops/activity'),
    GoRoute(
        path: '/app/deliverability',
        redirect: (context, state) => '/ops/mailboxes'),
    GoRoute(
        path: '/app/communications',
        redirect: (context, state) => '/ops/activity'),
    GoRoute(
        path: '/app/records', redirect: (context, state) => '/ops/activity'),
    GoRoute(path: '/app/settings', redirect: (context, state) => '/ops/debug'),
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            // DD-26: the front door is board S01.
            currentPath: state.uri.path, child: const FrontDoorScreen()),
      ),
    ),
    GoRoute(
      path: '/product',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/',
    ),
    GoRoute(
      path: '/how-it-works',
      // DD-26: "One customer, start to paid" (board S03), an illustrated
      // example labelled as one.
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: const OneCustomerScreen()),
      ),
    ),
    GoRoute(
      path: '/ai-governed-revenue',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/',
    ),
    GoRoute(
      path: '/lead-sourcing',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/how-it-works',
    ),
    GoRoute(
      path: '/trust-compliance',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/trust',
    ),
    GoRoute(
      path: '/intake',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: const ContactScreen()),
      ),
    ),
    GoRoute(
      path: '/pricing',
      // Points at the commercial model rather than the six-plan catalog.
      // Those prices were never approved, disagreed with what was stored
      // against real organisations, and were purchasable — so the page that
      // sold them is off the public route rather than edited into honesty.
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            // DD-26: pricing is board S04; the numbers are the server's.
            currentPath: state.uri.path, child: const PricingBScreen()),
      ),
    ),
    GoRoute(
      path: '/trust',
      // DD-26: one trust page in place of four.
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: const TrustScreen()),
      ),
    ),
    GoRoute(
      path: '/legal',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: const LegalIndexScreen()),
      ),
    ),
    GoRoute(
      path: '/about',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          // DD-26: said in the front door's own words.
          child: const PublicContentScreen(
            eyebrow: 'About',
            title: 'Built for owners who would rather be doing the work.',
            subtitle:
                'Orchestrate finds businesses that need what you do, writes to '
                'them from your own email, and carries each one to an agreement '
                'and a paid invoice. You say yes at every step that matters.',
            sections: [
              ContentSection(
                title: 'What it is',
                body:
                    'Not a list of contacts to work through, and not a robot '
                    'that writes to people on its own. Orchestrate does the '
                    'searching, the writing and the following up, and stops '
                    'for your yes before anything goes out in your name.',
              ),
              ContentSection(
                title: 'What stays yours',
                body:
                    'Your name, your email address and your customers. Notes go '
                    'from your own address; replies land in your own inbox; '
                    'anyone who asks not to be contacted is never written to '
                    'again. You can stop at any time.',
              ),
              ContentSection(
                title: 'Who makes it',
                body: 'Orchestrate is made by Aura Platform LLC.',
              ),
            ],
            sideActions: [
              ContentAction(
                  label: 'Start with your business',
                  path: '/auth/register',
                  filled: true),
              ContentAction(
                  label: 'One customer, start to paid', path: '/how-it-works'),
              ContentAction(label: 'Pricing', path: '/pricing'),
              ContentAction(label: 'Trust', path: '/trust'),
            ],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/contact',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: const ContactScreen()),
      ),
    ),
    GoRoute(
      path: '/account-deletion',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
          currentPath: state.uri.path,
          child: const PublicContentScreen(
            eyebrow: 'Policy',
            title: 'Account deletion',
            subtitle:
                'You can delete your account yourself inside the app, or ask us '
                'to from the email address on the account.',
            sideNote:
                'Orchestrate is made by Aura Platform LLC. '
                'Support: support@orchestrateops.com.',
            sections: [
              ContentSection(
                title: 'Delete your account from inside the app',
                body:
                    'You can permanently delete your account yourself, without contacting support: Client workspace → Account → Delete account. Deletion is confirmed in-app and cannot be undone.',
              ),
              ContentSection(
                title: 'Or ask us by email',
                body:
                    'If you prefer, you may also request deletion by emailing support@orchestrateops.com from the email address associated with your Orchestrate account.',
              ),
              ContentSection(
                title: 'What is deleted',
                body:
                    'When you delete your account, Orchestrate erases your login credentials and sign-in identities, your profile information (name and email), workspace access, and the contact details on your client record, and cancels any active subscription. After deletion the account can no longer be signed into or recovered.',
                points: [
                  'login credentials and sign-in identities',
                  'profile information (name and email)',
                  'workspace access',
                  'contact details on your client record',
                  'active subscription (canceled on deletion)',
                ],
              ),
              ContentSection(
                title: 'What may be retained',
                body:
                    'Some records are kept after the account is deleted, for billing, security, audit, legal compliance, dispute resolution, or unpaid balances. No fixed retention period is currently set for them.',
                points: [
                  'the record of who authorized Orchestrate to act for the business, including that person\'s name and email',
                  'agreement acceptance records, including the accepting person\'s name and email',
                  'the business\'s workspace records: organization, legal name, address, business profile and market data',
                  'records of commercial access granted to the business',
                  'billing records',
                  'security and audit logs',
                ],
              ),
              ContentSection(
                title: 'Timeline',
                body:
                    'Requests are reviewed and processed within a reasonable period, normally within 30 days, unless retention is required by law, billing, security, or dispute obligations.',
              ),
            ],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/newsletter',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/',
    ),
    GoRoute(
      path: '/newsletter/subscribe',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/',
    ),
    GoRoute(path: '/terms', redirect: (context, state) => '/legal/terms'),
    GoRoute(path: '/privacy', redirect: (context, state) => '/legal/privacy'),
    GoRoute(
      path: '/legal/terms',
      pageBuilder: (context, state) => NoTransitionPage(
        child:
            PublicShell(currentPath: state.uri.path, child: buildTermsScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/privacy',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildPrivacyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/billing',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildBillingPolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/refunds',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildRefundPolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/acceptable-use',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildAcceptableUseScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/service-agreement',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildServiceAgreementScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/deliverability',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildDeliverabilityScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/mailbox-access',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: buildMailboxAccessPolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/ai-usage',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildAiUsagePolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/credentials',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: buildCredentialHandlingScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/reply-monitoring',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: buildReplyMonitoringDisclosureScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/suppression',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildSuppressionPolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/providers',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: buildProviderResponsibilityScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/abuse',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildAbusePolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/legal/retention',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path, child: buildRetentionPolicyScreen()),
      ),
    ),
    GoRoute(
      path: '/why-orchestrate',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/',
    ),
    GoRoute(
      path: '/how-orchestrate-operates',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/how-it-works',
    ),
    GoRoute(
      path: '/trust-architecture',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/trust',
    ),
    GoRoute(
      path: '/for-evaluators',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/trust',
    ),
    GoRoute(
      path: '/activation',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/how-it-works',
    ),
    GoRoute(
      path: '/security-evaluation',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/trust',
    ),
    // Public DNS diagnostic surface — visitors can verify SPF / DKIM /
    // DMARC for their sending domain without signup. Live DNS lookups;
    // no records stored.
    GoRoute(
      path: '/diagnostics',
      pageBuilder: (context, state) => NoTransitionPage(
        child: PublicShell(
            currentPath: state.uri.path,
            child: const PublicDiagnosticsScreen()),
      ),
    ),
    GoRoute(
      path: '/dns-diagnostic',
      redirect: (context, state) => '/diagnostics',
    ),
    // Public operational answers surface — curated knowledge catalog,
    // deterministic matcher, no AI generation. Honest "no match" path.
    GoRoute(
      path: '/answers',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/contact',
    ),
    GoRoute(
      path: '/help',
      redirect: (context, state) => '/contact',
    ),
    GoRoute(
      path: '/faq',
      redirect: (context, state) => '/contact',
    ),
    // Guided operational journey surface. /journey defaults to the
    // evaluate-and-activate map for visitors landing without a key.
    GoRoute(
      path: '/journey',
      redirect: (context, state) => '/how-it-works',
    ),
    GoRoute(
      path: '/journey/:journeyKey',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/how-it-works',
    ),
    GoRoute(
      path: '/trust-review',
      // DD-26: retired in the public rebuild; the address still lands
      // somewhere true.
      redirect: (context, state) => '/trust',
    ),
    // SETUP IS A FOCUSED FLOW, NOT A WORKSPACE DESTINATION.
    //
    // /client/setup used to sit inside the client ShellRoute, so the screen
    // rendered the workspace nav rail AND its own AuthShell header and footer
    // at once: two sets of chrome around one form, with the content squeezed
    // into what was left. Three separate layout overflows fell out of that —
    // the rail, the header and the industry field — and every person who
    // reached setup from Today saw them.
    //
    // Declared here, outside the shell, exactly where /app/setup was. The
    // canonical spelling is what changed; the chrome is what it always was.
    GoRoute(
        path: '/client/setup',
        // Founder, 1 Oct 2026: once a business has its workspace, Setup lives
        // inside it, with the sidebar, instead of taking the whole screen.
        // First-time setup stays here, focused. Every query (step, oauth,
        // checkout) travels with the move.
        redirect: (context, state) => AuthSessionController.instance.hasSetupCompleted
            ? Uri(path: '/client/setup/workspace',
                    queryParameters: state.uri.queryParameters.isEmpty
                        ? null
                        : state.uri.queryParameters)
                .toString()
            : null,
        // DD-26: setup is one path of six steps. `?step=` opens a step
        // directly; without it the first unfinished step opens.
        builder: (context, state) => OnePathSetupScreen(
            initialStep: state.uri.queryParameters['step'],
            oauthStatus: state.uri.queryParameters['oauth'],
            oauthReason: state.uri.queryParameters['reason'],
            checkoutStatus: state.uri.queryParameters['checkout'])),
    // Compatibility only. /client/setup is canonical; this keeps older links
    // and any saved deep link resolving rather than 404ing.
    GoRoute(
        path: '/app/setup',
        redirect: (context, state) => '/client/setup'),
    GoRoute(
        path: '/app/subscribe',
        redirect: (context, state) => '/client/setup?step=plan'),
    ShellRoute(
      navigatorKey: _clientShellNavigatorKey,
      builder: (context, state, child) =>
          ClientShell(currentPath: state.uri.path, child: child),
      routes: [
        // Setup inside the workspace, once the business has one.
        GoRoute(
            path: '/client/setup/workspace',
            pageBuilder: (context, state) => NoTransitionPage(
                child: OnePathSetupScreen(
                    embedded: true,
                    initialStep: state.uri.queryParameters['step'],
                    oauthStatus: state.uri.queryParameters['oauth'],
                    oauthReason: state.uri.queryParameters['reason'],
                    checkoutStatus: state.uri.queryParameters['checkout']))),
        GoRoute(
            path: '/client', redirect: (context, state) => '/client/today'),
        GoRoute(
            path: '/client/overview',
            redirect: (context, state) => '/client/today'),
        GoRoute(
            path: '/client/workspace',
            redirect: (context, state) => '/client/today'),
        // ── THE THREE DESTINATIONS ─────────────────────────────────────
        // Today, Relationships, Business. Everything else is reached by
        // entering the work, or lives in the account layer below.
        GoRoute(
            path: '/client/today',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const TodayScreen())),
        GoRoute(
          path: '/client/relationships',
          pageBuilder: (context, state) =>
            NoTransitionPage(child: RelationshipsWorkspaceScreen(
            relationshipId: state.uri.queryParameters['id'],
            returnTo: state.uri.queryParameters[kReturnToParam],
          )),
        ),
        GoRoute(
          path: '/client/relationships/:id',
          pageBuilder: (context, state) =>
            NoTransitionPage(child: RelationshipsWorkspaceScreen(
            relationshipId: state.pathParameters['id'],
            // Where they came from — Today, Market, the list, or a deep link.
            // Back goes there instead of always dumping them on the list.
            returnTo: state.uri.queryParameters[kReturnToParam],
          )),
        ),
        GoRoute(
          path: '/client/market',
          pageBuilder: (context, state) =>
            NoTransitionPage(child: MarketScreen(
            focusCounterpartyKey: state.uri.queryParameters['focus'],
          )),
        ),
        // DD-26: the business's own money with its customers.
        GoRoute(
          path: '/client/money',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: MoneyScreen()),
        ),
        GoRoute(
            path: '/client/inbound',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const AttentionScreen())),
        GoRoute(
            path: '/client/business',
            redirect: (context, state) => _retired(state, '/client/setup')),

        // ── THE ACCOUNT LAYER ──────────────────────────────────────────
        // Deliberately NOT subject to the setup or subscription gates below.
        // Authority is a property of the business and governs what the
        // workspace may do, so it cannot live inside the gates it governs —
        // an invited representative whose business had not finished setup
        // could not otherwise reach the page they were emailed about.
        GoRoute(
            path: '/account', redirect: (context, state) => '/account/people'),
        GoRoute(
            path: '/account/people',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const AccountLayerScreen(section: AccountSection.people))),
        GoRoute(
            path: '/account/plan',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const AccountLayerScreen(section: AccountSection.plan))),
        // Orchestrate's own record with the business: agreements, charges,
        // authority granted. Moved here from /client/records (DD-34).
        GoRoute(
            path: '/account/record',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const ClientRecordsScreen())),
        GoRoute(
            path: '/account/security',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const AccountLayerScreen(section: AccountSection.security))),
        // The authority screen's first home. It moved; the link still works.
        GoRoute(
            path: '/client/authorised-people',
            redirect: (context, state) => '/account/people'),
        // Representation — the canonical client-owned commercial-profile
        // surface. Old /client/business-identity + /client/campaign paths
        // redirect here so the operational IA stays single-source.
        GoRoute(
            path: '/client/representation',
            redirect: (context, state) => _retired(state, '/client/setup?step=business')),
        // OAuth return surface — backend's ORCH_APP_OAUTH_RETURN_URL
        // should be configured to land here so the result is rendered
        // with operation-scoped mailbox disclosure + next-action CTAs
        // rather than dumping the user on a bare query-string URL.
        GoRoute(
            path: '/client/oauth/return',
            // A mailbox connect started inside setup comes back to setup
            // (DD-26): the person was on step 4 and that is where they
            // continue, with the outcome shown there.
            redirect: (context, state) {
              final q = state.uri.queryParameters;
              if ((q['provider'] ?? '').toLowerCase() == 'google_contacts') {
                return null;
              }
              // DD-27: every mailbox connection belongs to the email step,
              // wherever it was started from.
              return Uri(path: '/client/setup', queryParameters: {
                'step': 'email',
                if ((q['status'] ?? '').isNotEmpty) 'oauth': q['status']!,
                if ((q['reason'] ?? '').isNotEmpty) 'reason': q['reason']!,
              }).toString();
            },
            pageBuilder: (context, state) =>
            NoTransitionPage(child: OAuthReturnScreen(
                  status: state.uri.queryParameters['status'] ?? '',
                  provider: state.uri.queryParameters['provider'],
                  reason: state.uri.queryParameters['reason'],
                  email: state.uri.queryParameters['email'],
                  mailboxId: state.uri.queryParameters['mailboxId'],
                ))),
        GoRoute(
            path: '/client/business-identity',
            redirect: (context, state) => '/client/setup?step=want'),
        GoRoute(
            path: '/client/campaign',
            redirect: (context, state) => '/client/setup?step=want'),
        GoRoute(
            path: '/client/campaign/targeting',
            redirect: (context, state) => '/client/setup?step=want'),
        GoRoute(
            path: '/client/campaigns',
            redirect: (context, state) => '/client/setup?step=want'),
        // Targeting scope editor (geographies + industries). Kept under
        // /app/campaigns for now; representation links to it as
        // "refine targeting".
        GoRoute(
            // Targeting is edited on the business identity surface — ideal
            // customer, geography, industry — so this points there rather than
            // at a route that no longer renders anything.
            //
            // It used to redirect to /app/campaigns while /app/campaigns
            // redirected back here, so the two were a cycle: every arrival
            // bounced between them and the workspace reported no surface. The
            // pair was written when /app/campaigns still rendered the targeting
            // editor, and survived the retirement of the /app screens as two
            // redirects with nothing left underneath either.
            path: '/client/representation/targeting',
            redirect: (context, state) => '/client/setup?step=want'),
        // Sequence authoring (governed template vs legacy custom body).
        // Mounted under the client shell so the workspace chrome wraps
        // it. Step CRUD posts directly to the new ClientPortalService
        // endpoints (POST /client/sequences/:id/steps,
        // PATCH /client/sequence-steps/:stepId,
        // DELETE /client/sequence-steps/:stepId).
        GoRoute(
            path: '/client/sequences/:sequenceId',
            redirect: (context, state) => _retired(state, '/client/relationships')),
        GoRoute(
            path: '/client/subscribe',
            redirect: (context, state) => _retired(state, '/account/plan')),
        // Relationships — mailbox-derived relationship intelligence.
        GoRoute(
            path: '/client/contacts/inventory',
            redirect: (context, state) => _retired(state, '/client/relationships')),
        GoRoute(
            path: '/client/contacts',
            redirect: (context, state) => '/client/relationships'),
        // Opportunities — signal-driven intelligence (was "Leads").
        GoRoute(
            // Opportunities were a second list of the same durable records.
            // Pipeline survives as a view; the second universe does not.
            path: '/client/opportunities',
            redirect: (context, state) => '/client/relationships'),
        GoRoute(
            path: '/client/leads',
            redirect: (context, state) => '/client/relationships'),
        // Operations — managed execution runtime (was "Outreach").
        GoRoute(
            // Outreach in flight shows on Today; per-relationship activity
            // shows inside the relationship.
            path: '/client/operations',
            redirect: (context, state) => '/client/relationships'),
        GoRoute(
            path: '/client/outreach',
            redirect: (context, state) => '/client/operations'),
        GoRoute(
            // Replies are relationship correspondence, not a destination.
            path: '/client/replies',
            redirect: (context, state) => '/client/relationships'),
        // Infrastructure — mailbox + sending identity + provider trust
        // consolidated under one surface (was /client/mailbox).
        GoRoute(
            path: '/client/infrastructure',
            redirect: (context, state) => _retired(state, '/client/setup?step=email')),
        GoRoute(
            path: '/client/mailbox',
            redirect: (context, state) => '/client/setup?step=email'),
        GoRoute(
            // Meetings are timeline events inside a relationship.
            path: '/client/meetings',
            redirect: (context, state) => '/client/relationships'),
        GoRoute(
            path: '/client/billing',
            redirect: (context, state) => _retired(state, '/account/plan')),
        GoRoute(
            path: '/client/records',
            redirect: (context, state) => _retired(state, '/account/record')),
        GoRoute(
            path: '/client/invoices',
            redirect: (context, state) => '/account/record'),
        GoRoute(
            path: '/client/receipts',
            redirect: (context, state) => '/account/record'),
        GoRoute(
            path: '/client/agreements',
            redirect: (context, state) => '/account/record'),
        GoRoute(
            path: '/client/statements',
            redirect: (context, state) => '/account/record'),
        GoRoute(
            path: '/client/reminders',
            redirect: (context, state) => '/account/record'),
        GoRoute(
            // Notifications became Attention, which lives in Today.
            path: '/client/notifications',
            redirect: (context, state) => '/client/today'),
        GoRoute(
            path: '/client/support',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const ClientSupportScreen())),
        GoRoute(
            path: '/client/settings',
            redirect: (context, state) => _retired(state, '/account/security')),
        GoRoute(
            path: '/client/account',
            redirect: (context, state) => _retired(state, '/account/security')),
        GoRoute(
            path: '/client/help',
            redirect: (context, state) => '/client/support'),
        // CREDENTIALS WAS A DIAGNOSTIC WEARING A PRODUCT LABEL.
        //
        // The Business hub offered "Credentials — certifications, licences,
        // insurance" and this route answered with "Client-safe AI activity and
        // trust summary": a generic backend-surface screen that listed the
        // endpoints it had called and printed whatever came back, including a
        // record whose only visible field read "campaign: null".
        //
        // The product has no certifications capability, so the honest move is
        // to stop offering one. It redirects rather than 404s because the link
        // has existed, and Evidence is the real surface for what a business can
        // show about itself.
        GoRoute(
            path: '/client/trust',
            redirect: (context, state) => '/client/setup?step=offer'),
        // THE LEGACY HOME IS RETIRED, NOT LEFT LYING AROUND.
        //
        // It predates the reconstructed workspace and was never one of its
        // four destinations, so it rendered inside the new shell with nothing
        // selected — a page that could not say where it was. Sign-in sent
        // every client here, which is why it kept being the last place a lot
        // of people saw. It redirects rather than 404s: the path is in old
        // links, and Today is where it was always meant to lead.
        GoRoute(
            path: '/app/home',
            redirect: (context, state) => '/client/today'),
        GoRoute(
            path: '/app/contacts',
            redirect: (context, state) => '/client/relationships'),
        GoRoute(
            path: '/app/contacts/import',
            redirect: (context, state) => '/client/relationships'),
        GoRoute(
            path: '/app/contacts/:contactId',
            redirect: (context, state) => '/client/relationships'),
        // LEGACY TARGETING. Unlinked from the current IA, and it told a
        // business "Billing: ACTIVE" beside "Plan: opportunity ·" — the first
        // flatly untrue for an account with no subscription, the second a
        // concept the product retired. Market and targeting is the surface the
        // Business hub maintains.
        GoRoute(
            path: '/app/campaigns',
            redirect: (context, state) => '/client/setup?step=want'),
        GoRoute(
            path: '/app/campaigns/create',
            redirect: (context, state) => '/client/setup?step=want'),
        GoRoute(
            path: '/app/campaigns/:campaignId',
            redirect: (context, state) => '/client/setup?step=want'),
        // A SECOND EXECUTION SURFACE, LINKED FROM NOWHERE. What has actually
        // moved belongs on the relationship it moved on, which is where the
        // reconstructed workspace puts it.
        GoRoute(
            path: '/app/activity',
            redirect: (context, state) => '/client/relationships'),
        GoRoute(
            path: '/app/mailbox',
            redirect: (context, state) => '/client/setup?step=email'),
        // A PLACEHOLDER IS NOT A FEATURE. This said "Update controls are
        // available later" and nothing else, and nothing linked to it. A
        // customer who found it learned only that something might exist one
        // day.
        GoRoute(
            path: '/app/newsletter',
            redirect: (context, state) => '/client/today'),
        GoRoute(
            path: '/app/newsletter/audience',
            redirect: (context, state) => '/client/today'),
        GoRoute(
            path: '/app/newsletter/issues',
            redirect: (context, state) => '/client/today'),
        GoRoute(
            path: '/app/newsletter/settings',
            redirect: (context, state) => '/client/today'),
        GoRoute(
            path: '/app/branding',
            redirect: (context, state) => _retired(state, '/client/setup?step=business')),
        GoRoute(
            path: '/app/branding/identity',
            redirect: (context, state) => '/client/setup?step=business'),
        GoRoute(
            path: '/app/branding/templates',
            redirect: (context, state) => '/client/setup?step=business'),
        GoRoute(
            path: '/app/branding/signatures',
            redirect: (context, state) => '/client/setup?step=business'),
        GoRoute(
            path: '/app/trust',
            redirect: (context, state) => _retired(state, '/client/setup?step=offer')),
        GoRoute(
            path: '/app/evidence',
            redirect: (context, state) => _retired(state, '/client/setup?step=offer')),
        GoRoute(
            path: '/app/artifacts',
            redirect: (context, state) => _retired(state, '/client/money')),
        // Retired with the home it belonged to. It carried no title, no
        // breadcrumb, buttons in a colour the design system does not use, and
        // "ICP" as a word shown to a customer — while /client/billing is the
        // billing surface the product actually maintains.
        GoRoute(
            path: '/app/billing',
            redirect: (context, state) => '/account/plan'),
        GoRoute(
            path: '/app/account',
            redirect: (context, state) => _retired(state, '/account/security')),
      ],
    ),
    ShellRoute(
      navigatorKey: _operatorShellNavigatorKey,
      builder: (context, state, child) =>
          OperatorShell(currentPath: state.uri.path, child: child),
      routes: [
        // Legacy /operator/overview lands on the work queue, which is where
        // an operator's day actually starts. It used to open a composed
        // "cognition home" that no navigation reached and that is now retired.
        GoRoute(
            path: '/operator/overview',
            redirect: (context, state) => '/ops/work'),
        GoRoute(
            path: '/operator/system',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.system))),
        GoRoute(
            path: '/operator/system-doctor',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorSystemDoctorScreen())),
        // Legacy operator Clients panel removed — it was disconnected
        // from runtime truth. Redirect to the runtime-backed
        // campaign-lifecycle surface.
        GoRoute(
            path: '/operator/clients',
            redirect: (context, state) => '/ops/continuity/campaigns'),
        GoRoute(
            path: '/operator/organizations',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.organizations))),
        // Legacy operator Campaigns panel removed — it reported
        // "Campaigns = 0" while real campaigns existed. Redirect to
        // the runtime-backed campaign-lifecycle surface.
        GoRoute(
            path: '/operator/campaigns',
            redirect: (context, state) => '/ops/continuity/campaigns'),
        GoRoute(
            path: '/operator/leads',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.leads))),
        GoRoute(
            path: '/operator/jobs',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorWorkspaceScreen(
                section: OperatorSection.execution))),
        GoRoute(
            path: '/operator/workers',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorWorkspaceScreen(
                section: OperatorSection.execution))),
        GoRoute(
            path: '/operator/queues',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorWorkspaceScreen(
                section: OperatorSection.execution))),
        GoRoute(
            path: '/operator/ai-governance',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.aiGovernance))),
        // Legacy operator Providers panel removed — superseded by the
        // Runtime Truth surface that replaced it. Transport owns provider health.
        GoRoute(
            path: '/operator/providers',
            redirect: (context, state) => '/ops/transport'),
        GoRoute(
            path: '/operator/sources',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.sources))),
        GoRoute(
            path: '/operator/reachability',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.reachability))),
        GoRoute(
            path: '/operator/qualification',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.qualification))),
        GoRoute(
            path: '/operator/signals',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorBackendSurfaceScreen(
                surface: OperatorBackendSurface.signals))),
        GoRoute(
            path: '/operator/deliverability',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorWorkspaceScreen(
                section: OperatorSection.deliverability))),
        GoRoute(
            path: '/operator/emails',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorWorkspaceScreen(
                section: OperatorSection.communications))),
        GoRoute(
            path: '/operator/replies',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorWorkspaceScreen(
                section: OperatorSection.replies))),
        GoRoute(
            path: '/operator/meetings',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorWorkspaceScreen(
                section: OperatorSection.meetings))),
        GoRoute(
            path: '/operator/billing',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorWorkspaceScreen(
                section: OperatorSection.revenue))),
        GoRoute(
            path: '/operator/documents',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorWorkspaceScreen(
                section: OperatorSection.records))),
        GoRoute(
            path: '/operator/support',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorWorkspaceScreen(
                section: OperatorSection.inquiries))),
        GoRoute(
            path: '/operator/analytics',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorWorkspaceScreen(
                section: OperatorSection.analytics))),
        GoRoute(
            path: '/operator/activity',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorWorkspaceScreen(
                section: OperatorSection.activity))),
        // Cognition Home replaces the legacy command center at the
        // canonical landing URL. The legacy command surface remains
        // reachable as a drill-down inside Continuity for operators
        // who want the metric-wall view.
        GoRoute(
            path: '/ops/work',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OpsWorkQueueScreen())),
        GoRoute(
            path: '/ops/dispatch',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OpsDispatchScreen())),
        GoRoute(
            path: '/ops/transport',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OpsTransportScreen())),
        GoRoute(
            path: '/ops/inventory',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OpsInventoryScreen())),
        GoRoute(
            path: '/ops/jobs',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OpsJobsScreen())),
        // The durable half of authority work. The queue is what needs deciding;
        // this is what the deciding produced, and it outlives the case.
        GoRoute(
            path: '/ops/authority',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OpsAuthorityScreen())),
        GoRoute(
            path: '/ops/history',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OpsHistoryScreen())),

        // What was done, by whom, to what, and when. The evidence behind
        // every operator decision, and the one surface of the retired estate
        // that was genuinely load-bearing — extracted rather than deleted.
        GoRoute(
            path: '/ops/governance/audit',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const AuditTimelineScreen())),
        GoRoute(
            path: '/operator/jobs-legacy',
            redirect: (context, state) => '/ops/continuity?drill=jobs'),
        GoRoute(
            path: '/operator/queues-legacy',
            redirect: (context, state) => '/ops/continuity?drill=queues'),
        GoRoute(
            path: '/operator/workers-legacy',
            redirect: (context, state) => '/ops/continuity?drill=workers'),
        GoRoute(
            path: '/ops/clients',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OpsClientsScreen())),
        GoRoute(
            // Inventory & imports owns contact records. This was a second,
            // unlinked view of the same thing in the legacy sectioned screen.
            path: '/ops/contacts',
            redirect: (context, state) => '/ops/inventory'),
        GoRoute(
            path: '/ops/campaigns',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OpsCampaignsScreen())),
        GoRoute(
            // Transport owns mailboxes and sending identity.
            path: '/ops/mailboxes',
            redirect: (context, state) => '/ops/transport'),
        GoRoute(
            path: '/ops/providers',
            redirect: (context, state) => '/ops/transport'),
        GoRoute(
            // Audit history owns what happened and when.
            path: '/ops/activity',
            redirect: (context, state) => '/ops/history'),
        GoRoute(
            path: '/ops/inquiries',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorWorkspaceScreen(
                section: OperatorSection.inquiries))),
        // Product feedback. The operator queue sits beside Inquiries because
        // it is the same job — listening — and not a second console.
        GoRoute(
            path: '/ops/feedback',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const FeedbackQueueScreen())),
        // Telling us something. Open to any member of any role: requiring
        // seniority would collect only the opinions of people who can already
        // change things.
        GoRoute(
            path: '/feedback',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: FeedbackScreen(
                fromSurface: _firstSegment(state.uri.queryParameters['from'])))),
        GoRoute(
            path: '/ops/inquiries/:id',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: InquiryDetailScreen(
                inquiryId: state.pathParameters['id'] ?? ''))),
        GoRoute(
            path: '/ops/debug',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorDebugScreen())),
        // Operator governance workspace — cross-client provenance + lifecycle
        // visibility. Reads /operator/governance/messages/{recent,:id}.
        GoRoute(
            path: '/ops/governance',
            pageBuilder: (context, state) =>
            NoTransitionPage(child: const OperatorGovernanceScreen())),
        GoRoute(
            path: '/operator/governance',
            redirect: (context, state) => '/ops/governance'),
      ],
    ),
  ],
  // A link that leads nowhere says so, and offers the way back. It used to be
  // a bare "This surface is unavailable." with no way out (2 Oct 2026).
  errorBuilder: (context, state) => Theme(
    data: Ob.theme(),
    child: Scaffold(
      backgroundColor: Ob.paper,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('This page does not exist.', style: Ob.name(24)),
            const SizedBox(height: 8),
            Text('The link may be old or mistyped. Nothing has changed.',
                style: Ob.body(15, color: Ob.inkMuted)),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => GoRouter.of(context).go(
                  AuthSessionController.instance.surface == 'operator'
                      ? '/ops/overview'
                      : AuthSessionController.instance.isAuthenticated
                          ? '/client/today'
                          : '/'),
              child: const Text('Go to your workspace'),
            ),
          ]),
        ),
      ),
    ),
  ),
  );
}


/// WHERE A SIGNED-OUT VISITOR IS SENT, AND WHY THEY CAME.
///
/// It used to carry three more things through every hop: a plan, a tier and a
/// trial flag, so a package chosen on the marketing site survived registration
/// and arrived preselected in setup. There are no packages and there is no
/// trial, so all three carried a promise the product could not keep.
///
/// What still travels is the destination. A person who followed a link asking
/// them to do a specific thing must land on it after signing in.
String _clientRoute(String path, {String? returnTo}) =>
    withReturnTo(path, returnTo);

/// AN ALIAS MUST CARRY THE QUERY IT WAS GIVEN.
///
/// Eleven auth aliases redirected with a bare string — `/client/verify-email`
/// to `/auth/verify-email`, and so on — which silently discarded the query.
///
/// That is not cosmetic. The backend emails confirmation links to
/// `/client/verify-email?token=...`; the redirect dropped the token, and the
/// destination reads `?token` to call `verifyEmail`. So **every emailed
/// verification link landed on a screen with nothing to verify**, and the
/// person saw the same "Confirm your email" prompt that sent them there.
/// Password-reset links lost their token the same way, and `returnTo` — the
/// whole point of a deep link into the workspace — died on every `/login`,
/// `/join` and `/signup` alias.
///
/// Found on 2026-09-17 by clicking a real confirmation link from a real
/// mailbox. It could not be found any other way: the token only exists in
/// mail, so no amount of clicking inside the app reaches this path.
/// A retired page's address, kept so old emails, bookmarks and installed apps
/// still arrive somewhere real (DD-34). The new home's own `?step=` wins; any
/// other query the old link carried travels with it.
String _retired(GoRouterState state, String home) {
  final target = Uri.parse(home);
  final query = {...state.uri.queryParameters}..remove('focus');
  query.addAll(target.queryParameters);
  return Uri(path: target.path, queryParameters: query.isEmpty ? null : query).toString();
}

String _alias(GoRouterState state, String destination) {
  final query = state.uri.query;
  if (query.isEmpty) return destination;
  return '$destination?$query';
}

/// The KIND of screen someone came from, never the path.
///
/// Only the first segment survives: `/app/campaigns/<real id>` names a real
/// campaign, and a feedback record has no business carrying that.
String? _firstSegment(String? path) {
  if (path == null || !path.startsWith('/')) return null;
  final segments = path.split('/').where((s) => s.isNotEmpty);
  return segments.isEmpty ? '/' : '/${segments.first}';
}
