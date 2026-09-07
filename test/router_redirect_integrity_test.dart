// A redirect that comes back to where it started is not a redirect.
//
// /client/representation/targeting pointed at /app/campaigns, and
// /app/campaigns pointed back at /client/representation/targeting. Every
// arrival bounced between the two, and the workspace reported that no surface
// was available — which was true, and said nothing about why.
//
// The pair was written when /app/campaigns still rendered the targeting editor.
// Retiring the /app screens turned both halves into redirects with nothing
// underneath either, and neither half is wrong on its own. Only the cycle is,
// and nothing in a screen test can see it.
//
// This reads the router source rather than building the app: the property is
// about the routing table as a whole, and the failure is silent everywhere else.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no redirect returns to where it started', () {
    final source = File('lib/app/routing/app_router.dart').readAsStringSync();

    final pattern = RegExp(
      r"path:\s*'([^']+)'\s*,\s*\n?\s*redirect:\s*\(context, state\)\s*=>\s*'([^']+)'",
      multiLine: true,
    );

    final redirects = <String, String>{
      for (final m in pattern.allMatches(source)) m.group(1)!: m.group(2)!,
    };

    expect(redirects, isNotEmpty,
        reason: 'the redirect table could not be read; rewrite this test with it');

    final cycles = <String>[];
    redirects.forEach((from, to) {
      final hops = <String>[from];
      var current = to;
      for (var i = 0; i < 12; i++) {
        hops.add(current);
        if (current == from) {
          cycles.add(hops.join(' -> '));
          return;
        }
        final next = redirects[current];
        if (next == null) return;
        current = next;
      }
    });

    expect(cycles, isEmpty,
        reason: 'these redirects lead back to themselves, so the destination '
            'never renders:\n  ${cycles.join('\n  ')}');
  });

  test('no redirect points at a path that is not itself routed', () {
    final source = File('lib/app/routing/app_router.dart').readAsStringSync();
    final declared = RegExp(r"path:\s*'([^']+)'")
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toSet();

    // Retired operator surfaces are resolved by a set rather than declared as
    // routes, deliberately: a bookmark to one still lands on the work queue
    // instead of a dead end. They are routed, just not by a GoRoute, and
    // reporting them here would be this test not knowing how the router works.
    final retiredBlock =
        RegExp(r'_retiredOperatorSurfaces = <String>\{(.*?)\};', dotAll: true)
            .firstMatch(source)
            ?.group(1) ??
            '';
    final retired = RegExp(r"'([^']+)'")
        .allMatches(retiredBlock)
        .map((m) => m.group(1)!)
        .toSet();

    final targets = RegExp(
      r"redirect:\s*\(context, state\)\s*=>\s*'([^'?]+)",
      multiLine: true,
    )
        .allMatches(source)
        .map((m) => m.group(1)!)
        // Interpolated destinations are built at navigation time and cannot be
        // compared against a literal table.
        .where((t) => !t.contains(r'$'))
        .toSet();

    // A declared path may carry parameters, so /journey/:journeyKey answers
    // /journey/evaluate_and_activate. Compared segment by segment, with a
    // ":" segment matching anything.
    bool declaredMatches(String target) {
      final t = target.split('/');
      return declared.any((d) {
        final p = d.split('/');
        if (p.length != t.length) return false;
        for (var i = 0; i < p.length; i++) {
          if (p[i].startsWith(':')) continue;
          if (p[i] != t[i]) return false;
        }
        return true;
      });
    }

    // The router resolves a retired surface AND anything beneath it, so the
    // prefix rule has to be the same one the router uses.
    bool isRetired(String target) =>
        retired.any((p) => target == p || target.startsWith('$p/'));

    final missing = targets
        .where((t) => !declaredMatches(t) && !isRetired(t))
        .toList()
      ..sort();

    expect(missing, isEmpty,
        reason: 'these redirect destinations are not declared as routes, so a '
            'person following them arrives nowhere:\n  ${missing.join('\n  ')}');
  });
}
