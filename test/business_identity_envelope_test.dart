import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Business hub read the wrong level of the identity response.
///
/// `/client/business-identity` answers `{ profile: {...}, sections: [...] }`.
/// Business identity unwraps it. The hub did not, so it read `legalName` and
/// `displayName` off the envelope, found null, and told every operator — in
/// red, as a problem — that the business had no trading name and no legal
/// name, while the surface one tap away showed both set.
///
/// Found on a Pixel by opening the two surfaces in sequence. It cannot be seen
/// in either file alone: both read their map correctly, and only the shape
/// underneath differs. This asserts they agree about that shape.
void main() {
  final hub = File('lib/features/client/screens/business_screen.dart')
      .readAsStringSync();
  final identity =
      File('lib/features/client/screens/client_business_identity_screen.dart')
          .readAsStringSync();

  test('Business identity unwraps the profile from the envelope', () {
    expect(identity.contains("asMap(raw['profile'])"), isTrue);
  });

  test('the Business hub unwraps the same envelope', () {
    expect(
      hub.contains("identity['profile']"),
      isTrue,
      reason: 'the hub must read the profile, not the response around it',
    );
  });

  test('the hub does not read identity fields off the envelope', () {
    // The failure mode was silent: a null read renders as "not set" rather
    // than as an error, so nothing on screen said the data had been missed.
    final assignsEnvelope = RegExp(r'_profile\s*=\s*results\[0\]\s*;');
    expect(
      assignsEnvelope.hasMatch(hub),
      isFalse,
      reason: 'assigning the raw envelope reintroduces the always-null read',
    );
  });
}
