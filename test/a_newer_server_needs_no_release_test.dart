import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/data/repositories/client/client_market_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_playbook_repository.dart';

/// A NEWER SERVER NEEDS NO RELEASE (4 Oct 2026).
///
/// Before store 2.0 went out, four places would have needed another release
/// the day the server said something new. Each now takes the server's word:
///   1. a decision this app does not know is shown as decided, never as a yes;
///   2. ways of being paid come from the playbook, in its words;
///   3. a kind's question on any step is asked, never dropped;
///   4. any draft waiting for a yes is shown before it is approved.
void main() {
  test('an unknown decision is decided, never a new yes', () {
    final c = Candidate.fromJson({
      'key': 'acme.com',
      'name': 'Acme',
      'whyItMatters': 'They buy what you sell.',
      'disposition': 'WRITING_AUTOMATICALLY',
      'dispositionMeans': 'Writing to them on your standing yes',
    });
    expect(c.disposition, PursuitDisposition.decided);
    expect(c.needsReview, isFalse);
    expect(PursuitDisposition.parse(null), PursuitDisposition.unreviewed);
    expect(PursuitDisposition.parse('PURSUING'), PursuitDisposition.pursuing);
  });

  test('a decided candidate is never sent back to the server', () async {
    final repo = ClientMarketRepository();
    expect(
      () => repo.setPursuit(key: 'acme.com', disposition: PursuitDisposition.decided),
      throwsArgumentError,
    );
  });

  test('payment choices are the playbook\'s, in its words', () {
    final book = PlaybookOption.fromJson({
      'key': 'business_services',
      'label': 'Services',
      'paymentModels': ['retainer'],
      'paymentChoices': [
        {'key': 'retainer', 'label': 'A monthly retainer', 'says': 'Billed monthly.', 'asks': []},
      ],
    });
    expect(book.paymentChoices.single.label, 'A monthly retainer');
    expect(book.paymentChoices.single.asks, isEmpty);

    final older = PlaybookOption.fromJson({
      'key': 'trade_contractor',
      'label': 'Trades',
      'paymentModels': ['progress', 'terms'],
    });
    expect(older.paymentChoices.map((c) => c.label),
        ['Monthly, as the work progresses', 'An invoice when the work is done']);
    expect(older.paymentChoices.first.asks, containsAll(['deposit', 'retainage']));
  });

  test('a question on any step is asked; any draft is shown', () {
    final setup = File('lib/features/client/setup/one_path_setup_screen.dart').readAsStringSync();
    expect(setup, contains("_questionSteps.contains(q.step) ? q.step : 'offer'"));
    expect(setup, isNot(contains('static const _paymentModels')));

    final today = File('lib/features/client/screens/today_screen.dart').readAsStringSync();
    expect(today, contains("(w.draftBody ?? '').trim().isNotEmpty && !w.isInvoice && !w.isAgreement"));
  });
}
