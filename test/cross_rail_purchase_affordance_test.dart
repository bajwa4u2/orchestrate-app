/// ONE PLATFORM ENTITLEMENT, MULTIPLE PAYMENT RAILS.
///
/// Found 2026-09-18, hours after the web Stripe rail opened. Billing decided
/// whether to offer a purchase by reading the Stripe `Subscription` record off
/// `/billing/subscription`. Apple and Google purchases are not in that table —
/// they are store purchase evidence — so for an App Store subscriber the record
/// was null and Billing offered them **"Activate a plan"** into Stripe
/// Checkout. They could have been charged twice for the same entitlement.
///
/// The store purchase panel had always asked the right question, through
/// `alreadyActive`. Only the web surfaces asked a Stripe-shaped one.
///
/// These pin both halves: the model can carry the answer, and neither web
/// surface is allowed to go back to reading a row.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/core/commercial/client_capabilities.dart';

Entitlement parse(Map<String, dynamic> json) => Entitlement.fromJson(json);

void main() {
  group('the entitlement carries which rail is billing', () {
    test('an App Store subscription names its rail', () {
      final e = parse({
        'state': 'ACTIVE',
        'source': 'PAID_SUBSCRIPTION',
        'ownedByRail': 'APPLE_APP_STORE',
        'isPayingCustomer': true,
      });
      expect(e.state.operating, isTrue);
      expect(e.ownedByRail, OwningRail.apple);
      expect(e.ownedByRail!.where, 'the App Store');
    });

    test('a Google Play subscription names its rail', () {
      final e = parse({'state': 'ACTIVE', 'ownedByRail': 'GOOGLE_PLAY'});
      expect(e.ownedByRail, OwningRail.google);
      expect(e.ownedByRail!.where, 'Google Play');
    });

    test('a Stripe subscription names its rail — the half that was missing', () {
      final e = parse({'state': 'ACTIVE', 'ownedByRail': 'STRIPE'});
      expect(e.ownedByRail, OwningRail.stripe);
    });

    test('a grant names no rail, because nobody is billing', () {
      final e = parse({
        'state': 'ACTIVE',
        'source': 'LEGACY_GRANTED_ACCESS',
        'ownedByRail': null,
      });
      expect(e.state.operating, isTrue, reason: 'granted access still operates');
      expect(e.ownedByRail, isNull);
      expect(e.isPayingCustomer, isFalse);
    });

    test('an unknown rail string is null rather than a wrong rail', () {
      // A rail this build does not know is not the nearest one it does.
      expect(parse({'ownedByRail': 'SOMETHING_NEW'}).ownedByRail, isNull);
    });
  });

  group('who may be offered a purchase', () {
    // The single question every purchase surface asks.
    bool mayBeOffered(String state) =>
        !parse({'state': state}).state.operating;

    test('an active subscriber may not be offered another purchase', () {
      expect(mayBeOffered('ACTIVE'), isFalse);
    });

    test('somebody mid payment-retry may not either', () {
      // The rail is still serving them. Selling a second subscription during a
      // retry charges for what they already have.
      expect(mayBeOffered('PAYMENT_ISSUE'), isFalse);
    });

    test('a lapsed customer may purchase again', () {
      expect(mayBeOffered('LAPSED'), isTrue);
    });

    test('a customer with no entitlement still sees the activation path', () {
      // Closing the double-sell must not close the legitimate sell.
      expect(mayBeOffered('NONE'), isTrue);
    });

    test('an unknown state is treated as no entitlement, not as active', () {
      expect(mayBeOffered('SOMETHING_ELSE'), isTrue);
    });
  });

  group('neither web surface may go back to reading a Stripe row', () {
    String read(String path) => File(path).readAsStringSync();

    const billing = 'lib/features/client/screens/client_billing_screen.dart';
    const subscribe = 'lib/features/client/screens/client_subscribe_screen.dart';

    test('Billing decides from the entitlement, not from a subscription record',
        () {
      final source = read(billing);
      expect(
        source.contains('_holdsPlatform()'),
        isTrue,
        reason: 'the purchase affordance must ask whether the platform is held',
      );
      expect(
        source.contains("data.subscription;"),
        isFalse,
        reason: 'the Stripe record must not decide whether to sell again',
      );
    });

    test('Billing offers the Stripe portal only for a Stripe subscription', () {
      // The portal is Stripe's and can only manage a Stripe subscription.
      // Offering it to an App Store subscriber sends them to a page about
      // somebody else's money; to a granted client it fails outright, because
      // a grant never created a Stripe customer.
      expect(
        read(billing).contains('_owningRail() == OwningRail.stripe'),
        isTrue,
      );
    });

    test('Billing waits for the answer before offering anything', () {
      // Offering a purchase before the entitlement is known lets an existing
      // subscriber buy a second one in the gap.
      expect(read(billing).contains('_entitlementKnown'), isTrue);
    });

    test('Subscribe refuses to price what the organisation already holds', () {
      final source = read(subscribe);
      expect(source.contains('holdsPlatform'), isTrue);
      expect(
        source.indexOf('holdsPlatform') < source.indexOf('_CadenceCard('),
        isTrue,
        reason: 'the check must come before the cadence cards are built',
      );
    });
  });
}
