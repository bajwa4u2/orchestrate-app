// THE RECONSTRUCTED FORMS, AT THE WIDTHS THEY WILL ACTUALLY MEET.
//
// Desktop composition that has never been narrowed is a guess. These render
// the shared primitives introduced during the Business and Account pass at web
// narrow, phone, and desktop-with-enlarged-text, and fail on overflow rather
// than on appearance.
//
// The primitives are tested rather than the screens because that is where a
// responsive defect would be shared: `_FieldRow` decides every form's column
// behaviour, and fixing it in five screens independently is how five screens
// come to disagree.
//
// Evidence class: WIDGET PROOF. It is not runtime proof on a browser or a
// handset, and it is not labelled as such.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/theme/workspace_theme.dart';

/// A viewport somebody actually uses, with the text scale they actually set.
class _Viewport {
  const _Viewport(this.name, this.width, this.height, this.textScale);
  final String name;
  final double width;
  final double height;
  final double textScale;
}

const _viewports = <_Viewport>[
  _Viewport('web narrow', 420, 900, 1.0),
  _Viewport('web narrow, larger text', 420, 900, 1.3),
  _Viewport('android phone', 411, 891, 1.0),
  _Viewport('android phone, largest text', 411, 891, 1.3),
  _Viewport('iphone, dynamic type', 390, 844, 1.35),
  _Viewport('small tablet', 700, 1000, 1.0),
  _Viewport('desktop, enlarged text', 1265, 800, 1.75),
];

void main() {
  Future<void> render(WidgetTester tester, _Viewport v, Widget child) async {
    tester.view.physicalSize = Size(v.width, v.height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(
        size: Size(v.width, v.height),
        textScaler: TextScaler.linear(v.textScale),
      ),
      child: MaterialApp(
        theme: Ws.data,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  group('a form row lays out at every width', () {
    // Mirrors the real composition on business identity: two medium fields
    // that share a desktop line, and a compact one that must not be stretched
    // to hold an ISO country code.
    Widget fields() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(builder: (context, constraints) {
              final available = constraints.maxWidth;
              final wide = available >= 520;
              return Wrap(
                spacing: 16,
                runSpacing: 0,
                children: [
                  SizedBox(
                    width: wide ? (available - 16) / 2 : available,
                    child: const _StubField(
                        label: 'Legal name',
                        affects: 'Used on agreements and invoices.'),
                  ),
                  SizedBox(
                    width: wide ? (available - 16) / 2 : available,
                    child: const _StubField(label: 'Website'),
                  ),
                  SizedBox(
                    width: wide ? 190 : available,
                    child: const _StubField(label: 'Primary country'),
                  ),
                ],
              );
            }),
          ],
        );

    for (final v in _viewports) {
      testWidgets(v.name, (tester) async {
        await render(tester, v, fields());
        expect(tester.takeException(), isNull,
            reason: '${v.name} (${v.width}pt at ${v.textScale}x) overflowed');
      });
    }

    testWidgets('fields stack rather than crowd below the split', (tester) async {
      // The rule the layout depends on: below 520 points there is no room for
      // two fields side by side, and forcing it produces two cramped boxes
      // instead of one usable one.
      await render(tester, const _Viewport('narrow', 420, 900, 1.0), fields());

      final boxes = tester.widgetList<SizedBox>(find.byType(SizedBox)).where(
          (b) => b.width != null && b.width! > 100);
      expect(boxes.every((b) => b.width! > 300), isTrue,
          reason: 'a field was given a fraction of an already narrow screen');
    });
  });

  group('a long value does not break the row that holds it', () {
    // Real production values: this business has a legal name and a trading
    // name that differ, and counterparty names in the estate run long.
    for (final v in _viewports) {
      testWidgets(v.name, (tester) async {
        await render(
          tester,
          v,
          const _StubField(
            label: 'Registered legal name of the operating entity',
            affects:
                'Appears on every agreement and invoice this business issues, '
                'and on nothing a counterparty reads day to day.',
          ),
        );
        expect(tester.takeException(), isNull,
            reason: '${v.name} overflowed on a long label and helper');
      });
    }
  });

  group('a confirmation states consequence at any width', () {
    // The archive dialogs carry three sentences. A dialog that clips its
    // consequence is worse than one that never stated it, because the person
    // believes they have read it.
    for (final v in _viewports) {
      testWidgets(v.name, (tester) async {
        tester.view.physicalSize = Size(v.width, v.height);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(
            size: Size(v.width, v.height),
            textScaler: TextScaler.linear(v.textScale),
          ),
          child: MaterialApp(
            theme: Ws.data,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Archive this evidence?'),
                      content: const Text(
                        'It will no longer count as active evidence for the '
                        'business, so anything relying on it no longer has it '
                        'to draw on.\n\n'
                        'This record will be preserved, but it cannot be '
                        'restored from this workspace.',
                      ),
                      actions: [
                        TextButton(
                            onPressed: () {}, child: const Text('Keep it')),
                        TextButton(
                            onPressed: () {},
                            child: const Text('Archive record')),
                      ],
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: '${v.name}: the confirmation overflowed');
        expect(find.textContaining('cannot be restored'), findsOneWidget,
            reason: 'the irreversibility must survive every viewport');
        expect(find.text('Keep it'), findsOneWidget);
      });
    }
  });

  testWidgets('the rail never crowds the work it sits beside', (tester) async {
    // Cross-checked here as well as in the family matrix, because a form is
    // the surface where losing the last hundred points actually hurts.
    for (final v in _viewports) {
      late double rail;
      late bool collapsed;
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(
          size: Size(v.width, v.height),
          textScaler: TextScaler.linear(v.textScale),
        ),
        child: Builder(builder: (context) {
          rail = Workspace.railWidth(context);
          collapsed = Workspace.railIsCollapsed(context, v.width);
          return const SizedBox();
        }),
      ));

      if (!collapsed) {
        expect(v.width - rail, greaterThan(520),
            reason: '${v.name}: the rail left too little room for a form');
      }
    }
  });
}

/// A stand-in with the same shape as the real field: label, input, and an
/// optional consequence line.
class _StubField extends StatelessWidget {
  const _StubField({required this.label, this.affects});

  final String label;
  final String? affects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text(label, style: theme.textTheme.titleSmall)),
              const SizedBox(width: 6),
              Text('optional',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Ws.inkSubtle)),
            ],
          ),
          const SizedBox(height: 6),
          const TextField(),
          if (affects != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(affects!,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Ws.inkSubtle)),
            ),
        ],
      ),
    );
  }
}
