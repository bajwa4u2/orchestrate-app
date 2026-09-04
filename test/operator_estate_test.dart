import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE OPERATOR ESTATE CANNOT GROW BACK.
///
/// It had reached 41 screens and 18,578 lines against a navigation offering
/// twelve destinations — roughly 12,000 lines of adaptation, cognition,
/// reasoning-cache, convergence and green-path surfaces that no menu reached
/// and no operator could find. Meanwhile the things an operator actually had
/// to do, like admitting a company's authority designation, had no surface at
/// all.
///
/// These read the source rather than the widget tree on purpose. The failure
/// mode being prevented is structural — a route added without a way in, or a
/// module name from the implementation leaking into product navigation — and
/// neither shows up in a render test.
void main() {
  final router = File('lib/app/routing/app_router.dart').readAsStringSync();
  final shell = File('lib/app/shell/operator_shell.dart').readAsStringSync();

  Set<String> opsRoutes() => RegExp(r"path:\s*'(/ops/[^']*)'")
      .allMatches(router)
      .map((m) => m.group(1)!)
      .toSet();

  /// Routes that only forward somewhere else. A redirect has no surface, so
  /// nobody can be stranded on it — it exists so an old link keeps resolving.
  Set<String> redirectOnly() {
    final out = <String>{};
    for (final block in router.split('GoRoute(')) {
      final m = RegExp(r"path:\s*'(/ops/[^']*)'").firstMatch(block);
      if (m == null) continue;
      final head = block.substring(0, block.length < 400 ? block.length : 400);
      if (head.contains('redirect:') && !head.contains('builder:')) {
        out.add(m.group(1)!);
      }
    }
    return out;
  }

  Set<String> navPaths() => RegExp(r"_NavItem\(\s*'[^']*',\s*'([^']+)'", multiLine: true, dotAll: true)
      .allMatches(shell)
      .map((m) => m.group(1)!)
      .toSet();

  test('the retired estate is gone, not hidden', () {
    expect(Directory('lib/features/operator_workspace').existsSync(), isFalse,
        reason: 'parking the estate somewhere unnavigable is the failure, not the fix');

    // Vocabulary from the implementation that had become navigation.
    const retired = [
      'adaptation', 'cognition', 'reasoning-cache', 'green-path', 'convergence',
      'healing', 'ai-economy', 'runtime-truth', 'platform-supervision',
      'trust-readiness', 'learning-feed',
    ];
    for (final word in retired) {
      expect(opsRoutes().any((r) => r.contains(word)), isFalse,
          reason: '/ops route still carries the retired term "$word"');
      expect(shell.contains("'/ops/$word"), isFalse,
          reason: 'operator navigation still points at "$word"');
    }
  });

  /// Paths any operator surface links to. A destination reached from a screen
  /// that is itself in the navigation is reachable — the failure being guarded
  /// against is a surface with NO way in, not one that is a click deeper.
  Set<String> linkedPaths() {
    final linked = <String>{};
    for (final dir in [
      Directory('lib/features/operator'),
      Directory('lib/features/ops_console'),
    ]) {
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        for (final m in RegExp(r"'(/ops/[^']*)'").allMatches(f.readAsStringSync())) {
          linked.add(m.group(1)!);
        }
      }
    }
    return linked;
  }

  test('every operator destination is reachable without typing a URL', () {
    // Routes a person is not expected to navigate to directly: sign-in, a
    // detail view entered from a list, and redirects that exist so old links
    // keep resolving.
    const notDestinations = {
      '/ops/login', '/ops/join',   // authentication
      '/ops/inquiries/:id',        // entered from the inquiries list
      '/ops/overview',             // redirect, kept so old links resolve
      '/ops/providers',            // redirect into Transport
    };

    final reachable = {...navPaths(), ...linkedPaths()};
    final surfaces = opsRoutes().difference(redirectOnly());
    final orphans = surfaces
        .where((r) => !notDestinations.contains(r))
        .where((r) => !reachable.contains(r))
        // A sub-route is reachable when its parent is.
        .where((r) => !reachable.any((n) => n != r && r.startsWith('$n/')))
        .toList()
      ..sort();

    expect(orphans, isEmpty,
        reason: 'these operator surfaces exist with no way in: $orphans');
  });

  test('navigation stays small enough to be read', () {
    // Not an arbitrary cap. Twelve destinations was the size the console was
    // usable at; the failure was 29 more routes behind it, not the twelve.
    expect(navPaths().length, lessThanOrEqualTo(16),
        reason: 'operator navigation is growing back into a module list');
  });

  test('the extracted capability survived the retirement', () {
    // Three things in the retired estate were genuinely live. Deleting them
    // with the rest would have taken the audit trail and the status strip.
    expect(File('lib/features/operator/system_status/system_status.dart').existsSync(), isTrue);
    expect(File('lib/features/operator/screens/audit_timeline_screen.dart').existsSync(), isTrue);
    expect(File('lib/features/operator/screens/audit_events.dart').existsSync(), isTrue);
    expect(opsRoutes(), contains('/ops/governance/audit'));
  });

  test('a bookmark to a retired surface lands somewhere, not nowhere', () {
    // Every link to the retired estate that exists in the world is a bookmark
    // or a pasted address, because nothing in the product ever linked to it.
    // Falling through to the not-found page strands a person on a bare screen
    // with no navigation — a deep-link dead end.
    expect(router.contains('_retiredOperatorSurfaces'), isTrue);
    for (final path in const [
      '/ops/adaptation', '/ops/cognition', '/ops/continuity', '/ops/runtime-truth',
      '/ops/trust-readiness', '/ops/platform-supervision',
      '/ops/governance/ai-approvals',
    ]) {
      expect(router.contains("'$path'"), isTrue,
          reason: '$path must still resolve to the work queue for old links');
    }
  });
}
