import 'global_setup_options.dart';

/// City/metro suggestions for setup. Top-level so the rule can be tested.
///
/// "SUGGESTIONS FROM SELECTED MARKETS" MEANS THE SELECTED ONES. This offered
/// every city-type subdivision of the whole country, so a business that chose
/// Michigan was offered "District of Columbia" -- a federal district nowhere
/// near its market. Once regions are chosen in a country, only those regions
/// are candidates. A country with no regions chosen still offers its
/// city-type subdivisions. Also offers towns in the one-path setup (DD-26).
List<String> metroSuggestionsFor(
  Iterable<String> countryCodes,
  Set<String> regionCodes,
  Iterable<String> metroNames,
) {
  final suggestions = <String>{};
  for (final countryCode in countryCodes) {
    final all = GlobalSetupOptions.regionsForCountry(countryCode);
    final chosen = all.where((r) => regionCodes.contains(r.code)).toList();
    for (final region in chosen.isEmpty ? all : chosen) {
      final type = region.type.toLowerCase();
      if (type.contains('city') ||
          type.contains('municipality') ||
          type.contains('district') ||
          type.contains('metropolitan')) {
        suggestions.add(region.label.replaceAll('[city]', '').trim());
      }
    }
  }
  final filtered = suggestions
      .where((item) => !metroNames
          .any((selected) => selected.toLowerCase() == item.toLowerCase()))
      .toList()
    ..sort();
  return filtered.take(18).toList();
}
