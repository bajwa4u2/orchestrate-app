import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// setState must not be handed a callback that returns a Future.
///
/// `setState(() => _future = _load())` looks like an assignment and is one,
/// but an arrow body evaluates to the assigned value — a Future — and Flutter
/// asserts: "setState() callback argument returned a Future". The screen
/// throws on the reload path, which is the path nobody exercises until a
/// person pulls to refresh.
///
/// Found when an in-process runtime test drove a screen I had just written,
/// and it would have thrown on the device. A sweep then found four more of the
/// same shape, all on reload paths. A peer session found one in Aura from the
/// same report, so the shape travels.
void main() {
  final dart = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  test('no setState arrow body assigns the result of an async call', () {
    // An arrow body assigning from a call whose name reads as a fetch. Kept
    // deliberately narrow: the point is the reload shape, not every assignment.
    final shape = RegExp(
      r'setState\(\(\)\s*=>\s*_?\w+\s*=\s*_?(load|fetch|refresh|reload|request)\w*\(',
      caseSensitive: false,
    );

    final offenders = <String>[];
    for (final file in dart) {
      final source = file.readAsStringSync();
      for (final match in shape.allMatches(source)) {
        final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
        offenders.add('${file.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'setState would receive a Future and assert at runtime: '
          '$offenders. Start the request outside setState and assign it '
          'inside a block body.',
    );
  });
}
