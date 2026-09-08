import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
  final service =
      File('lib/features/support/services/support_service.dart').readAsStringSync();
  final controller = File(
    '../orchestrate_backend/src/support/client-support.controller.ts',
  ).readAsStringSync();

  test('the screen still makes the promise', () {
    expect(screen.contains('are attached'), isTrue);
  });

  test('the client sends the surface it promises to send', () {
    expect(
      screen.contains('sourcePage:'),
      isTrue,
      reason: 'the screen promises the surface travels and must send it',
    );
  });

  test('the transport carries every promised field', () {
    for (final field in ['sourcePage', 'message']) {
      expect(service.contains(field), isTrue, reason: 'missing: $field');
    }
  });

  test('the endpoint attaches the identity the screen names', () {
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
  });
}
