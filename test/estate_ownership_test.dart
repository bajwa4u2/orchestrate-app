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

  final accountLayer =
      read('lib/features/client/screens/account_layer_screen.dart');
  final setup = read('lib/features/client/setup/one_path_setup_screen.dart');
  final signOff = read('lib/features/client/widgets/sign_off_section.dart');
  final actions = read('lib/features/client/widgets/account_actions.dart');

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

  // DD-34: the retired Workspace settings and Your account pages are gone;
  // what only they could do lives on Account & security.
  group('leaving is reachable inside the app', () {
    test('Account & security offers deactivate and delete', () {
      expect(accountLayer.contains('showDeactivateAccount(context)'), isTrue);
      expect(accountLayer.contains('showDeleteAccount(context)'), isTrue);
      expect(actions.contains('deleteClientAccount'), isTrue,
          reason: 'the app stores require account deletion inside the app');
    });

    test('a person edits their own name there', () {
      expect(accountLayer.contains('showOwnNameEditor(context)'), isTrue);
      expect(actions.contains('updateOwnName'), isTrue);
    });
  });

  group('the business name has exactly one writer', () {
    test('the sign-off cannot write it', () {
      expect(signOff.contains('businessName'), isFalse,
          reason: 'the signature may display the name, never write it');
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
    test('Setup sets it, every line of it', () {
      expect(setup.contains("'postalAddress'"), isTrue);
      expect(setup.contains("'line2'"), isTrue);
      expect(setup.contains("'region'"), isTrue);
    });

    test('it writes through the canonical designated-address record', () {
      final identityService =
          backendSource('src/business-identity/business-identity.service.ts');
      expect(identityService.contains('designateAddress'), isTrue);
    }, skip: backendSkipReason);
  });

  group('the signature sits with communication', () {
    test("Setup's email step renders it", () {
      expect(setup.contains('const SignOffSection()'), isTrue);
    });

    test('a save keeps the fields it does not show', () {
      expect(signOff.contains("complianceFooter: _k('complianceFooter')"), isTrue);
    });
  });
}
