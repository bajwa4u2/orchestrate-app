import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/data/repositories/product_feedback_repository.dart';

/// CONFORMANCE TO THE CANONICAL CONTRACT.
///
/// The client is a second place the vocabulary can drift, and a client that
/// quietly invents a fourth intent or starts sending a forbidden field is
/// exactly as broken as a backend that does. So it is held to the same file
/// Aura's client is held to.
void main() {
  final contract = jsonDecode(
    File('contracts/product_feedback_contract.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('the three intents match the contract, exactly', () {
    final keys = (contract['intents'] as List)
        .map((i) => (i as Map)['key'] as String)
        .toSet();
    expect(FeedbackIntent.values.map((v) => v.wire).toSet(), keys);
  });

  test('the four lifecycle states match the contract, exactly', () {
    final states = ((contract['lifecycle'] as Map)['states'] as List)
        .cast<String>()
        .toSet();
    expect(FeedbackState.values.map((v) => v.wire).toSet(), states);
  });

  test('an unknown state from the wire does not blank the screen', () {
    // A backend one version ahead must not break a client that has not
    // updated yet.
    expect(FeedbackState.fromWire('SOMETHING_NEW'), FeedbackState.received);
    expect(FeedbackState.fromWire(null), FeedbackState.received);
  });

  group('what leaves the device', () {
    const ctx = FeedbackContext(
      product: 'orchestrate',
      platform: 'android',
      appVersion: '0.2.2',
      buildNumber: '11',
      surface: '/app',
      locale: 'en-GB',
    );

    test('carries only fields the contract allows', () {
      final allowed = ((contract['diagnosticContext'] as Map)['allowed'] as List)
          .cast<String>();
      for (final key in ctx.toJson().keys) {
        expect(allowed, contains(key), reason: '$key is not an allowed field');
      }
    });

    test('carries nothing the contract forbids', () {
      final forbidden =
          ((contract['diagnosticContext'] as Map)['forbidden'] as List)
              .cast<String>();
      final sent = ctx.toJson();
      for (final key in forbidden) {
        expect(sent.containsKey(key), isFalse,
            reason: '$key must never be sent');
      }
    });

    test('names the product, so one contract can serve several', () {
      expect(ctx.product, 'orchestrate');
    });

    test('the surface is a pattern, never a populated path', () {
      // A real path names a real client or campaign. The router reduces it to
      // a first segment and the server normalises it again.
      expect(ctx.surface, '/app');
      expect(RegExp(r'^/[a-z-]*$').hasMatch(ctx.surface!), isTrue);
    });
  });
}
