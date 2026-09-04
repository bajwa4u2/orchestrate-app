import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/data/repositories/client/client_capability_repository.dart';

/// THE EXACT BYTES PRODUCTION SENDS.
///
/// Plan & billing spun forever on a request that had already returned 200. Two
/// guesses about why were wrong, so this stops guessing: the real response body,
/// captured from the live API while signed in as the store-review workspace,
/// parsed by the real parser.
void main() {
  const live = r'''
{"entitlement":{"organizationId":"cmqb54jx30002bumqluayfyjp","clientId":"cmqb54jxk0004bumq7ejclakq","state":"ACTIVE","source":"STORE_REVIEW","says":"App-store review access.","because":"Access was granted directly rather than purchased, so it does not depend on a billing period.","isPayingCustomer":false,"executionActivated":false},"capabilities":[{"capability":"READ_OWN_RECORDS","permitted":true,"code":null,"why":null,"resolution":null},{"capability":"CONFIGURE_BUSINESS","permitted":true,"code":null,"why":null,"resolution":null},{"capability":"MANAGE_ACCOUNT","permitted":true,"code":null,"why":null,"resolution":null},{"capability":"EXPORT","permitted":true,"code":null,"why":null,"resolution":null},{"capability":"OPERATE_COMMERCIALLY","permitted":true,"code":null,"why":null,"resolution":null},{"capability":"RESEARCH_COUNTERPARTIES","permitted":true,"code":null,"why":null,"resolution":null},{"capability":"GOVERNED_EXECUTION","permitted":false,"code":"EXECUTION_SERVICE_NOT_ACTIVATED","why":"Orchestrate acting on your behalf is not part of what your organisation has activated.","resolution":"Add it from Plan & billing. Activating it makes it available; who may authorise a message stays a separate question."}],"model":[{"dimension":"PLATFORM_SUBSCRIPTION","means":"A subscription for your organisation, priced primarily at the level of the business rather than per seat."},{"dimension":"INCLUDED_OPERATING_CAPACITY","means":"A meaningful amount of operation is included, so ordinary use does not arrive as a bill."},{"dimension":"USAGE_EXPANSION","means":"Where a business consumes materially more, the cost grows with it."},{"dimension":"GOVERNED_EXECUTION","means":"Orchestrate acting on your behalf is a service you activate. Activating it makes it available; it never makes anyone authorised to represent you."},{"dimension":"ASSISTED_IMPLEMENTATION","means":"Where real setup, migration or integration work is needed, that is quoted separately. A business that sets itself up is not charged for it."}],"note":"Activating a plan makes capability available. It never authorises anyone to act on your behalf — who may do that stays yours to decide."}
''';

  test('the live production response parses', () {
    final json = Map<String, dynamic>.from(jsonDecode(live) as Map);
    final projection = CapabilityProjection.fromJson(json);

    expect(projection.entitlement.state, EntitlementState.active);
    expect(projection.entitlement.source, EntitlementSource.storeReview);
    // A review fixture is never a customer.
    expect(projection.entitlement.isPayingCustomer, isFalse);

    expect(projection.capabilities.length, 7);
    expect(projection.may('OPERATE_COMMERCIALLY'), isTrue);
    expect(projection.may('GOVERNED_EXECUTION'), isFalse);

    // The refusal that must never read as an authority refusal.
    final execution = projection.forCapability('GOVERNED_EXECUTION')!;
    expect(execution.code, 'EXECUTION_SERVICE_NOT_ACTIVATED');

    expect(projection.model.length, 5);
    expect(projection.model.first.dimension, 'PLATFORM_SUBSCRIPTION');
    expect(projection.note, contains('never authorises anyone'));
  });
}
