import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A DESTINATION MUST BE THE PLACE IT SAYS IT IS.
///
/// Opening every client route found two navigation entry points promising
/// views the product does not have, and three promising sections by URL
/// fragment — which nothing in the app reads.
///
/// A person who searches the palette for "Pipeline", lands on the ordinary
/// relationships list and finds no board concludes the product is broken. The
/// truth is milder and worse: the view was never built, and two places kept
/// advertising it.
void main() {
  final palette =
      File('lib/features/client/widgets/command_palette.dart').readAsStringSync();
  final router = File('lib/app/routing/app_router.dart').readAsStringSync();
  final workspace =
      File('lib/features/client/screens/relationships_workspace_screen.dart')
          .readAsStringSync();

  test('nothing advertises a view that does not exist', () {
    expect(palette.contains('view=pipeline'), isFalse);
    expect(palette.contains('view=waiting'), isFalse);
    expect(router.contains('view=pipeline'), isFalse);
    // And the parameter that carried it is gone rather than left dangling:
    // it was declared, passed by the router, and read by nobody.
    expect(workspace.contains('initialView'), isFalse);
    expect(router.contains('initialView'), isFalse);
  });

  test('the palette names routes, not fragments', () {
    final commands = RegExp(r"_Command\('([^']+)', '([^']+)'")
        .allMatches(palette)
        .map((m) => (label: m.group(1)!, path: m.group(2)!))
        .toList();
    expect(commands, isNotEmpty);
    for (final c in commands) {
      expect(c.path.contains('#'), isFalse,
          reason: '"${c.label}" points at a fragment, which nothing reads');
    }
  });

  /// A DIAGNOSTIC IS NOT A DESTINATION.
  ///
  /// The Business hub offered "Credentials — certifications, licences,
  /// insurance" and the route answered with "Client-safe AI activity and trust
  /// summary": a generic screen that listed the endpoints it had called and
  /// printed whatever came back, including a record whose only visible field
  /// read "campaign: null".
  test('no customer route renders the backend-surface screen', () {
    expect(
      router.contains('ClientBackendSurfaceScreen('),
      isFalse,
      reason: 'that screen shows endpoint names and raw records to customers',
    );
  });

  /// RETIRED MEANS RETIRED (DD-34, founder, 2 Oct 2026).
  ///
  /// Search kept offering Business settings, Targeting, Credentials and
  /// Evidence after Setup and Account replaced them, and those pages still
  /// rendered. Every retired address now redirects to its new home, so an old
  /// email, bookmark or installed app still arrives somewhere real, and none
  /// of them can open a retired page again.
  const retired = {
    '/client/business': '/client/setup',
    '/client/representation': '/client/setup?step=business',
    '/client/infrastructure': '/client/setup?step=email',
    '/client/billing': '/account/plan',
    '/client/subscribe': '/account/plan',
    '/client/records': '/account/record',
    '/client/settings': '/account/security',
    '/client/account': '/account/security',
    '/app/account': '/account/security',
    '/app/trust': '/client/setup?step=offer',
    '/app/evidence': '/client/setup?step=offer',
    '/app/branding': '/client/setup?step=business',
    '/app/artifacts': '/client/money',
    '/client/contacts/inventory': '/client/relationships',
    '/client/sequences/:sequenceId': '/client/relationships',
  };

  test('every retired address redirects to its new home', () {
    for (final entry in retired.entries) {
      expect(
        // Line endings and indentation are not the point; the pairing is.
        router.replaceAll(RegExp(r'\s+'), ' ').contains(
            "path: '${entry.key}', redirect: (context, state) => _retired(state, '${entry.value}'))"),
        isTrue,
        reason: '${entry.key} must redirect to ${entry.value}',
      );
    }
  });

  test('no retired page is mounted anywhere', () {
    const screens = [
      'BusinessScreen(', 'ClientBusinessIdentityScreen(', 'ClientMailboxScreen(',
      'ClientTrustScreen(', 'ClientEvidenceScreen(', 'ClientArtifactsScreen(',
      'ClientBrandingScreen(', 'ClientBillingScreen(', 'ClientSubscribeScreen(',
      'ClientSettingsScreen(', 'ClientAccountScreen(', 'ClientSequenceAuthorScreen(',
      'ClientRelationshipsScreen(',
    ];
    for (final s in screens) {
      expect(RegExp(r'(^|[^A-Za-z])' + RegExp.escape(s)).hasMatch(router), isFalse,
          reason: '$s is retired and must not be mounted');
    }
  });

  test('nothing in the app links to a retired address', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('app_router.dart')) continue;
      final src = f.readAsStringSync();
      for (final path in retired.keys) {
        final p = RegExp.escape(path.split('/:').first);
        final link = RegExp("go\\('$p(['?/])");
        final command = RegExp("_Command\\((?:'[^']*'|\"[^\"]*\"), '$p['?]");
        if (link.hasMatch(src) || command.hasMatch(src)) {
          offenders.add('${f.path}: $path');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('every palette destination is a page the app shows today', () {
    final commands = RegExp("_Command\\((?:'[^']*'|\"[^\"]*\"), '([^']+)'")
        .allMatches(palette)
        .map((m) => m.group(1)!.split('?').first)
        .toSet();
    expect(commands.length, greaterThan(5));
    for (final path in commands) {
      expect(router.contains("path: '$path'"), isTrue,
          reason: '$path is offered but not routed');
      expect(retired.containsKey(path), isFalse,
          reason: '$path is retired and must not be offered');
    }
  });
}
