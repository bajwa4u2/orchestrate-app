import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'support/sibling_backend.dart';
import 'package:orchestrate_app/data/repositories/client/store_purchase_repository.dart';

/// A PURCHASE PATH THAT CANNOT COMPLETE MUST NOT BE OFFERED.
///
/// Google is currently answering 401 permissionDenied — the service account
/// authenticates but is not linked to the Play listing. With a Subscribe button
/// still on screen, a person on Android would be charged by Google and then
/// refused by us: the worst of both, and a refund conversation rather than a
/// missing feature.
void main() {
  final panel = File('lib/features/client/widgets/store_subscribe_panel.dart')
      .readAsStringSync();

  test('the rail decides whether anything is offered', () {
    expect(panel.contains('_offerings?.rails[_rail]'), isTrue);
    // And the check comes BEFORE the products are rendered — a rail that
    // cannot verify must not reach the Subscribe button even when the store
    // happily lists products for it.
    expect(
      panel.indexOf('!availability.live') < panel.indexOf('_products.isEmpty'),
      isTrue,
      reason: 'a dead rail must be caught before anything is offered',
    );
  });

  test('the reason shown is the server\'s, not the client\'s guess', () {
    expect(panel.contains('availability.says'), isTrue);
    // The client holds a fallback for an older server, but never invents a
    // reason of its own about why a payment rail is down.
    expect(panel.contains('permissionDenied'), isFalse);
    expect(panel.contains('401'), isFalse);
  });

  test('an older server does not break an existing client', () {
    // A deploy order where the app ships before the server answers `rails`
    // must not silently disable purchasing for everyone.
    expect(RailAvailability.fromJson(null).live, isTrue);
    expect(RailAvailability.fromJson({}).live, isTrue);
    // But an explicit no is an explicit no.
    expect(RailAvailability.fromJson({'live': false}).live, isFalse);
    expect(RailAvailability.fromJson({'live': true}).live, isTrue);
  });

  test('the server refuses too, not only the screen', () {
    // A client build from last month does not know a rail went down, and the
    // money moves at the store before it reaches us.
    final controller =
        backendSource('src/commercial-policy/store-purchase.controller.ts');
    expect(controller.contains("code: 'RAIL_NOT_AVAILABLE'"), isTrue);
    final purchase = controller.substring(controller.indexOf('async purchase('));
    expect(
      purchase.indexOf('RAIL_NOT_AVAILABLE') < purchase.indexOf('this.verify('),
      isTrue,
      reason: 'refuse before verifying, so nothing is accepted on a dead rail',
    );
  }, skip: backendSkipReason);
}
