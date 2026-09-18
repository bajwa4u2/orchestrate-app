// TYPING IN THE PICKER SEARCH HAS TO FILTER THE PICKER.
//
// It didn't. The scaffold that owns the TextField answered a keystroke by
// marking its OWN element dirty — but it is a StatelessWidget holding a
// `child` list that the parent state had already built, so rebuilding it
// re-rendered the same list. The parent, which computes the visible items
// from the search text, never rebuilt.
//
// The visible symptom: type "United States", and the list still reads
// Afghanistan, Albania, Algeria. It appeared to work only after ticking any
// checkbox, because that calls setState on the parent and recomputes the list
// as a side effect — which is why it looked intermittent rather than broken.
//
// Found on 2026-09-17 while completing setup on a real account, in the exact
// interaction Scene 3 of the Getting Started walkthrough films.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late final String source =
      File('lib/features/client/screens/client_setup_screen.dart')
          .readAsStringSync();

  group('the search reaches the state that owns the filter', () {
    test('both pickers listen to their own search controller', () {
      // Two pickers share the scaffold: countries and regions.
      expect(
        '_search.addListener(_onSearchChanged);'.allMatchesIn(source),
        2,
        reason: 'the country and region pickers must each rebuild on input',
      );
      expect(
        'void _onSearchChanged() {'.allMatchesIn(source),
        2,
        reason: 'each picker state owns its own rebuild',
      );
      expect(
        'if (mounted) setState(() {});'.allMatchesIn(source),
        2,
        reason: 'setState on the state that computes the list, not on the '
            'scaffold that merely displays it',
      );
    });

    test('the listener is removed before the controller is disposed', () {
      expect(
        '_search.removeListener(_onSearchChanged);'.allMatchesIn(source),
        2,
        reason: 'a listener outliving its controller is the next defect',
      );
      // Ordering matters: remove, then dispose.
      for (final block in source.split('void dispose() {').skip(1)) {
        final remove = block.indexOf('removeListener');
        final dispose = block.indexOf('_search.dispose()');
        if (remove == -1 || dispose == -1) continue;
        expect(remove < dispose, isTrue,
            reason: 'removeListener must come before dispose');
      }
    });

    test('the scaffold no longer pretends it can rebuild somebody else', () {
      expect(source.contains('markNeedsBuild'), isFalse,
          reason: 'marking a stateless scaffold dirty rebuilt the wrong thing, '
              'and reused the already-built child list');
    });
  });

  group('the filter itself is still what it was', () {
    test('it matches on label or code, and shows everything when empty', () {
      expect(source.contains('if (query.isEmpty) return true;'), isTrue);
      expect(
        source.contains('country.label.toLowerCase().contains(query)'),
        isTrue,
      );
      expect(
        source.contains('country.code.toLowerCase().contains(query)'),
        isTrue,
        reason: 'typing US must find United States',
      );
    });
  });
}

extension on String {
  int allMatchesIn(String source) => source.split(this).length - 1;
}
