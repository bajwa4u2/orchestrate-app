import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The visible return and the system Back must name the same destination.
///
/// §16's invariant: system Back = visible product return = semanticParentOf.
/// The account frame broke it by hardcoding Today while Android's Back went to
/// the semantic parent, so the same gesture meant two things depending on
/// whether a thumb landed on the screen or the navigation bar. Proven on a
/// Pixel, from Account & security.
///
/// A hardcoded destination is the shape of that bug: it cannot be wrong today
/// and right tomorrow, it is simply a second opinion. This asserts the return
/// controls ask the map rather than holding their own view.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('the account frame resolves its return from the map', () {
    final source =
        read('lib/features/client/screens/account_layer_screen.dart');
    expect(
      source.contains("onBack: () => context.go('/client/today')"),
      isFalse,
      reason: 'a hardcoded return is a second opinion about what contains a '
          'surface, and it disagreed with system Back',
    );
    expect(source.contains('semanticParentOf('), isTrue);
  });

  test('the workspace shell draws its return from the map', () {
    final shell = read('lib/app/shell/client_shell.dart');
    expect(shell.contains('semanticParentOf(widget.currentPath)'), isTrue);
  });

  test('system Back resolves through the same map', () {
    final router = read('lib/app/routing/app_router.dart');
    expect(
      router.contains('semanticParentOf(path)'),
      isTrue,
      reason: 'system Back must not hold its own opinion either',
    );
  });
}
