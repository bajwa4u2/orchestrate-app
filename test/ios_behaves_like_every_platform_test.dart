/// iOS IS NOT A DIFFERENT PRODUCT.
///
/// The App Store build used to route through its own policy: registration,
/// setup, plan selection, subscription and the entire public site were
/// unreachable, and an unauthenticated visitor resolved to sign-in whatever
/// they opened. On the sign-in screen itself the "Create workspace" affordance
/// was replaced by a note saying accounts are set up on the web.
///
/// That was written for App Store Guideline 3.1.1 at a time when the app could
/// not take a payment. Every route toward a plan ended at a web checkout, and
/// sending someone out to pay is exactly what 3.1.1 forbids, so the routes were
/// blocked wholesale.
///
/// In-app purchase is wired now. The reason is gone and only the cost remains:
/// a person could not create an account on an iPhone, and neither could an App
/// Reviewer — which is its own rejection.
///
/// 3.1.1 is still enforced, by the control that actually states it rather than
/// by hiding screens. These assertions hold that line in both directions: the
/// routing special case must not come back, and the external-purchase ban must
/// not be relaxed along with it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('the router has no iOS-only branch', () {
    final router = _read('lib/app/routing/app_router.dart');

    // The whole mechanism, gone: the policy file, its import, and the call.
    expect(File('lib/core/platform/ios_route_policy.dart').existsSync(), isFalse,
        reason: 'the iOS routing policy file should be retired, not kept dormant');
    expect(router.contains('ios_route_policy'), isFalse);
    expect(router.contains('iosRouteRedirect'), isFalse);

    // And no new one wearing a different name: the router must not branch on
    // the platform at all.
    expect(router.contains('isIosAppStorePlatform'), isFalse,
        reason: 'routing must not depend on which store shipped the binary');
    expect(router.contains('isPlayStorePlatform'), isFalse);
  });

  test('sign-in offers account creation on every platform', () {
    final login = _read('lib/features/auth/screens/client_login_screen.dart');

    expect(login.contains('Create workspace'), isTrue);
    // The note that stood in for it is gone.
    expect(login.contains('New accounts are set up on the Orchestrate web'),
        isFalse);
    // And nothing on this screen is hidden by platform any more.
    expect(login.contains('isIosAppStorePlatform'), isFalse,
        reason: 'a reviewer on an iPhone must be able to create an account');
  });

  test('3.1.1 is still enforced, by the billing gate', () {
    // The narrower, truer control: no surface may send anyone OUT to pay.
    final gate = _read('lib/core/platform/billing_gate.dart');

    expect(gate.contains('bool get externalPurchaseAllowed => !isAppStorePlatform'),
        isTrue,
        reason: 'a store build must never offer an external purchase route');
    expect(gate.contains('bool get inAppPurchaseAllowed => isAppStorePlatform'),
        isTrue,
        reason: 'a store build takes payment through its own store');

    // The two questions stay apart. Collapsing them is what produced a build
    // that could sell nothing at all.
    expect(gate.contains('externalPurchaseAllowed'), isTrue);
    expect(gate.contains('inAppPurchaseAllowed'), isTrue);
  });

  test('the purchase surface is still gated on in-app purchase, not routing',
      () {
    final panel =
        _read('lib/features/client/widgets/store_subscribe_panel.dart');
    expect(panel.contains('if (!inAppPurchaseAllowed)'), isTrue,
        reason: 'the panel appears because a store can take the payment, '
            'not because of where the router allowed someone to go');
  });
}
