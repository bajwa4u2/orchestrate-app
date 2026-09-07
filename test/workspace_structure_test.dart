// A DESKTOP WINDOW IS NOT A PHONE BECAUSE THE TEXT IS LARGE.
//
// Every workspace breakpoint was measured in effective width — real width
// divided by the OS text scale. For the upper boundaries that is right: how
// many panes fit beside each other genuinely depends on how large the text is.
//
// Applying it to the phone boundary was wrong, and it was measured wrong in
// production rather than argued about. On the founder's machine a 1582px
// window is 1265.6 logical pixels at a device pixel ratio of 1.25, and with
// the OS enlarging text 1.75x that came out as 723 effective — under the 760
// phone boundary. The workspace served a bottom navigation bar, an app bar, no
// rail and one stacked column on a desktop monitor.
//
// That is the root of the enlarged-phone feeling. It was never a styling
// problem: the layout system had decided the machine WAS a phone.
//
// Whether there is a pointer, a keyboard and a window manager is not a
// function of type size. Somebody who enlarges text on a desktop wants larger
// text, not a different product.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/layout/workspace.dart';

void main() {
  /// Ask the layout system what it thinks a viewport is.
  Future<WorkspaceSize> classify(
    WidgetTester tester, {
    required double width,
    required double textScale,
  }) async {
    late WorkspaceSize seen;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Builder(
          builder: (context) {
            seen = Workspace.sizeOf(context, width);
            return const SizedBox();
          },
        ),
      ),
    );
    return seen;
  }

  testWidgets('the founder’s own window is not a phone', (tester) async {
    // The exact numbers measured from the running client.
    final size = await classify(tester, width: 1265.6, textScale: 1.75);
    expect(
      size.isPhone,
      isFalse,
      reason: 'a 1265 logical pixel desktop window was being served a phone '
          'layout because the OS was enlarging text',
    );
  });

  testWidgets('a real phone is still a phone', (tester) async {
    final size = await classify(tester, width: 390, textScale: 1.0);
    expect(size.isPhone, isTrue);
  });

  testWidgets('a phone with enlarged text is still a phone', (tester) async {
    // The boundary must not move in the other direction either.
    final size = await classify(tester, width: 390, textScale: 1.75);
    expect(size.isPhone, isTrue);
  });

  testWidgets('enlarged text still reduces how many panes fit', (tester) async {
    // The part of the old rule that was right, kept. A wide window with large
    // text genuinely holds fewer columns, and pretending otherwise would
    // crush them.
    final plain = await classify(tester, width: 1500, textScale: 1.0);
    final enlarged = await classify(tester, width: 1500, textScale: 1.75);

    expect(plain, WorkspaceSize.extraWide);
    expect(
      enlarged.index,
      lessThan(plain.index),
      reason: 'density still follows the text scale, only structure does not',
    );
    expect(enlarged.isPhone, isFalse);
  });

  testWidgets('a narrow desktop window becomes a phone by shape', (tester) async {
    final size = await classify(tester, width: 700, textScale: 1.0);
    expect(size.isPhone, isTrue);
  });

  // ── The rail is sized by what it has to say ────────────────────────

  testWidgets('the rail widens with the text it carries', (tester) async {
    late double plain;
    late double enlarged;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(1500, 900)),
      child: Builder(builder: (c) {
        plain = Workspace.railWidth(c);
        return const SizedBox();
      }),
    ));
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(
        size: Size(1500, 900),
        textScaler: TextScaler.linear(1.75),
      ),
      child: Builder(builder: (c) {
        enlarged = Workspace.railWidth(c);
        return const SizedBox();
      }),
    ));

    expect(enlarged, greaterThan(plain),
        reason: 'the rail was fixed at 232px while its labels followed the '
            'text scale, so enlarged labels had nowhere to go');
    // Capped, because past a point a navigation rail that keeps widening is
    // taking the work area hostage.
    expect(enlarged, lessThan(plain * 1.5));
  });

  testWidgets('the rail keeps its labels on a wide window', (tester) async {
    late bool collapsed;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(
        size: Size(1265.6, 900),
        textScaler: TextScaler.linear(1.75),
      ),
      child: Builder(builder: (c) {
        collapsed = Workspace.railIsCollapsed(c, 1265.6);
        return const SizedBox();
      }),
    ));

    expect(collapsed, isFalse,
        reason: 'the rail collapsed to icons on a wide monitor and took the '
            'destination labels and the business identity with it');
  });

  testWidgets('the rail collapses when the work would be squeezed',
      (tester) async {
    late bool collapsed;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(
        size: Size(820, 900),
        textScaler: TextScaler.linear(1.75),
      ),
      child: Builder(builder: (c) {
        collapsed = Workspace.railIsCollapsed(c, 820);
        return const SizedBox();
      }),
    ));

    expect(collapsed, isTrue,
        reason: 'a rail that keeps its labels at any cost leaves no work area');
  });
}
