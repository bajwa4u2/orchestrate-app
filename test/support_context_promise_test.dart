import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/sibling_backend.dart';

/// The Support screen tells people what it attaches. That has to be true.
///
/// It promised the page you were on, and the request omitted sourcePage
/// entirely, so every client request recorded null. Of everything the screen
/// claims — name, email, business, plan, page — the page was the one item a
/// person cannot check for themselves, and it was the one that was false.
///
/// These assertions tie the sentence to the request that carries it.
void main() {
  final screen = File('lib/features/client/screens/client_support_screen.dart')
      .readAsStringSync();

  // DD-35: the screen's promises are now that Support sees where the business
  // stands, and that a person replies by email. Each is tied to the code
  // that keeps it.
  test('the screen promises Support sees the business, and it does', () {
    expect(screen.contains('Support sees where'), isTrue);
    final assistant = backendSource('src/support/support-assistant.service.ts');
    expect(assistant.contains('this.standing.forClient('), isTrue,
        reason: "an answer must be built from the business's standing");
  }, skip: backendSkipReason);

  test('the screen promises a person by email, and the handoff emails support', () {
    expect(screen.contains('A person replies by email within one business day.'), isTrue);
    final assistant = backendSource('src/support/support-assistant.service.ts');
    expect(assistant.contains('one business day'), isTrue);
    expect(assistant.contains('sendDirectEmail'), isTrue);
  }, skip: backendSkipReason);

  test('the endpoint attaches the identity the screen names', () {
    final controller =
        backendSource('src/support/client-support.controller.ts');
    // Person, address, business and plan are attached server-side from the
    // session rather than typed, which is exactly why the screen can promise
    // them. The business name was previously selected out and sent as null.
    for (final field in [
      'fullName',
      'email',
      'displayName',
      'legalName',
      'selectedPlan',
      'sourcePage',
    ]) {
      expect(
        controller.contains(field),
        isTrue,
        reason: 'support intake no longer carries: $field',
      );
    }
  }, skip: backendSkipReason);
}
