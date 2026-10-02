import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/sibling_backend.dart';

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
  /// rendered. The first answer was to redirect every old address. With no
  /// client yet depending on one, the founder retired them outright: a fresh
  /// client meets only today's places, and an old address is not found.
  const retired = {
    '/client/overview', '/client/workspace', '/client/business',
    '/client/representation', '/client/infrastructure', '/client/mailbox',
    '/client/billing', '/client/subscribe', '/client/records',
    '/client/settings', '/client/account', '/client/contacts',
    '/client/contacts/inventory', '/client/sequences/:sequenceId',
    '/client/leads', '/client/campaigns', '/client/operations',
    '/client/outreach', '/client/replies', '/client/meetings',
    '/client/opportunities', '/client/notifications', '/client/help',
    '/client/trust', '/client/activity', '/client/invoices',
    '/client/receipts', '/client/agreements', '/client/statements',
    '/client/reminders', '/client/authorised-people',
    '/client/business-identity',
  };

  test('no retired address is routed, and nothing under /app is', () {
    for (final path in retired) {
      expect(router.contains("path: '$path'"), isFalse, reason: '$path is retired');
    }
    expect(router.contains("path: '/app/"), isFalse, reason: 'the /app area is retired');
    expect(router.contains('_retired('), isFalse, reason: 'retired means gone, not redirected');
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
      for (final path in retired) {
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
      expect(retired.contains(path), isFalse,
          reason: '$path is retired and must not be offered');
    }
  });

  /// SUPPORT SENDS PEOPLE ONLY TO PAGES THAT EXIST (DD-35).
  ///
  /// Support's answers name places from one backend table. Each must be a
  /// page this app shows today, never a retired one.
  test('every place Support can send a client is a page the app shows', () {
    final places = backendSource('src/support/client-places.ts');
    final routes = RegExp(r"route: '([^']+)'")
        .allMatches(places)
        .map((m) => m.group(1)!.split('?').first)
        .toSet();
    expect(routes.length, greaterThan(8));
    for (final path in routes) {
      expect(router.contains("path: '$path'"), isTrue, reason: '$path is named by Support but not routed');
      expect(retired.contains(path), isFalse, reason: '$path is retired');
    }
  }, skip: backendSkipReason);

  /// THE VISITOR ASSISTANT SENDS VISITORS ONLY TO PUBLIC PAGES (2 Oct 2026).
  test('every place the visitor assistant names is a public page', () {
    final places = backendSource('src/support/visitor-knowledge.ts');
    final routes = RegExp(r"route: '([^']+)'")
        .allMatches(places)
        .map((m) => m.group(1)!.split('?').first)
        .toSet();
    expect(routes.length, greaterThan(4));
    for (final path in routes) {
      expect(router.contains("path: '$path'"), isTrue, reason: '$path is named for visitors but not routed');
      expect(path.startsWith('/client') || path.startsWith('/account'), isFalse,
          reason: '$path needs an account');
    }
  }, skip: backendSkipReason);

  /// The server names where a blocker is resolved. Each must be a page the
  /// app shows today, or the button that should help lands on nothing.
  test('every route the server sends a client to is a page the app shows', () {
    const sources = [
      'src/operational-readiness/execution-eligibility.service.ts',
      'src/client-portal/workflow-state.service.ts',
      'src/client-portal/client-experience.service.ts',
      'src/clients/clients.service.ts',
      'src/guidance/readiness-explanation.engine.ts',
      'src/guidance/operational-state.explainer.ts',
      'src/guidance/guidance-rules.provider.ts',
    ];
    final named = RegExp(r"'(/(?:client|account)[A-Za-z/_-]*)[?']");
    for (final source in sources) {
      for (final m in named.allMatches(backendSource(source))) {
        final path = m.group(1)!;
        expect(router.contains("path: '$path'") || path == '/client', isTrue,
            reason: '$source sends clients to $path, which is not routed');
      }
    }
  }, skip: backendSkipReason);

}
