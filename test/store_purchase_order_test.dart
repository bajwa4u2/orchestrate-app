import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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
    await tester.tap(find.text('Subscribe'));
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
    await tester.tap(find.text('Subscribe'));
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
    await tester.tap(find.text('Subscribe'));
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
    await tester.tap(find.text('Subscribe'));
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

  @override
  Future<List<ProductDetails>> productsFor(Set<String> identifiers) async {
    calls.add('products');
    return [
      for (final id in identifiers)
        ProductDetails(
          id: id,
          title: 'Orchestrate',
          description: 'Operating access for your organisation.',
          price: r'$49.99',
          rawPrice: 49.99,
          currencyCode: 'USD',
        ),
    ];
  }

  @override
  Future<bool> buy({
    required ProductDetails product,
    required String intentKey,
  }) async {
    calls.add('buy');
    intentKeyUsed = intentKey;
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
          'productIds': {
            'APPLE_APP_STORE': 'com.orchestrateops.app.platform.monthly',
            'GOOGLE_PLAY': 'com.orchestrateops.app.platform.monthly',
          },
        },
      ],
    });
  }

  @override
  Future<StoreIntent> beginPurchase({
    required String rail,
    required String productId,
  }) async {
    calls.add('intent');
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
