import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AN EMPTY SURFACE MUST NOT CLAIM AN EMPTY PLATFORM.
///
/// Every list in the operations console reads the organisation the session
/// belongs to. A platform operator signs in to Orchestrate Operations, which
/// holds no clients, no mailboxes, no domains and no campaigns of its own —
/// they belong to the businesses that use us, each inside their own
/// organisation. Production, on the day this was written: nine client
/// organisations holding nine clients, ten mailboxes, four domains, six
/// campaigns and thirty-nine held messages between them; the operator's own
/// organisation holding none of any of it.
///
/// So the console said "No clients found", "No mailboxes found", "No import
/// batches found", screen after screen, while the platform was operating
/// normally on the other side of a boundary it never mentioned. That reads as a
/// broken console, and it was read as one.
void main() {
  final dir = Directory('lib/features/ops_console');
  final screens = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('_screen.dart'))
      .toList();

  test('there are operator screens to check', () {
    expect(screens.length, greaterThanOrEqualTo(6));
  });

  test('no screen claims a global absence', () {
    final offenders = <String>[];
    for (final file in screens) {
      final source = file.readAsStringSync();
      // "found" is the tell: "No clients found" is a statement about the world.
      // "No clients in this organisation" is a statement about the boundary.
      for (final match
          in RegExp(r"'No[^']*found\.?'").allMatches(source)) {
        offenders.add('${file.uri.pathSegments.last}: ${match.group(0)}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'these say the platform has none, when what is true is that this '
          'organisation has none:\n${offenders.join('\n')}',
    );
  });

  test('the empty state explains the boundary once, in one place', () {
    final shared =
        File('lib/features/ops_console/ops_empty_state.dart').readAsStringSync();
    expect(shared.contains('class OpsEmptyState'), isTrue);
    expect(
      shared.contains('organisation you are signed in as'),
      isTrue,
      reason: 'the default detail must name why the surface is empty',
    );

    // Six near-identical private copies is how the wording drifted apart in the
    // first place. One component, one sentence.
    final copies = screens
        .where((f) => f.readAsStringSync().contains('class _EmptyState'))
        .map((f) => f.uri.pathSegments.last)
        .toList();
    expect(copies, isEmpty, reason: 'private empty states: ${copies.join(', ')}');
  });
}
