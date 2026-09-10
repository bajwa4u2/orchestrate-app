import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE SAME SENTENCE, TWICE, IN ONE CARD.
///
/// Plan & billing shows the entitlement's own sentence as the heading, the
/// reason underneath, and then names how the entitlement arose — because a
/// grant is not a purchase and must not be presented as one.
///
/// On an internal grant those two are the same words. The card read:
///
///   Internal operational access.
///   Access was granted directly rather than purchased, so it does not depend
///   on a billing period.
///   Internal operational access
///
/// Seen on a Pixel 9a and again in the Windows build. It reads as a rendering
/// fault rather than as emphasis, and it is the one place a customer looks to
/// understand what they hold.
///
/// The footnote now earns its place: it appears only when it adds something
/// the heading has not already said.
void main() {
  final source =
      File('lib/features/client/widgets/commercial_boundary.dart')
          .readAsStringSync();

  test('the source line is suppressed when it repeats the heading', () {
    expect(source.contains('String? _footnoteFor(Entitlement entitlement)'),
        isTrue);

    final fn = source.substring(source.indexOf('String? _footnoteFor'));
    final body = fn.substring(0, fn.indexOf('\n}'));

    // A purchase needs no source line at all — "you bought it" is what a
    // subscription means.
    expect(body.contains('EntitlementSource.paid'), isTrue);

    // And a grant only gets one where it says something new. Compared with
    // punctuation and case ignored, because the heading carries a full stop
    // and the label does not.
    expect(body.contains('toLowerCase'), isTrue);
    expect(body.contains('bare(label) == bare(says) ? null : label'), isTrue);
  });

  test('the panel takes its footnote from that decision, not inline', () {
    // The call site must not reconstruct the rule; one place decides.
    expect(source.contains('_footnoteFor(entitlement))'), isTrue);
    expect(
      source.contains('''entitlement.source == EntitlementSource.paid
                ? null
                : entitlement.source.label'''),
      isFalse,
      reason: 'the old inline rule printed the label unconditionally for '
          'every grant, including the one where it duplicated the heading',
    );
  });
}
