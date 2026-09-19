import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Not ready with nothing to resolve is still an answer.
///
/// Execution eligibility's blockers come from setup, authorisation and the
/// mailbox; its bucket also depends on the campaign and on what has been sent.
/// So a workspace with every gate green and no active campaign is not ready and
/// has no blocker. The Business hub told that workspace "Sending is not ready.
/// No reason was reported" — found on the packaged Windows build of 1.0.2
/// against a real workspace — while the evaluator's headline and description
/// said exactly why. This pins that the hub shows them.
void main() {
  final hub = File('lib/features/client/screens/business_screen.dart')
      .readAsStringSync();

  test('the no-blocker branch shows the evaluator headline and description', () {
    expect(hub.contains("_sending?['headline']"), isTrue);
    expect(hub.contains("_sending?['description']"), isTrue);
  });

  test('the hub no longer claims no reason was reported', () {
    expect(hub.contains('No reason was reported'), isFalse);
  });
}
