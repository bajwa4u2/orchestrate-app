import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// TEXT ON THE DARK GROUND MUST NAME ITS OWN COLOUR.
///
/// The public estate paints white cards on a dark canvas. A card that sets
/// `color: AppTheme.publicSurface` inherits the theme's near-black
/// `publicText` and reads perfectly. A container that is only an outline — a
/// border and no fill — inherits exactly the same near-black and puts it on the
/// near-black canvas.
///
/// The pricing card is the one outline on that page, and it had two texts and a
/// closing line relying on the inherited colour. On a Pixel 9a the heading and
/// the call to action were invisible. Nothing caught it: the analyzer has no
/// opinion on contrast, the widget tests never pump this screen because it
/// fetches from the network in `initState`, and at desktop width in a browser
/// the eye reads the white cards and skips the gap.
///
/// So this pins the colours. It is deliberately specific rather than a general
/// contrast rule — a general rule needs a real render, and this file is the
/// cheap guard that stops the known regression coming back in a refactor.
void main() {
  final source =
      File('lib/features/public/screens/commercial_model_screen.dart')
          .readAsStringSync();

  test('the unfilled pricing card names light colours', () {
    // The card is an outline over the canvas: border, no fill.
    expect(source.contains('AppTheme.publicAccent.withValues(alpha: 0.45)'),
        isTrue,
        reason: 'the pricing card is still the bordered outline this is about');

    // Heading, free-entry line and cadence note.
    expect(source.contains('AppTheme.publicOnDark'), isTrue);
    expect(source.contains('AppTheme.publicOnDarkMuted'), isTrue);

    // Three sites, and all three must survive a refactor: the pricing heading,
    // the two muted lines under it, and the closing invitation.
    final onDark = 'AppTheme.publicOnDark'.allMatches(source).length;
    expect(onDark, greaterThanOrEqualTo(4),
        reason: 'every text on the dark ground must carry an explicit colour');
  });

  test('the cadence cards keep a filled surface', () {
    // They may inherit the theme's dark text, because they paint themselves
    // white. If that fill ever goes, the prices go with it.
    expect(source.contains('class _CadenceCard'), isTrue);
    final card = source.substring(source.indexOf('class _CadenceCard'));
    expect(card.contains('color: AppTheme.publicSurface'), isTrue,
        reason: 'a cadence card without a fill would render its price '
            'near-black on the near-black canvas');
  });
}
