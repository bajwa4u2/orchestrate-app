import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'support/sibling_backend.dart';

/// THE WORDS THE PLATFORM USES ABOUT ITSELF ARE NOT THE WORDS A CUSTOMER READS.
///
/// Opening the Mailbox and sending screen as a business showed it being called
/// a "tenant", twice, in the banner about its own mailbox — alongside
/// "platform bootstrap transport" and a raw provider code, IMAP_SMTP,
/// underscore included, in the row naming who carries its mail.
///
/// None of it was wrong internally. All of it was written for us.
void main() {
  String backend(String path) => backendSource(path);

  /// Quoted strings only. Comments may keep the internal vocabulary — that is
  /// where it belongs, and a test that forbade it there would push accurate
  /// language out of the code to protect the customer from reading the code.
  Iterable<String> literals(String source) sync* {
    for (final line in const LineSplitter().convert(source)) {
      final code = line.trimLeft();
      if (code.startsWith('//') || code.startsWith('*') || code.startsWith('/*')) {
        continue;
      }
      for (final m in RegExp("'[^']{12,}'").allMatches(line)) {
        yield m.group(0)!;
      }
    }
  }

  const platformWords = [
    'this tenant',
    'platform bootstrap transport',
    'client-owned sending mailbox',
    'client-authorized sending mailbox',
  ];

  final customerFacing = [
    'src/client-portal/client-portal.service.ts',
    'src/runtime-state/runtime-state.ts',
    'src/runtime-state/operational-status.ts',
    'src/deliverability/deliverability.service.ts',
  ];

  for (final path in customerFacing) {
    test('$path speaks to the business, not about it', () {
      final offending = literals(backend(path))
          .where((s) => platformWords.any((w) => s.toLowerCase().contains(w)))
          .toList();
      expect(offending, isEmpty,
          reason: 'these strings reach the customer:\n${offending.join('\n')}');
    }, skip: backendSkipReason);
  }

  test('a provider code is rendered as a name', () {
    final screen = File('lib/features/client/screens/client_mailbox_screen.dart')
        .readAsStringSync();
    expect(screen.contains('String _providerName('), isTrue);
    expect(screen.contains("'IMAP_SMTP': 'SMTP and IMAP'"), isTrue);
    // An unknown code is still shown — knowing it is something beats knowing
    // nothing — but spelled as words.
    expect(screen.contains('split(RegExp('), isTrue);
  });

  /// A REMEMBERED CHOICE IS NOT A PLAN.
  ///
  /// The plan fields fell back to the plan the session remembers someone
  /// looking at in the signed-out funnel. Billing therefore read
  /// "Plan: Focused" beside "Status: None" and "No active subscription
  /// record" — three cards disagreeing about one fact, and the wrong one was
  /// the one a person reads first.
  test('no surface states a plan from a remembered selection', () {
    for (final path in <String>[
      'lib/features/client/screens/client_billing_screen.dart',
      'lib/features/client/screens/client_settings_screen.dart',
    ]) {
      expect(File(path).readAsStringSync().contains('selectedPlanDisplay'),
          isFalse,
          reason: '$path states a subscription from browsing history');
    }
  });

  test('a readiness section is rendered as a place', () {
    final screen =
        File('lib/features/client/screens/client_business_identity_screen.dart')
            .readAsStringSync();
    expect(screen.contains('String _sectionName('), isTrue);
    expect(screen.contains(r"'Section: ${"), isFalse);
    expect(screen.contains('field(s)'), isFalse);
  });
}
