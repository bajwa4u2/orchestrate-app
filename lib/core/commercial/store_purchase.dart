import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../data/repositories/client/client_capability_repository.dart';
import '../platform/billing_gate.dart';

/// BUYING ORCHESTRATE FROM INSIDE THE APP.
///
/// Deliberately thin. The device asks the store to take a payment and hands
/// what comes back to our own server; it decides nothing. A receipt sitting on
/// a phone is a claim, and the only thing that makes it evidence is Apple or
/// Google confirming it to our backend.
///
/// So this never grants a capability, never writes an entitlement, and never
/// believes `purchaseStatus == purchased` on its own. The one thing it is
/// careful about is the ORDER of operations:
///
///   1. ask the server to record which organisation is buying
///   2. carry that token into the store purchase
///   3. hand the store's answer back to the server
///   4. re-read entitlement from the server
///
/// Step 1 first, always. Apple and Google purchases are begun by a person's own
/// store account and neither store knows which company that person works for —
/// so if the token is not attached before the payment, there is no honest way
/// to work out afterwards who paid.
/// What a purchase surface needs from a store, and nothing else.
///
/// Exists so the orchestration above a store — intent before payment, delivery
/// after it, refusal in between — can be tested without a device. That ordering
/// is the part that decides whether a payment can be placed at all, and it is
/// not something to find out about for the first time on someone's phone.
abstract class StoreRail {
  /// Set by the surface that started a purchase, so completion can be reported
  /// where the person is looking rather than into a void.
  abstract void Function(StorePurchaseOutcome outcome)? onOutcome;

  void listen({required Future<void> Function(PurchaseDetails) deliver});

  Future<List<ProductDetails>> productsFor(Set<String> identifiers);

  Future<bool> buy({required ProductDetails product, required String intentKey});

  Future<void> restore();
}

class StorePurchase implements StoreRail {
  StorePurchase._();

  static final StorePurchase instance = StorePurchase._();

  final InAppPurchase _store = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  @override
  void Function(StorePurchaseOutcome outcome)? onOutcome;

  /// Whether this build can take a payment at all.
  ///
  /// Web and desktop cannot: there is no store binary underneath them, and
  /// their rail is the one Orchestrate bills directly.
  bool get availableOnThisPlatform => isAppStorePlatform;

  Future<bool> storeReachable() async {
    if (!availableOnThisPlatform) return false;
    return _store.isAvailable();
  }

  /// Begin listening for purchase results.
  ///
  /// Called once when a commercial surface appears. The stream also delivers
  /// purchases that completed while the app was closed and restores triggered
  /// from the store itself, which is why it is a subscription rather than a
  /// return value from `buy`.
  @override
  void listen({required Future<void> Function(PurchaseDetails) deliver}) {
    if (!availableOnThisPlatform || _subscription != null) return;
    _subscription = _store.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          await _handle(purchase, deliver);
        }
      },
      onError: (Object error) => onOutcome?.call(
        StorePurchaseOutcome.failed(
          'The store reported a problem. Nothing has been charged that we can see.',
        ),
      ),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _handle(
    PurchaseDetails purchase,
    Future<void> Function(PurchaseDetails) deliver,
  ) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        onOutcome?.call(StorePurchaseOutcome.pending());
        return;

      case PurchaseStatus.error:
        onOutcome?.call(StorePurchaseOutcome.failed(
          'The store could not complete that. Nothing has been activated.',
        ));
        break;

      case PurchaseStatus.canceled:
        onOutcome?.call(StorePurchaseOutcome.cancelled());
        break;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        // Handed to the server, which verifies it with the store and decides.
        // A device saying "purchased" is not an entitlement.
        await deliver(purchase);
        break;
    }

    // Completed regardless of what our server concluded.
    //
    // This acknowledges the transaction to the store, and both stores refund a
    // purchase that is never acknowledged. If our verification failed, the
    // right answer is a support conversation about a real payment — not a
    // silent refund caused by us leaving the transaction dangling.
    if (purchase.pendingCompletePurchase) {
      await _store.completePurchase(purchase);
    }
  }

  /// Fetch what the store will actually sell, by identifier.
  ///
  /// The identifiers come from the server, not from a constant here. A client
  /// that carries its own product list is a second commercial doctrine, and it
  /// will be the one that is out of date.
  @override
  Future<List<ProductDetails>> productsFor(Set<String> identifiers) async {
    if (!availableOnThisPlatform || identifiers.isEmpty) return const [];
    final response = await _store.queryProductDetails(identifiers);
    if (response.error != null) return const [];
    return response.productDetails;
  }

  /// Ask the store to take a payment for one organisation.
  ///
  /// `intentKey` is not optional and not derived here — it comes from the
  /// server, which recorded which organisation is buying before this was
  /// called. Both stores carry it through unchanged and hand it back on the
  /// transaction, which is the only deterministic way a store purchase can
  /// name a company.
  @override
  Future<bool> buy({
    required ProductDetails product,
    required String intentKey,
  }) async {
    if (!availableOnThisPlatform) return false;

    final parameters = PurchaseParam(
      productDetails: product,
      // Apple returns this as `appAccountToken`; Google as
      // `obfuscatedExternalAccountId`. Same purpose, same value.
      applicationUserName: intentKey,
    );
    return _store.buyNonConsumable(purchaseParam: parameters);
  }

  /// Ask the store to replay what this account already bought.
  ///
  /// Results arrive on the purchase stream as `restored`, go to the server like
  /// any other purchase, and are reconciled there. A restore that the server
  /// cannot tie to an organisation is refused rather than attached to whichever
  /// workspace happens to be open.
  @override
  Future<void> restore() async {
    if (!availableOnThisPlatform) return;
    await _store.restorePurchases();
  }
}

/// What happened, in words a person can read.
@immutable
class StorePurchaseOutcome {
  const StorePurchaseOutcome._(this.kind, this.says);

  factory StorePurchaseOutcome.pending() => const StorePurchaseOutcome._(
        StorePurchaseKind.pending,
        'Waiting for the store to confirm. Nothing is active yet.',
      );

  factory StorePurchaseOutcome.cancelled() => const StorePurchaseOutcome._(
        StorePurchaseKind.cancelled,
        'Cancelled. Nothing has been charged.',
      );

  factory StorePurchaseOutcome.failed(String says) =>
      StorePurchaseOutcome._(StorePurchaseKind.failed, says);

  /// The store took the payment. Whether it becomes service is the server's
  /// answer, and this deliberately does not claim it.
  factory StorePurchaseOutcome.paid() => const StorePurchaseOutcome._(
        StorePurchaseKind.paid,
        'The store took the payment. We are confirming it with them now.',
      );

  /// The server verified it and the organisation is entitled.
  factory StorePurchaseOutcome.active(Entitlement entitlement) =>
      StorePurchaseOutcome._(StorePurchaseKind.active, entitlement.says);

  /// Verified, and it belongs to nobody we can identify.
  factory StorePurchaseOutcome.unplaceable(String says) =>
      StorePurchaseOutcome._(StorePurchaseKind.unplaceable, says);

  final StorePurchaseKind kind;
  final String says;
}

enum StorePurchaseKind { pending, cancelled, failed, paid, active, unplaceable }
