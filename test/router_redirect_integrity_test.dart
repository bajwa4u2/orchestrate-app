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

  // A LINK THE PRODUCT OFFERS AND CANNOT HONOUR.
  //
  // The two tests above check the routing table against itself. They cannot
  // see the other half of the same failure: a screen that navigates somewhere
  // no route answers. Business is a hub of eight links, the workspace rail
  // carries four more, and every one of them is a literal path written in a
  // screen rather than in the router.
  //
  // That is where the founder met this. A dead link does not throw and does
  // not log — it renders "no surface available", which is a true statement
  // about the result and says nothing about the cause, and it looks
  // identical to a feature that was never built.
  test('every path a screen navigates to is answered by a route', () {
    final source = File('lib/app/routing/app_router.dart').readAsStringSync();
    final declared = RegExp(r"path:\s*'([^']+)'")
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toSet();

    final retiredBlock =
        RegExp(r'_retiredOperatorSurfaces = <String>\{(.*?)\};', dotAll: true)
            .firstMatch(source)
            ?.group(1) ??
            '';
    final retired = RegExp(r"'([^']+)'")
        .allMatches(retiredBlock)
        .map((m) => m.group(1)!)
        .toSet();

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

    bool isRetired(String target) =>
        retired.any((p) => target == p || target.startsWith('$p/'));

    // Every literal absolute path a screen hands to navigation. Interpolated
    // ones are built at navigation time from values only the running app has,
    // so a literal table cannot judge them and guessing would produce noise
    // that gets this test switched off.
    final navigation = RegExp(
      r"(?:context\.go|context\.push|\.go|\.push|withReturnTo)\(\s*'(/[^'?$]+)'",
    );
    final hubEntry = RegExp(r"path:\s*'(/[^'?$]+)'");

    final offenders = <String, Set<String>>{};
    var examined = 0;

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // The router declares paths; it does not navigate to them.
      if (entity.path.replaceAll(r'\', '/').endsWith('app/routing/app_router.dart')) {
        continue;
      }
      final text = entity.readAsStringSync();

      final targets = <String>{
        for (final m in navigation.allMatches(text)) m.group(1)!,
        for (final m in hubEntry.allMatches(text)) m.group(1)!,
      };

      examined += targets.length;
      for (final target in targets) {
        if (declaredMatches(target) || isRetired(target)) continue;
        offenders.putIfAbsent(target, () => <String>{}).add(entity.path);
      }
    }

    // A sweep that finds nothing to check passes for the wrong reason. If the
    // navigation idiom changes and these patterns stop matching, this test
    // would go quietly green while covering nothing at all.
    expect(examined, greaterThan(20),
        reason: 'almost no navigation targets were found, so this test is not '
            'looking at anything; the patterns need rewriting against how the '
            'app actually navigates now');

    final report = offenders.entries
        .map((e) => '${e.key}  <- ${e.value.join(', ')}')
        .toList()
      ..sort();

    expect(report, isEmpty,
        reason: 'these screens navigate to paths no route answers, so the '
            'person arrives at "no surface available":\n  ${report.join('\n  ')}');
  });
}
