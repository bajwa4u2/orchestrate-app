import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/commercial/client_capabilities.dart';
import '../../../core/commercial/store_purchase.dart';
import '../../../core/platform/billing_gate.dart';
import '../../../data/repositories/client/store_purchase_repository.dart';
import 'client_workspace_widgets.dart';

/// SUBSCRIBING FROM INSIDE THE APP.
///
/// The only surface in the product that can take a payment on a phone, and it
/// is deliberately small. It shows nothing it invented: the product name comes
/// from the server, the price comes from the store, and every sentence about
/// whether service is on was written by the authority that decided it.
///
/// It renders nothing at all on web and desktop. Those rails are billed
/// directly and a subscribe button here would be a second commercial doctrine.
class StoreSubscribePanel extends StatefulWidget {
  const StoreSubscribePanel({super.key, this.repository, this.store});

  /// Injected in tests. The real path is exercised, not a stub of it.
  final StorePurchaseRepository? repository;
  final StoreRail? store;

  @override
  State<StoreSubscribePanel> createState() => _StoreSubscribePanelState();
}

class _StoreSubscribePanelState extends State<StoreSubscribePanel> {
  late final StorePurchaseRepository _repository =
      widget.repository ?? StorePurchaseRepository();
  late final StoreRail _store = widget.store ?? StorePurchase.instance;

  StoreOfferings? _offerings;
  List<ProductDetails> _products = const [];
  Object? _loadError;
  bool _loading = true;

  /// Held from purchase-intent until the store answers, because the transaction
  /// that comes back has to be reported against the organisation that started
  /// it — not against whoever is signed in when it lands.
  String? _pendingRail;
  bool _buying = false;
  String? _message;
  bool _messageIsGood = false;

  String get _rail =>
      isIosAppStorePlatform ? 'APPLE_APP_STORE' : 'GOOGLE_PLAY';

  @override
  void initState() {
    super.initState();
    if (!inAppPurchaseAllowed) {
      _loading = false;
      return;
    }
    _store.onOutcome = _onOutcome;
    _store.listen(deliver: _deliver);
    _load();
  }

  @override
  void dispose() {
    _store.onOutcome = null;
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final offerings = await _repository.fetchOfferings();
      final ids = <String>{
        for (final offering in offerings.offerings)
          if (offering.productIdFor(_rail) != null) offering.productIdFor(_rail)!,
      };
      // Asked of the store, not assumed. A product that exists on our side and
      // not in the store is a configuration mistake, and the honest thing is to
      // show nothing rather than a button that cannot work.
      final products = await _store.productsFor(ids);
      if (!mounted) return;
      setState(() {
        _offerings = offerings;
        _products = products;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _subscribe(ProductDetails product) async {
    setState(() {
      _buying = true;
      _message = null;
    });

    // Order matters and this is the whole of it: the organisation is recorded
    // BEFORE the store is opened. Neither Apple nor Google knows which company
    // a person works for, so a payment that arrives without this token cannot
    // honestly be placed afterwards.
    try {
      final intent = await _repository.beginPurchase(
        rail: _rail,
        productId: product.id,
      );
      if (!intent.ok || intent.intentKey == null) {
        setState(() {
          _buying = false;
          _message = intent.reason ??
              'This cannot be purchased from this account right now.';
          _messageIsGood = false;
        });
        return;
      }

      _pendingRail = _rail;
      final opened = await _store.buy(
        product: product,
        intentKey: intent.intentKey!,
      );
      if (!opened && mounted) {
        setState(() {
          _buying = false;
          _message = 'The store did not open. Nothing has been charged.';
          _messageIsGood = false;
        });
      }
      // Otherwise the purchase stream carries it from here.
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _buying = false;
        _message = 'That could not be started. Nothing has been charged.';
        _messageIsGood = false;
      });
    }
  }

  /// Hand what the store said to the server, and show whatever it answers.
  Future<void> _deliver(PurchaseDetails purchase) async {
    final rail = _pendingRail ?? _rail;
    try {
      final verified = await _repository.deliverPurchase(
        rail: rail,
        payload: purchase.verificationData.serverVerificationData,
      );
      if (!mounted) return;

      // Entitlement is re-read through the same authority every other surface
      // uses, so the answer here cannot differ from the answer the workspace
      // shows a second later.
      await ClientCapabilities.instance.refresh();
      if (!mounted) return;

      setState(() {
        _buying = false;
        _message = verified.ok
            ? (verified.says ?? 'Purchase confirmed.')
            : (verified.reason ??
                'The store confirmed a payment we could not place. '
                    'Nothing has been switched on; please contact us and we '
                    'will sort it out.');
        _messageIsGood = verified.ok;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _buying = false;
        // Careful wording: the money may well have moved. Saying "nothing was
        // charged" here would be a lie the person can disprove on their card
        // statement.
        _message = 'We could not confirm that with the store just now. '
            'If a payment was taken it will be recognised — reopen this screen '
            'in a moment.';
        _messageIsGood = false;
      });
    }
  }

  void _onOutcome(StorePurchaseOutcome outcome) {
    if (!mounted) return;
    switch (outcome.kind) {
      case StorePurchaseKind.pending:
        setState(() => _message = outcome.says);
      case StorePurchaseKind.cancelled:
      case StorePurchaseKind.failed:
        setState(() {
          _buying = false;
          _message = outcome.says;
          _messageIsGood = false;
        });
      case StorePurchaseKind.paid:
      case StorePurchaseKind.active:
      case StorePurchaseKind.unplaceable:
        setState(() => _message = outcome.says);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _message = 'Asking the store what this account already bought…';
      _messageIsGood = false;
    });
    await _store.restore();
  }

  @override
  Widget build(BuildContext context) {
    // Web and desktop render nothing. There is no store underneath them.
    if (!inAppPurchaseAllowed) return const SizedBox.shrink();

    if (_loading) {
      return const ClientPanel(
        title: 'Subscription',
        children: [ClientEmptyState(message: 'Checking with the store…')],
      );
    }

    if (_loadError != null) {
      return ClientPanel(
        title: 'Subscription',
        children: [
          const ClientEmptyState(
            message: 'We could not reach the store just now. Any subscription '
                'you already have is unaffected.',
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ],
      );
    }

    final offerings = _offerings;

    // An organisation that already operates is not sold to again, on any rail.
    if (offerings != null && offerings.alreadyActive) {
      return ClientPanel(
        title: 'Subscription',
        children: [
          // The server's sentence, said once. Repeating it as both a heading
          // and a body reads as two facts when it is one.
          ClientInfoRow(
            title: offerings.entitlement?.says ??
                'Orchestrate is active for your organisation.',
            primary: offerings.entitlement?.because ?? '',
          ),
          const SizedBox(height: 12),
          Text(
            kStorePlanManagementNotice,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    // A RAIL THAT CANNOT VERIFY MUST NOT BE OFFERED.
    //
    // Google is currently refusing our service account, so a purchase on
    // Android would be taken by the store and then refused here — a charge
    // followed by a no, and a refund conversation. The server says which rails
    // can complete; where one cannot, this states it plainly rather than
    // rendering a Subscribe button that leads somewhere bad.
    final availability = _offerings?.rails[_rail];
    if (availability != null && !availability.live) {
      return ClientPanel(
        title: 'Subscription',
        children: [
          ClientEmptyState(
            message: availability.says ??
                'Subscribing is not available on this device yet.',
          ),
        ],
      );
    }

    if (_products.isEmpty) {
      return const ClientPanel(
        title: 'Subscription',
        children: [
          ClientEmptyState(
            message: 'Nothing is available to purchase on this device yet.',
          ),
        ],
      );
    }

    return ClientPanel(
      title: 'Subscription',
      subtitle: 'Billed by ${isIosAppStorePlatform ? 'the App Store' : 'Google Play'}, '
          'to your organisation. One subscription covers everyone in it.',
      children: [
        for (final product in _products) ...[
          ClientInfoRow(
            title: product.title.isEmpty ? product.id : product.title,
            // The price is the store's, read at the moment of purchase. It is
            // never held on our side, because the store is the only place it is
            // actually charged from.
            primary: product.price,
            secondary: product.description,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _buying ? null : () => _subscribe(product),
            child: Text(_buying ? 'Working…' : 'Subscribe'),
          ),
          const SizedBox(height: 18),
        ],
        // Required by both stores, and the right thing anyway: someone who
        // already paid, on another device or before a reinstall, must be able
        // to get their service back without paying twice.
        TextButton(
          onPressed: _buying ? null : _restore,
          child: const Text('Restore a purchase'),
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(
            _message!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _messageIsGood
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
          ),
        ],
      ],
    );
  }
}
