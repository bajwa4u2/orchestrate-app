import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/core/navigation/workspace_map.dart';

/// Every surface the Business hub opens must be on the workspace map.
///
/// Four were not. The hub opens Credentials, Evidence, Artifacts and Branding
/// on `/app/...` paths, and the map and the bottom bar both knew only the
/// `/client/...` spellings. The consequence was invisible in either file: the
/// screens opened and rendered correctly, but carried no return, and the
/// bottom bar — which always highlights something — fell back to index 0 and
/// told the operator they were on Today.
///
/// Found by opening Credentials on a Pixel and noticing the bar disagreed with
/// the screen. This asserts the hub and the map cannot drift apart again.
void main() {
  final hub = File('lib/features/client/screens/business_screen.dart')
      .readAsStringSync();
  final shell =
      File('lib/app/shell/client_shell.dart').readAsStringSync();

  /// The `path: '...'` targets the hub's rows navigate to.
  Set<String> hubTargets() {
    final targets = <String>{};
    for (final m in RegExp(r"path:\s*'(/[^']+)'").allMatches(hub)) {
      targets.add(m.group(1)!);
    }
    for (final m in RegExp(r"context\.go\('(/[^']+)'\)").allMatches(hub)) {
      targets.add(m.group(1)!);
    }
    return targets;
  }

  test('the hub actually opens something', () {
    expect(hubTargets(), isNotEmpty);
  });

  test('every hub destination knows what contains it', () {
    final unmapped = <String>[];
    for (final path in hubTargets()) {
      if (isAreaLanding(path)) continue;
      if (semanticParentOf(path) == null) unmapped.add(path);
    }
    expect(
      unmapped,
      isEmpty,
      reason: 'these open with no return and no Back parent: $unmapped',
    );
  });

  test('every hub destination keeps the bottom bar honest', () {
    // The bar highlights index 0 when nothing matches, so an unlisted path
    // does not render "no selection" — it renders "Today".
    final absorbed = RegExp(r"absorbs:\s*\{([^}]*)\}", dotAll: true)
        .allMatches(shell)
        .expand((m) => RegExp(r"'(/[^']+)'").allMatches(m.group(1)!))
        .map((m) => m.group(1)!)
        .toSet();
    final destinations = RegExp(r"path:\s*'(/client/[^']+)'")
        .allMatches(shell)
        .map((m) => m.group(1)!)
        .toSet();

    final orphaned = <String>[];
    for (final path in hubTargets()) {
      final claimed = absorbed.contains(path) ||
          destinations.any((d) => path == d || path.startsWith('$d/'));
      if (!claimed) orphaned.add(path);
    }
    expect(
      orphaned,
      isEmpty,
      reason: 'the bar would show Today on these: $orphaned',
    );
  });
}
