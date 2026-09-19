import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/features/client/screens/client_setup_screen.dart';

/// Found filming Getting Started: a business that chose Michigan was offered
/// "District of Columbia" under "Suggestions from selected markets".
void main() {
  test('a chosen region confines suggestions to what was chosen', () {
    final s = metroSuggestionsFor(['US'], {'US-MI'}, const []);
    expect(s, isNot(contains('District of Columbia')));
  });

  test('with no region chosen, the country-wide city-type list remains', () {
    final s = metroSuggestionsFor(['US'], <String>{}, const []);
    expect(s, contains('District of Columbia'));
  });

  test('a metro already added is not suggested again', () {
    final s = metroSuggestionsFor(['US'], <String>{}, const ['district of columbia']);
    expect(s, isNot(contains('District of Columbia')));
  });
}
