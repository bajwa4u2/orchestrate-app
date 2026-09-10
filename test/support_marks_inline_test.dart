import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/features/public/widgets/execution_visual_chapters.dart';

/// A ROW OF ENDORSEMENTS IS ONE ROW.
///
/// The support band laid its three marks out with a `Wrap`. Three marks at
/// 132 + 110 + 94 with 22 between them need 380 logical pixels; a Pixel 9a
/// offers 411 less the band's 56 of padding, which is 355. Twenty-five pixels
/// short — so the third mark dropped to a line of its own and the band read as
/// two supporters and an orphan.
///
/// It only shows on a narrow screen. Every desktop width fits all three, which
/// is why it survived review and had to be caught on a phone.
void main() {
  testWidgets('the marks stay on one line at phone width', (tester) async {
    // Narrower than the Pixel 9a's 411, so a Wrap would certainly break.
    tester.view.physicalSize = const Size(1080, 2424);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Align(
            alignment: Alignment.topLeft,
            child: OfficialSupportMarks(),
          ),
        ),
      ),
    ));
    await tester.pump();

    // Every entry sits at the same vertical offset: that is what "inline" is,
    // and it is checked by geometry rather than by asserting a widget type.
    // One badge and two programme names — see OfficialSupportMarks for why the
    // two are words rather than logos.
    final marks = find.byType(SizedBox).evaluate().where((e) {
      final box = e.widget as SizedBox;
      return box.height == 42;
    }).toList();
    expect(marks.length, 3, reason: 'all three support entries must render');
    expect(find.text('Google for Startups'), findsOneWidget);
    expect(find.text('AWS Activate'), findsOneWidget);

    final tops = marks
        .map((e) => (e.renderObject as RenderBox)
            .localToGlobal(Offset.zero)
            .dy
            .roundToDouble())
        .toSet();
    expect(tops.length, 1,
        reason: 'a second distinct top edge means a mark wrapped to its own '
            'row — the defect this exists to prevent');
  });

  test('the marks are not laid out with a Wrap', () {
    // Geometry above is the real check; this names the specific mistake so a
    // future refactor does not reintroduce it and then puzzle over the test.
    final source =
        File('lib/features/public/widgets/execution_visual_chapters.dart')
            .readAsStringSync();
    final widget = source.substring(source.indexOf('class OfficialSupportMarks'),
        source.indexOf('class _SupportAsset'));
    expect(widget.contains('Wrap('), isFalse,
        reason: 'Wrap gives up and drops a mark to the next line; FittedBox '
            'scales the set down together and keeps them inline');
    expect(widget.contains('FittedBox'), isTrue);
  });
}
