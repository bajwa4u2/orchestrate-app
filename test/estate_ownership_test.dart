import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/sibling_backend.dart';

/// Where each fact is owned, asserted so it cannot drift back.
///
/// Workspace settings had become the screen everything landed on, because it
/// was the one nobody argued about. It held business readiness, a business
/// name, billing, records, the outbound signature and a person's trusted
/// devices — while Account & security, which links to it, held no security
/// controls at all.
///
/// Accumulation is not ownership, and it cost the estate concretely: two
/// editable business names free to disagree, a compliance footer nobody could
/// reach from the refusal that named it, and a security surface with no
/// security. These assertions describe the corrected estate.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final settings =
      read('lib/features/client/screens/client_settings_screen.dart');
  final accountLayer =
      read('lib/features/client/screens/account_layer_screen.dart');
  final mailbox = read('lib/features/client/screens/client_mailbox_screen.dart');
  final identity =
      read('lib/features/client/screens/client_business_identity_screen.dart');
  final signature =
      read('lib/features/client/widgets/signature_identity_card.dart');

  group('Account & security owns personal security', () {
    test('it holds the trusted devices, not a link to them', () {
      expect(accountLayer.contains('WHERE YOU ARE SIGNED IN'), isTrue);
      expect(accountLayer.contains('_TrustedDeviceRow'), isTrue);
      expect(accountLayer.contains('revokeTrustedDevice'), isTrue);
    });

    test('an unreachable device list is not reported as an empty one', () {
      expect(
        accountLayer.contains('Trusted devices could not be read'),
        isTrue,
        reason: 'a failed read must not claim the account is trusted nowhere',
      );
    });

    test('revoking a device is kept distinct from losing authority', () {
      // The source wraps this sentence, so assert the half that stays whole.
      expect(accountLayer.contains('business is not affected'), isTrue);
      expect(
        accountLayer.contains('does not touch it'),
        isTrue,
        reason: 'the authority row must say a device revoke leaves it alone',
      );
    });
  });

  group('Workspace settings owns preferences only', () {
    test('it no longer holds a person\'s sessions', () {
      expect(settings.contains('_TrustedDeviceRow'), isFalse);
      expect(settings.contains('revokeTrustedDevice'), isFalse);
      expect(settings.contains('fetchTrustedDevices'), isFalse);
    });

    test('it no longer restates business readiness', () {
      expect(settings.contains('BlockerResolutionList'), isFalse);
      expect(settings.contains('ClientMetricStrip'), isFalse);
    });

    test('it no longer carries the outbound signature', () {
      expect(settings.contains('SignatureIdentityCard'), isFalse);
    });

    test('it points at owners instead of reproducing them', () {
      expect(settings.contains('Where things are configured'), isTrue);
    });
  });

  group('the business name has exactly one writer', () {
    test('the signature card cannot write it', () {
      expect(
        signature.contains('businessName: _trimToNull'),
        isFalse,
        reason: 'the signature may display the name, never write it',
      );
      expect(signature.contains('_ReadOnlyLine'), isTrue);
    });

    test('the endpoint does not persist a signature business name', () {
      final portalService =
          backendSource('src/client-portal/client-portal.service.ts');
      expect(
        portalService.contains('businessName: sanitizeField'),
        isFalse,
        reason: 'this was the second writer',
      );
    }, skip: backendSkipReason);

    test('the renderer resolves it from the canonical record', () {
      final humanSignature =
          backendSource('src/communication/human-signature.ts');
      expect(humanSignature.contains('canonicalBusinessName'), isTrue);
      expect(
        humanSignature.contains('businessName: str(canonicalBusinessName)'),
        isTrue,
      );
    }, skip: backendSkipReason);
  });

  group('the postal address is owned where it is judged', () {
    test('Business identity can set it', () {
      expect(identity.contains('Registered address'), isTrue);
      expect(identity.contains('postalAddress'), isTrue);
    });

    test('it writes through the canonical designated-address record', () {
      final identityService =
          backendSource('src/business-identity/business-identity.service.ts');
      expect(identityService.contains('designateAddress'), isTrue);
    }, skip: backendSkipReason);
  });

  group('the signature sits with communication', () {
    test('Mailbox renders it', () {
      expect(mailbox.contains('SignatureIdentityCard'), isTrue);
    });
  });
}
