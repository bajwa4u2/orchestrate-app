/// NO TEST MAY SILENTLY REQUIRE THE OTHER REPOSITORY.
///
/// `test/support/sibling_backend.dart` exists because eight tests read
/// `../orchestrate_backend/...` directly. That path resolves on a machine with
/// both repositories side by side and nowhere else. CI clones one. They passed
/// locally, failed on the runner, and — because `flutter test` gates the iOS
/// build — took the build down at step six with something that looked like a
/// toolchain problem.
///
/// It happened again. Three more tests were written the old way and were only
/// caught by a simulator-certification build, forty seconds in, for the same
/// reason and with the same misleading appearance. The helper's own comment
/// said this must never happen again; nothing was enforcing it.
///
/// This enforces it. A test that reads the sibling checkout must go through
/// `backendSource` and carry `skip: backendSkipReason`, so where the checkout
/// is absent it says what is missing instead of failing the build.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no test reaches into the sibling backend by hand', () {
    final offenders = <String>[];

    for (final entity in Directory('test').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // The helper is the one place allowed to name the path, and this file
      // names it only to describe the rule.
      final name = entity.uri.pathSegments.last;
      if (name == 'sibling_backend.dart') continue;
      if (name == 'sibling_backend_guard_test.dart') continue;

      final source = entity.readAsStringSync();
      if (source.contains('orchestrate_backend')) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'these read the sibling checkout directly; use backendSource() '
          'with skip: backendSkipReason so they skip where it is absent '
          'instead of failing CI:\n  ${offenders.join('\n  ')}',
    );
  });

  test('every test that reads the backend can also skip', () {
    // Using the helper is not enough on its own: `backendSource` throws by
    // design where the checkout is missing, so a caller without the skip is
    // the same failure wearing a nicer name.
    final offenders = <String>[];

    for (final entity in Directory('test').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (!source.contains('backendSource(')) continue;
      if (!source.contains('skip: backendSkipReason')) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'these call backendSource() without ever skipping:\n'
          '  ${offenders.join('\n  ')}',
    );
  });
}
