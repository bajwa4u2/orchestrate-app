import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE WORKSPACE MUST NOT ANIMATE BETWEEN ITS OWN SCREENS.
///
/// Reported from a real device: "a spin before loading every screen, a
/// transition which looks like overlapping."
///
/// Two causes, both real. Every route inside the two ShellRoutes used
/// `builder:`, which wraps the screen in a MaterialPage and therefore in the
/// platform's default page transition — the rail stays, being the shell, but
/// the content area slides and fades, so the outgoing screen and the incoming
/// one are painted over each other on every navigation. The marketing routes
/// had always used NoTransitionPage; the workspace never did.
///
/// And Today fetched into the screen's own State, which is destroyed on leaving
/// it, so returning to the first destination in the rail blanked the content
/// area behind a centred spinner and asked the server again — every time,
/// including when nothing had changed.
void main() {
  final router = File('lib/app/routing/app_router.dart').readAsStringSync();

  /// The text of one ShellRoute, bracket-balanced.
  String shell(int ordinal) {
    var at = -1;
    for (var seen = 0; seen <= ordinal; seen++) {
      at = router.indexOf('ShellRoute(', at + 1);
    }
    final open = router.indexOf('(', at);
    var depth = 0;
    for (var j = open; j < router.length; j++) {
      final c = router[j];
      if (c == '(') depth++;
      if (c == ')') {
        depth--;
        if (depth == 0) return router.substring(open, j);
      }
    }
    throw StateError('unbalanced ShellRoute');
  }

  for (final ordinal in <int>[0, 1]) {
    test('shell $ordinal builds pages that do not animate', () {
      final body = shell(ordinal);
      // The shell's own three-argument builder stays; no route inside it may
      // use the two-argument form, which is the one that animates.
      expect(
        body.contains('builder: (context, state) =>'),
        isFalse,
        reason: 'a route in this shell still uses the animating page builder',
      );
      expect(body.contains('NoTransitionPage(child:'), isTrue);
      expect(body.contains('builder: (context, state, child)'), isTrue,
          reason: "the shell's own builder must survive");
    });
  }

  test('today paints what it already knows', () {
    final holder = File('lib/core/today/client_today.dart').readAsStringSync();
    final screen =
        File('lib/features/client/screens/today_screen.dart').readAsStringSync();

    // The same shape Market and Relationships already had.
    expect(holder.contains('bool get hasAnswer => _state != null'), isTrue);
    expect(holder.contains('if (!refresh && _state != null)'), isTrue);

    // The spinner is only for having nothing at all, never for refreshing
    // something already on screen.
    expect(
      screen.contains('_today.isLoading && !_today.hasAnswer'),
      isTrue,
      reason: 'a refresh must not blank the screen',
    );
    // And returning does not re-ask.
    expect(
      screen.contains('if (!_today.hasAnswer && !_today.isLoading'),
      isTrue,
    );
  });
}
