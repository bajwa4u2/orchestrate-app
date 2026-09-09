import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'package:orchestrate_app/core/commercial/client_capabilities.dart';
import 'package:orchestrate_app/core/commercial/store_purchase.dart';
import 'package:orchestrate_app/data/repositories/client/client_capability_repository.dart';
import 'package:orchestrate_app/data/repositories/client/store_purchase_repository.dart';
import 'package:orchestrate_app/features/client/widgets/store_subscribe_panel.dart';

/// THE ORDER A PAYMENT HAPPENS IN.
///
/// Neither Apple nor Google knows which company a person works for. A payment
/// that reaches us without the server-issued intent token cannot honestly be
/// placed afterwards — it becomes money taken from a business that is not
/// switched on, and a support conversation with no answer in it.
///
/// So the ordering is the product, not an implementation detail, and this
/// proves it on a machine rather than on someone's phone: intent first, store
/// second, delivery third. A device test can confirm the money moves. Only this
/// can confirm the money is attributable.
void main() {
  const projection = r'''
{"entitlement":{"organizationId":"org","clientId":"client","state":"ACTIVE","source":"PAID_SUBSCRIPTION","says":"Orchestrate is active for your organisation.","because":"Bought through the App Store.","isPayingCustomer":true,"executionActivated":true},"capabilities":[],"model":[],"note":""}
''';

  setUp(() {
    ClientCapabilities.instance.seed(null);
    ClientCapabilities.instance.useRepository(_FakeCapabilities(projection));
  });

  testWidgets('the organisation is recorded before the store is opened',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final log = <String>[];
    final store = _FakeRail(log);
    final repository = _FakeRepository(log);

    await _mount(tester, repository, store);
    // Monthly, which is the first of the two cadences now on screen.
    await tester.tap(find.text('Subscribe').first);
    await _settle(tester);

    // One log, written by both sides, because the claim is about the order two
    // separate systems were spoken to in. Two lists could not express it.
    expect(log.indexOf('intent') < log.indexOf('buy'), isTrue,
        reason: 'intent must be recorded before the store takes money');

    // And the token the server issued is the one carried into the purchase,
    // unaltered. A client that mints its own is a client that can attribute a
    // payment to a company that never agreed to it.
    expect(store.intentKeyUsed, 'intent-from-server');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a refused intent never opens the store, and says why',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final log = <String>[];
    final store = _FakeRail(log);
    final repository = _FakeRepository(log)
      ..intentOk = false
      ..intentReason = 'Only an owner or admin can start a subscription.';

    await _mount(tester, repository, store);
    // Monthly, which is the first of the two cadences now on screen.
    await tester.tap(find.text('Subscribe').first);
    await _settle(tester);

    expect(log, isNot(contains('buy')),
        reason: 'a member without billing authority must not reach a payment sheet');
    // The server's own sentence, not one this screen wrote about it.
    expect(find.textContaining('Only an owner or admin'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('what the store returns is the server\'s answer, not the device\'s',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final log = <String>[];
    final store = _FakeRail(log);
    final repository = _FakeRepository(log);

    await _mount(tester, repository, store);
    // Monthly, which is the first of the two cadences now on screen.
    await tester.tap(find.text('Subscribe').first);
    await _settle(tester);

    // The device now reports a completed purchase, exactly as the real stream
    // would once the payment sheet closes.
    store.emit(_purchase(PurchaseStatus.purchased, 'receipt-blob'));
    await _settle(tester);

    expect(repository.deliveredPayload, 'receipt-blob');
    expect(repository.deliveredRail, 'APPLE_APP_STORE');
    expect(find.textContaining('Orchestrate is active'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a payment the server cannot place is not claimed as service',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final log = <String>[];
    final store = _FakeRail(log);
    final repository = _FakeRepository(log)
      ..verifyOk = false
      ..verifyReason = 'That purchase is not tied to any organisation here.';

    await _mount(tester, repository, store);
    // Monthly, which is the first of the two cadences now on screen.
    await tester.tap(find.text('Subscribe').first);
    await _settle(tester);
    store.emit(_purchase(PurchaseStatus.purchased, 'orphan-receipt'));
    await _settle(tester);

    expect(find.textContaining('not tied to any organisation'), findsOneWidget);
    expect(find.textContaining('is active'), findsNothing,
        reason: 'an unplaceable payment must never read as switched on');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('an organisation that already operates is not sold to again',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final log = <String>[];
    final store = _FakeRail(log);
    final repository = _FakeRepository(log)..alreadyActive = true;

    await _mount(tester, repository, store);

    expect(find.text('Subscribe'), findsNothing,
        reason: 'selling a second subscription is a refund conversation');
    expect(find.textContaining('active for your organisation'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("both cadences are offered, at the store's own prices",
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final log = <String>[];
    final store = _FakeRail(log);
    final repository = _FakeRepository(log);

    await _mount(tester, repository, store);

    // The old model held one product id per rail, so annual was not merely
    // unsold — it could not be represented. Two rows is the whole repair.
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Annual'), findsOneWidget);

    // Prices are the store's strings, verbatim. Nothing here formats a number
    // or names a currency: a price typed into the app is wrong for most of the
    // world on the day it is typed.
    expect(find.text(r'$29.99'), findsOneWidget);
    expect(find.text(r'$299.99'), findsOneWidget);

    // And the cheaper one is not a lesser product. Said plainly, because two
    // prices side by side is exactly where a person assumes otherwise.
    expect(find.textContaining('only difference is how often'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('on Google, the cadence tapped is the base plan reported',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final log = <String>[];
    final store = _FakeRail(log);
    final repository = _FakeRepository(log);

    await _mount(tester, repository, store);

    // Google returns two entries carrying the SAME product id. A surface that
    // reads only `id` cannot tell them apart, and would report whichever it
    // happened to hold — buying one cadence and recording the other.
    await tester.tap(find.text('Subscribe').last);
    await _settle(tester);

    expect(repository.intentProductId, 'orchestrate_platform');
    expect(repository.intentBasePlanId, 'annual',
        reason: 'the annual button must report the annual base plan');

    // THE PART THAT MATTERS: what was reported and what was handed to the
    // store are the same offer. Reporting 'annual' while buying the monthly
    // offer token is a person charged for one thing and recorded as another,
    // and every claim-side assertion above would still pass while it happened.
    expect(basePlanIdOf(store.boughtProduct!), 'annual');
    expect(store.boughtProduct!.price, r'$299.99');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a cadence the store does not sell is not shown', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final log = <String>[];
    final store = _FakeRail(log)..missing = const {'annual'};
    final repository = _FakeRepository(log);

    await _mount(tester, repository, store);

    // The server names both cadences; this console only configured one. The
    // honest response is one fewer button — never the monthly entry shown
    // under an annual heading because the ids happened to match.
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Annual'), findsNothing);
    expect(find.text('Subscribe'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop shows nothing, because there is no store underneath it',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final log = <String>[];
    final store = _FakeRail(log);
    final repository = _FakeRepository(log);

    await _mount(tester, repository, store);

    expect(find.text('Subscribe'), findsNothing);
    expect(log, isEmpty,
        reason: 'a rail billed directly must not even ask the store anything');
    debugDefaultTargetPlatformOverride = null;
  });
}

Future<void> _mount(
  WidgetTester tester,
  StorePurchaseRepository repository,
  StoreRail store,
) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: StoreSubscribePanel(repository: repository, store: store),
      ),
    ),
  ));
  await _settle(tester);
}

/// Bounded pumps rather than pumpAndSettle: a spinner animates forever, so a
/// settle would time out on the defect instead of reporting it.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

PurchaseDetails _purchase(PurchaseStatus status, String server) => PurchaseDetails(
      productID: 'com.orchestrateops.app.platform.monthly',
      verificationData: PurchaseVerificationData(
        localVerificationData: server,
        serverVerificationData: server,
        source: 'app_store',
      ),
      transactionDate: null,
      status: status,
    );

class _FakeRail implements StoreRail {
  _FakeRail(this.calls);

  /// Shared with the repository fake, so ordering across the two is observable.
  final List<String> calls;
  String? intentKeyUsed;
  ProductDetails? boughtProduct;
  Future<void> Function(PurchaseDetails)? _deliver;

  @override
  void Function(StorePurchaseOutcome outcome)? onOutcome;

  @override
  void listen({required Future<void> Function(PurchaseDetails) deliver}) {
    _deliver = deliver;
  }

  /// Stand in for the purchase stream, which in life delivers results the app
  /// did not ask for: completions from a previous launch, and restores begun
  /// from the store itself.
  void emit(PurchaseDetails purchase) => _deliver?.call(purchase);

  /// Cadences this fake store refuses to return, by base plan or product id.
  /// Stands in for a console that was never finished configuring.
  Set<String> missing = const {};

  @override
  Future<List<ProductDetails>> productsFor(Set<String> identifiers) async {
    calls.add('products');
    final details = <ProductDetails>[];
    for (final id in identifiers) {
      if (missing.contains(id)) continue;
      if (id == 'orchestrate_platform') {
        // GOOGLE'S REAL SHAPE: one subscription, several base plans, returned
        // as several entries that all carry the SAME id. Built through the
        // package's own type rather than mimicked, because the thing under
        // test is precisely whether we can tell those entries apart.
        details.addAll(
          GooglePlayProductDetails.fromProductDetails(_googleSubscription(missing)),
        );
        continue;
      }
      details.add(ProductDetails(
        id: id,
        title: 'Orchestrate',
        description: 'Operating access for your organisation.',
        price: id.endsWith('annual') ? r'$299.99' : r'$29.99',
        rawPrice: id.endsWith('annual') ? 299.99 : 29.99,
        currencyCode: 'USD',
      ));
    }
    return details;
  }

  @override
  Future<bool> buy({
    required ProductDetails product,
    required String intentKey,
  }) async {
    calls.add('buy');
    intentKeyUsed = intentKey;
    boughtProduct = product;
    return true;
  }

  @override
  Future<void> restore() async => calls.add('restore');
}

class _FakeRepository implements StorePurchaseRepository {
  _FakeRepository(this.calls);

  final List<String> calls;
  bool alreadyActive = false;
  bool intentOk = true;
  String? intentReason;
  bool verifyOk = true;
  String? verifyReason;
  String? deliveredPayload;
  String? deliveredRail;
  String? intentProductId;
  String? intentBasePlanId;

  @override
  Future<StoreOfferings> fetchOfferings() async {
    calls.add('offerings');
    return StoreOfferings.fromJson(<String, dynamic>{
      'alreadyActive': alreadyActive,
      'entitlement': {
        'state': 'ACTIVE',
        'source': 'PAID_SUBSCRIPTION',
        'says': 'Orchestrate is active for your organisation.',
        'because': 'Bought through the App Store.',
        'isPayingCustomer': true,
      },
      'offerings': [
        {
          'code': 'PLATFORM',
          'says': 'Operating access for your organisation.',
          // What the server actually returns now: one offering, both cadences,
          // named the way each rail names them. Google carries the cadence in
          // a base plan under one subscription id; Apple in the product id.
          'plans': [
            {
              'rail': 'APPLE_APP_STORE',
              'period': 'MONTHLY',
              'productId': 'com.orchestrateops.app.platform.monthly',
              'basePlanId': null,
            },
            {
              'rail': 'APPLE_APP_STORE',
              'period': 'ANNUAL',
              'productId': 'com.orchestrateops.app.platform.annual',
              'basePlanId': null,
            },
            {
              'rail': 'GOOGLE_PLAY',
              'period': 'MONTHLY',
              'productId': 'orchestrate_platform',
              'basePlanId': 'monthly',
            },
            {
              'rail': 'GOOGLE_PLAY',
              'period': 'ANNUAL',
              'productId': 'orchestrate_platform',
              'basePlanId': 'annual',
            },
          ],
        },
      ],
    });
  }

  @override
  Future<StoreIntent> beginPurchase({
    required String rail,
    required String productId,
    String? basePlanId,
  }) async {
    calls.add('intent');
    intentProductId = productId;
    intentBasePlanId = basePlanId;
    return StoreIntent.fromJson(<String, dynamic>{
      'ok': intentOk,
      'intentKey': intentOk ? 'intent-from-server' : null,
      'reason': intentReason,
    });
  }

  @override
  Future<StoreVerification> deliverPurchase({
    required String rail,
    required Object payload,
  }) async {
    calls.add('deliver');
    deliveredRail = rail;
    deliveredPayload = payload as String;
    return StoreVerification.fromJson(<String, dynamic>{
      'ok': verifyOk,
      'says': verifyOk ? 'Orchestrate is active for your organisation.' : null,
      'reason': verifyReason,
      'activatedNow': verifyOk,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCapabilities implements ClientCapabilityRepository {
  _FakeCapabilities(this.body);
  final String body;

  @override
  Future<CapabilityProjection> fetch() async => CapabilityProjection.fromJson(
      Map<String, dynamic>.from(jsonDecode(body) as Map));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One Google subscription holding both cadences, priced as Google would price
/// them in a US storefront.
ProductDetailsWrapper _googleSubscription(Set<String> missing) =>
    ProductDetailsWrapper(
      description: 'Operating access for your organisation.',
      name: 'Orchestrate',
      title: 'Orchestrate',
      productId: 'orchestrate_platform',
      productType: ProductType.subs,
      subscriptionOfferDetails: [
        for (final plan in const [
          ('monthly', 'P1M', r'$29.99', 29990000),
          ('annual', 'P1Y', r'$299.99', 299990000),
        ])
          if (!missing.contains(plan.$1))
            SubscriptionOfferDetailsWrapper(
              basePlanId: plan.$1,
              offerTags: const [],
              offerIdToken: 'token-${plan.$1}',
              pricingPhases: [
                PricingPhaseWrapper(
                  billingCycleCount: 0,
                  billingPeriod: plan.$2,
                  formattedPrice: plan.$3,
                  priceAmountMicros: plan.$4,
                  priceCurrencyCode: 'USD',
                  recurrenceMode: RecurrenceMode.infiniteRecurring,
                ),
              ],
            ),
      ],
    );
