// THE SAME COMMERCIAL MODEL, COMPOSED FOR FOUR DIFFERENT MACHINES.
//
// Windows exposed the breakpoint defect first: a desktop window with the OS
// enlarging text was classified as a phone. The repair separated two things
// that had been multiplied together —
//
//   STRUCTURAL LAYOUT   = actual available composition space
//   ACCESSIBILITY SCALE = typography and control accommodation
//
// — and this audits that the separation holds across the client family rather
// than only on the machine where the bug was found.
//
// The profiles are real. Browser zoom changes the logical viewport rather than
// the text scaler, which is why web zoom appears here as a smaller size and
// not as a scale factor. Android and iOS accessibility text is a scaler on a
// viewport that does not change. Confusing those two is exactly how the
// original defect was written.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/layout/workspace.dart';

/// A machine somebody actually uses.
class Profile {
  const Profile(this.name, this.width, this.height, this.textScale,
      {required this.expectPhone});

  final String name;

  /// Logical pixels — what Flutter lays out in, after device pixel ratio.
  final double width;
  final double height;

  /// Accessibility text scaling, which must never decide structure.
  final double textScale;

  final bool expectPhone;
}

const profiles = <Profile>[
  // ── Windows ────────────────────────────────────────────────────────
  Profile('windows desktop', 1265.6, 720, 1.0, expectPhone: false),
  // The exact configuration that used to collapse into phone navigation.
  Profile('windows desktop, enlarged text', 1265.6, 720, 1.75, expectPhone: false),
  Profile('windows narrow window', 700, 800, 1.0, expectPhone: true),

  // ── Web ────────────────────────────────────────────────────────────
  Profile('web desktop', 1440, 900, 1.0, expectPhone: false),
  // Browser zoom shrinks the logical viewport; it is not a text scaler. At
  // 200% a 1440 window presents 720 logical pixels, and that genuinely is a
  // narrow composition space.
  Profile('web desktop at 200% zoom', 720, 450, 1.0, expectPhone: true),
  Profile('web narrow', 420, 900, 1.0, expectPhone: true),

  // ── Android ────────────────────────────────────────────────────────
  Profile('android phone', 411, 891, 1.0, expectPhone: true),
  // Accessibility text on a phone. Still a phone — the repair must not have
  // moved the boundary in this direction either.
  Profile('android phone, largest text', 411, 891, 1.3, expectPhone: true),
  Profile('android tablet', 800, 1280, 1.0, expectPhone: false),

  // ── iOS ────────────────────────────────────────────────────────────
  Profile('iphone', 390, 844, 1.0, expectPhone: true),
  Profile('iphone, dynamic type', 390, 844, 1.35, expectPhone: true),
  Profile('ipad', 1024, 1366, 1.0, expectPhone: false),
  Profile('ipad, dynamic type', 1024, 1366, 1.35, expectPhone: false),
];

void main() {
  Future<WorkspaceSize> classify(WidgetTester tester, Profile p) async {
    late WorkspaceSize seen;
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(
        size: Size(p.width, p.height),
        textScaler: TextScaler.linear(p.textScale),
      ),
      child: Builder(builder: (context) {
        seen = Workspace.sizeOf(context, p.width);
        return const SizedBox();
      }),
    ));
    return seen;
  }

  group('structure follows the machine, not the type size', () {
    for (final p in profiles) {
      testWidgets(p.name, (tester) async {
        final size = await classify(tester, p);
        expect(
          size.isPhone,
          p.expectPhone,
          reason: '${p.name}: ${p.width}pt at ${p.textScale}x should '
              '${p.expectPhone ? '' : 'not '}be phone structure',
        );
      });
    }
  });

  testWidgets('enlarging text never changes the structure on one machine',
      (tester) async {
    // The property the original defect violated, stated directly. Somebody who
    // enlarges text wants larger text, not a different product.
    for (final width in <double>[1265.6, 1440, 1024, 800, 411, 390]) {
      final plain = await classify(
          tester, Profile('w', width, 900, 1.0, expectPhone: false));
      final enlarged = await classify(
          tester, Profile('w', width, 900, 1.75, expectPhone: false));

      expect(
        plain.isPhone,
        enlarged.isPhone,
        reason: 'at ${width}pt, enlarging text changed whether this is a phone',
      );
    }
  });

  testWidgets('but enlarging text still reduces how many panes fit',
      (tester) async {
    // The half of the old rule that was correct, kept. A wide window with
    // large text genuinely holds fewer columns.
    final plain =
        await classify(tester, Profile('w', 1500, 900, 1.0, expectPhone: false));
    final enlarged =
        await classify(tester, Profile('w', 1500, 900, 1.75, expectPhone: false));

    expect(enlarged.index, lessThan(plain.index));
  });

  group('the rail adapts rather than disappearing', () {
    Future<({double width, bool collapsed})> rail(
        WidgetTester tester, Profile p) async {
      late double w;
      late bool c;
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(
          size: Size(p.width, p.height),
          textScaler: TextScaler.linear(p.textScale),
        ),
        child: Builder(builder: (context) {
          w = Workspace.railWidth(context);
          c = Workspace.railIsCollapsed(context, p.width);
          return const SizedBox();
        }),
      ));
      return (width: w, collapsed: c);
    }

    testWidgets('a desktop keeps its labels, enlarged text or not',
        (tester) async {
      for (final scale in <double>[1.0, 1.35, 1.75]) {
        final r = await rail(
            tester, Profile('w', 1265.6, 720, scale, expectPhone: false));
        expect(r.collapsed, isFalse,
            reason: 'the rail collapsed to icons at ${scale}x on a desktop');
      }
    });

    testWidgets('a tablet keeps its labels at ordinary text', (tester) async {
      final r =
          await rail(tester, Profile('t', 1024, 1366, 1.0, expectPhone: false));
      expect(r.collapsed, isFalse);
    });

    testWidgets('a narrow desktop collapses rather than crushing the work',
        (tester) async {
      final r =
          await rail(tester, Profile('n', 820, 900, 1.75, expectPhone: false));
      expect(r.collapsed, isTrue,
          reason: 'a rail that keeps its labels at any cost leaves no work area');
    });

    testWidgets('the rail never takes more than a quarter of a desktop',
        (tester) async {
      // Measured, because an uncapped rail took 27% of the founder's window
      // and that is a navigation bar wearing the work area's clothes.
      for (final scale in <double>[1.0, 1.35, 1.75]) {
        final r = await rail(
            tester, Profile('w', 1265.6, 720, scale, expectPhone: false));
        if (r.collapsed) continue;
        expect(r.width / 1265.6, lessThan(0.26),
            reason: 'the rail took ${(r.width / 1265.6 * 100).round()}% at '
                '${scale}x');
      }
    });
  });
}
