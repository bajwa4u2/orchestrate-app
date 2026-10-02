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

  /// A REMEMBERED CHOICE IS NOT A PLAN.
  ///
  /// The plan fields fell back to the plan the session remembers someone
  /// looking at in the signed-out funnel. Billing therefore read
  /// "Plan: Focused" beside "Status: None" and "No active subscription
  /// record" — three cards disagreeing about one fact, and the wrong one was
  /// the one a person reads first.
  test('no surface states a plan from a remembered selection', () {
    for (final path in <String>[
      // Billing and Workspace settings retired into these two (DD-34).
      'lib/features/client/screens/account_layer_screen.dart',
      'lib/features/client/setup/one_path_setup_screen.dart',
    ]) {
      expect(File(path).readAsStringSync().contains('selectedPlanDisplay'),
          isFalse,
          reason: '$path states a subscription from browsing history');
    }
  });
}
