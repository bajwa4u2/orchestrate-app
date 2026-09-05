import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A DESTINATION MUST BE THE PLACE IT SAYS IT IS.
///
/// Opening every client route found two navigation entry points promising
/// views the product does not have, and three promising sections by URL
/// fragment — which nothing in the app reads.
///
/// A person who searches the palette for "Pipeline", lands on the ordinary
/// relationships list and finds no board concludes the product is broken. The
/// truth is milder and worse: the view was never built, and two places kept
/// advertising it.
void main() {
  final palette =
      File('lib/features/client/widgets/command_palette.dart').readAsStringSync();
  final router = File('lib/app/routing/app_router.dart').readAsStringSync();
  final workspace =
      File('lib/features/client/screens/relationships_workspace_screen.dart')
          .readAsStringSync();

  test('nothing advertises a view that does not exist', () {
    expect(palette.contains('view=pipeline'), isFalse);
    expect(palette.contains('view=waiting'), isFalse);
    expect(router.contains('view=pipeline'), isFalse);
    // And the parameter that carried it is gone rather than left dangling:
    // it was declared, passed by the router, and read by nobody.
    expect(workspace.contains('initialView'), isFalse);
    expect(router.contains('initialView'), isFalse);
  });

  test('the palette names routes, not fragments', () {
    final commands = RegExp(r"_Command\('([^']+)', '([^']+)'")
        .allMatches(palette)
        .map((m) => (label: m.group(1)!, path: m.group(2)!))
        .toList();
    expect(commands, isNotEmpty);
    for (final c in commands) {
      expect(c.path.contains('#'), isFalse,
          reason: '"${c.label}" points at a fragment, which nothing reads');
    }
  });

  test('every palette destination is a route the app defines', () {
    final commands = RegExp(r"_Command\('[^']+', '([^']+)'")
        .allMatches(palette)
        .map((m) => m.group(1)!.split('?').first)
        .toSet();
    for (final path in commands) {
      expect(router.contains("path: '$path'"), isTrue,
          reason: '$path is offered but not routed');
    }
  });
}
