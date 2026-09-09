import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/sibling_backend.dart';

/// Branding claims a downstream effect. Only one of the two it claimed is real.
///
/// The screen said logo and colours appear on documents AND on the mail sent
/// on the business's behalf. Artifact generation does resolve branding and
/// writes primaryColor into the generated document. Correspondence does not:
/// client voice renders through communication/render-html, which carries no
/// branding, and the one template that does carry a logo is Orchestrate's own
/// platform mail, which must never wrap a client's message.
///
/// Somebody uploading a logo here reasonably expects it on their outbound.
/// These assertions keep the screen honest about where it does and does not
/// appear.
void main() {
  final screen = File('lib/features/client/screens/client_branding_screen.dart')
      .readAsStringSync();

  test('documents really do carry branding', () {
    final artifacts =
        backendSource('src/artifacts/artifact-generation.service.ts');
    expect(artifacts.contains('ClientIdentityResolverService'), isTrue);
    expect(
      artifacts.contains('primaryColor'),
      isTrue,
      reason: 'the screen promises documents carry the colour',
    );
  }, skip: backendSkipReason);

  test('the platform template still refuses to wrap client correspondence', () {
    final platformTemplate =
        backendSource('src/emails/templates/base.template.ts');
    expect(
      platformTemplate.contains('never wrap'),
      isTrue,
      reason: 'the separation this screen now describes is stated there',
    );
  }, skip: backendSkipReason);

  test('the screen does not claim branding reaches counterparties', () {
    expect(
      screen.contains('on the mail sent on its behalf'),
      isFalse,
      reason: 'that claim was false — correspondence carries no branding',
    );
    expect(screen.contains('do not appear on the messages'), isTrue);
  });
}
