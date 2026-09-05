import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// EVERY SURFACE MUST STAY REACHABLE BY SCROLLING.
///
/// The Work Queue held twenty-seven cases and showed three. The wheel did
/// nothing, on every operator and client surface, in production. Nothing in the
/// widget tree was wrong: `SelectionArea` wraps both shells so a person can copy
/// an address out of a case, and on web — while the browser's own context menu
/// is enabled — Flutter lays a real `<div>` over the entire selectable region to
/// host that menu. `Positioned.fill`, `pointer-events: auto`, above the canvas.
/// It swallowed the wheel silently: no error, no jank, just a workspace that
/// would not move past its first screenful.
///
/// This is a source test on purpose. The defect lives in the HTML the web
/// embedder emits, so it is invisible to a widget test and invisible to a
/// bundle grep; the only durable guard is the pairing itself — if a shell
/// selects text, startup must hand the context menu to Flutter.
void main() {
  final main = File('lib/main.dart').readAsStringSync();
  final shells = <String, String>{
    'operator': File('lib/app/shell/operator_shell.dart').readAsStringSync(),
    'client': File('lib/app/shell/client_shell.dart').readAsStringSync(),
  };

  test('a shell that selects text is paired with a disabled browser menu', () {
    final selecting = shells.entries
        .where((e) => e.value.contains('SelectionArea'))
        .map((e) => e.key)
        .toList();

    if (selecting.isEmpty) {
      // Nothing to guard. Stated rather than skipped so the reason is legible
      // if selection is ever reintroduced without the pairing.
      return;
    }

    expect(
      main.contains('BrowserContextMenu.disableContextMenu()'),
      isTrue,
      reason:
          'These shells wrap content in SelectionArea: ${selecting.join(', ')}. '
          'On web that inserts a full-size DOM overlay which blocks scrolling '
          'unless the browser context menu is handed to Flutter at startup.',
    );
  });

  test('the browser menu is disabled before the app is built', () {
    final disable = main.indexOf('BrowserContextMenu.disableContextMenu()');
    final run = main.indexOf('runApp(');

    expect(disable, greaterThan(-1));
    expect(run, greaterThan(-1));
    expect(
      disable,
      lessThan(run),
      reason:
          'SelectableRegion reads BrowserContextMenu.enabled when it builds. '
          'Disabling it afterwards leaves the overlay in place for the first '
          'screen a person sees, which is the screen they judge us on.',
    );
    expect(
      main.contains('await BrowserContextMenu.disableContextMenu()'),
      isTrue,
      reason: 'the call crosses a platform channel; an unawaited one can land '
          'after the first frame',
    );
  });

  test('scrolling is not restored by giving up selection', () {
    // The other way to remove the overlay is to delete SelectionArea. It would
    // work and it would cost an operator the ability to copy an address, an id
    // or a bounce reason out of a case — which is most of what reading one is
    // for. Recorded here so the cheap fix is a visible choice rather than a
    // quiet one.
    expect(
      shells['operator']!.contains('SelectionArea'),
      isTrue,
      reason: 'operators copy addresses and ids out of cases',
    );
    expect(
      shells['client']!.contains('SelectionArea'),
      isTrue,
      reason: 'clients copy addresses and ids out of their own records',
    );
  });
}
