/// THE HEADER ACTIONS BELONG ON THE RIGHT EDGE.
///
/// Reported from the live site, twice. The sign-in / start-setup / menu group
/// sat a few hundred pixels short of the right edge on a wide window, so the
/// front door looked unfinished.
///
/// The cause was a Row of three flex children:
///
///     [ Flexible(brand), Spacer(), Flexible(actions) ]
///
/// `Spacer` is a Flexible too, and every one of them defaulted to `flex: 1`.
/// So the spacer was handed ONE THIRD of the free space instead of absorbing
/// it — and a loose Flexible that needs less than its share does not hand the
/// remainder back. The leftover simply sat unused at the right end.
///
/// It is a rendering fact, not a source-text fact, so this renders the header
/// and measures where things actually land. Two earlier fixes have to survive
/// it: the wordmark must not lose its last letters, and the buttons must not
/// run off the edge — so the narrow cases are asserted here too.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/app/shell/public_shell.dart';

Future<Rect> _headerAt(WidgetTester tester, double width) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(Size(width, 400));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PublicHeader(currentPath: '/', onHome: () {}),
      ),
    ),
  );
  await tester.pump();
  return tester.getRect(find.byType(PublicHeader));
}

void main() {
  testWidgets('the trailing group reaches the right edge of the frame',
      (tester) async {
    // A wide desktop window, which is where the gap was visible.
    final header = await _headerAt(tester, 1600);

    final menu = tester.getRect(find.byIcon(Icons.menu).first);
    final startSetup = tester.getRect(find.text('Start setup').first);
    final brand = tester.getRect(find.text('Orchestrate').first);

    // The frame is centred inside the header and capped at _maxFrameWidth,
    // with 28 of padding a side. Its right edge is therefore not the header's
    // right edge, and measuring against the wrong one is how a broken layout
    // could still look correct.
    final inner = header.width - 56;
    final frameWidth = inner < 1320 ? inner : 1320.0;
    final frameRight = (header.width + frameWidth) / 2;

    // Only the icon button's own internal padding may separate them. Before
    // the fix this gap was in the hundreds.
    expect(
      frameRight - menu.right,
      lessThan(16),
      reason: 'the menu button stopped ${(frameRight - menu.right).round()}px '
          'short of the frame edge',
    );

    // The buttons sit immediately before it, in order.
    expect(startSetup.right, lessThan(menu.left));
    // And the brand is still on the other side of the header.
    expect(brand.left, lessThan(startSetup.left));
  });

  testWidgets('nothing overflows at any width the header supports',
      (tester) async {
    // The two earlier defects: the wordmark was cut in half, and then the
    // buttons ran off the right edge. Neither may come back.
    for (final width in <double>[360, 480, 720, 900, 1280, 1600, 1920]) {
      await _headerAt(tester, width);
      expect(
        tester.takeException(),
        isNull,
        reason: 'the header overflowed at ${width.toInt()}px',
      );

      final brand = tester.getRect(find.text('Orchestrate').first);
      expect(
        brand.left,
        greaterThanOrEqualTo(-0.5),
        reason: 'the wordmark was painted off the left edge at $width',
      );

      final menu = tester.getRect(find.byIcon(Icons.menu).first);
      expect(
        menu.right,
        lessThanOrEqualTo(width + 0.5),
        reason: 'the menu button was painted off the right edge at $width',
      );
    }
  });

  testWidgets('the buttons appear once the window is wide enough',
      (tester) async {
    // Below the tablet breakpoint the menu carries navigation on its own; the
    // buttons must not be duplicated or stranded.
    await _headerAt(tester, 500);
    expect(find.text('Start setup'), findsNothing);
    expect(find.byIcon(Icons.menu), findsOneWidget);

    await _headerAt(tester, 1000);
    expect(find.text('Start setup'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });
}
