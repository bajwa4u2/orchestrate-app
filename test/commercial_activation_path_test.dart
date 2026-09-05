import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'support/sibling_backend.dart';
import 'package:orchestrate_app/core/config/pricing_config.dart';

/// A CUSTOMER MUST BE ABLE TO REACH THE CAPABILITY THEY ARE BEING SOLD.
///
/// Web certification found the gap by reading the screen: a business with no
/// plan was told "Managed execution starts once a plan is activated" and given
/// exactly one action — "Open billing portal", a Stripe portal for managing a
/// subscription that does not exist. There was no way to activate anywhere in
/// the product.
///
/// The cause was a redirect. `/client/subscribe` sat with the auth gates, so
/// the moment a session existed the router sent them to /client/today — which
/// made the only activation screen unreachable by the only people who could
/// use it. Correct when subscribing was an unauthenticated funnel; wrong once
/// it became a voluntary account action.
void main() {
  final router = File('lib/app/routing/app_router.dart').readAsStringSync();
  final billing =
      File('lib/features/client/screens/client_billing_screen.dart').readAsStringSync();
  final iosPolicy =
      File('lib/core/platform/ios_route_policy.dart').readAsStringSync();

  test('a signed-in customer is not redirected away from activation', () {
    // The gate list that bounces an authenticated session home.
    final gate = router.substring(
      router.indexOf('if (isClientAuth ||'),
      router.indexOf("path == '/') {"),
    );
    expect(
      gate.contains('isSubscribe ||'),
      isFalse,
      reason: 'being signed in is the precondition for activating, not a '
          'reason to be sent away from it',
    );
  });

  test('nothing routes anyone to checkout, which is a different rule', () {
    // Removing the bounce AWAY must not introduce a bounce TO. Activation is
    // chosen, never forced: no redirect target may be the subscribe route.
    final redirects = RegExp(r"return '(/[^']*)'").allMatches(router)
        .map((m) => m.group(1)!)
        .toList();
    expect(
      redirects.where((r) => r.contains('subscribe')),
      isEmpty,
      reason: 'no destination may bounce a signed-in business to checkout',
    );
  });

  test('activation and management are different actions', () {
    // A business with no subscription is offered activation; one with a
    // subscription is offered the portal. Never a portal for nothing.
    expect(billing.contains('bool _hasSubscription'), isTrue);
    expect(billing.contains('!_hasSubscription(data)'), isTrue);
    expect(billing.contains("context.go('/client/subscribe')"), isTrue);
    expect(
      billing.indexOf('!_hasSubscription(data)') <
          billing.indexOf('_openingPortal ? null : _openPortal'),
      isTrue,
      reason: 'activation is offered before management, because a new business '
          'has nothing to manage',
    );
  });

  /// AND NEITHER IS OFFERED WHEN THERE IS NOTHING TO SELL.
  ///
  /// Making the activation screen reachable was correct and incomplete. It
  /// arrived at a plan selector fed by a catalog that is deliberately empty —
  /// commercial activation is frozen closed, no price is approved, and the
  /// screen reported that as "Pricing details are temporarily unavailable"
  /// with a Retry that could only fail again.
  test('activation is offered only when activation is actually open', () {
    expect(
      billing.contains('data.activation.open'),
      isTrue,
      reason: '"no subscription exists" is a different fact from '
          '"activation is open"',
    );
    // The closed state is not a dead end: it offers the conversation that
    // actually sets commercial terms.
    expect(billing.contains("context.go('/client/support')"), isTrue);
  });

  test('the closed state uses the server words, not the client guess', () {
    final subscribe = File(
      'lib/features/client/screens/client_subscribe_screen.dart',
    ).readAsStringSync();
    expect(subscribe.contains('_ActivationClosedCard'), isTrue);
    expect(subscribe.contains('activation.says'), isTrue);
    expect(subscribe.contains('activation.resolution'), isTrue);
    // No screen may invent a commercial reason of its own.
    expect(subscribe.contains('early access'), isFalse);
    expect(billing.contains('activation.says'), isTrue);
  });

  test('an older server is assumed to be selling, not shut', () {
    // Direction of the unknown matters: a deploy order where the app ships
    // first must not silently close commerce for everyone.
    expect(CommercialActivation.fromMap(null).open, isTrue);
    expect(CommercialActivation.fromMap(const {}).open, isTrue);
    expect(CommercialActivation.fromMap(const {'open': false}).open, isFalse);
    expect(CommercialActivation.fromMap(const {'open': true}).open, isTrue);
  });

  test('one commercial policy governs every rail', () {
    // Stripe honoured the freeze at the service boundary; the store rails did
    // not, because rail readiness was a purely technical question. The App
    // Store rail is the one about to be submitted for review.
    final readiness =
        backendSource('src/commerce-evidence/store-readiness.service.ts');
    expect(readiness.contains('COMMERCIAL_ACTIVATION_OPEN'), isTrue);
    final availability = readiness.substring(readiness.indexOf('async availability('));
    expect(
      availability.indexOf('COMMERCIAL_ACTIVATION_OPEN') <
          availability.indexOf('this.googlePlay('),
      isTrue,
      reason: 'a closed policy needs no provider call and is not a provider '
          'problem',
    );
  }, skip: backendSkipReason);

  test('a single chrome, wherever the screen is reached from', () {
    // Reached from Billing by a signed-in customer, the screen wrapped itself
    // in the signed-out funnel's AuthShell inside the client shell: a page
    // inside a page, two Orchestrate headers, and a "Back to site" exit out of
    // the workspace.
    final subscribe = File(
      'lib/features/client/screens/client_subscribe_screen.dart',
    ).readAsStringSync();
    expect(subscribe.contains('this.insideWorkspace = false'), isTrue);
    expect(subscribe.contains('if (widget.insideWorkspace)'), isTrue);
    expect(router.contains('ClientSubscribeScreen(insideWorkspace: true)'), isTrue);
  });

  test('iOS still refuses the external checkout route', () {
    // App Store 3.1.1. The route being reachable on web must not make it
    // reachable in the store build, where purchase happens through StoreKit.
    expect(iosPolicy.contains("'/client/subscribe'"), isTrue);
  });
}
