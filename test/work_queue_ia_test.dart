import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A QUEUE HAS TO SURVIVE ITS OWN SUCCESS.
///
/// At twenty-seven cases the old one rendered every case's full diagnosis,
/// evidence table and six-button action grid inline, and showed twenty-five of
/// thirty-nine held messages under a heading reading "27 cases". Both problems
/// get worse in the same direction, and neither is a styling question.
void main() {
  final screen =
      File('lib/features/ops_console/ops_work_queue_screen.dart').readAsStringSync();
  final repository =
      File('lib/features/ops_console/ops_console_repository.dart').readAsStringSync();

  test('the list row is a line, not a case', () {
    final row = screen.substring(
      screen.indexOf('class _QueueRow'),
      screen.indexOf('class _Pager'),
    );

    // What belongs on a row: whose it is, what it is, how long, one way in.
    expect(row.contains('Review'), isTrue);

    // What does not. Each of these is a decision surface, and a list of thirty
    // of them is not a list.
    for (final inline in [
      '_EvidenceTable',
      '_ActionSet',
      '_ActionButton',
      '_VerificationSourceRow',
      '_HistoryList',
      "c['diagnosis']",
    ]) {
      expect(
        row.contains(inline),
        isFalse,
        reason: '$inline belongs in the case, not in every row of the list',
      );
    }
  });

  test('reviewing opens the case', () {
    expect(screen.contains('class _CaseDetail'), isTrue);
    // The detail is reached by state, and there is always a way back out of it.
    expect(screen.contains('Back to the queue'), isTrue);
    // And it carries what a decision needs.
    for (final section in [
      'Why this exists',
      'Evidence',
      'Actions',
      'How you will know',
      'What has been done',
    ]) {
      expect(screen.contains(section), isTrue, reason: '$section must be in the case');
    }
  });

  test('the count describes the work, and paging is real', () {
    // Never `_cases.length` as the total: that is the size of the page.
    expect(screen.contains("data['total']"), isTrue);
    expect(screen.contains("data['totalUnfiltered']"), isTrue);
    expect(screen.contains('hasMore'), isTrue);
    expect(screen.contains('offset'), isTrue);
    expect(repository.contains("query['offset']"), isTrue);

    // A count that is a floor must say so.
    expect(screen.contains('atCeiling'), isTrue);
    expect(
      screen.contains('The counts above are'),
      isTrue,
      reason: 'silence about truncation is what made "27 cases" possible',
    );
  });

  test('both questions are one choice', () {
    // "Everything owed to this business" and "every decision of this kind".
    expect(repository.contains("query['clientId']"), isTrue);
    expect(repository.contains("query['workType']"), isTrue);
    // The businesses are a menu, not a permanent tab each: twenty clients would
    // be twenty tabs, and a hundred would be unusable.
    expect(screen.contains('PopupMenuButton<String>'), isTrue);
  });

  test('raw identifiers are details, not the headline', () {
    final detail = screen.substring(screen.indexOf('class _CaseDetail'));
    // The case leads with what it is about; the case type and row id live under
    // Details, which is where an engineer looks and a person does not.
    expect(detail.contains('class _Fingerprint'), isTrue);
    final headline = detail.substring(0, detail.indexOf('Why this exists'));
    for (final raw in ["c['caseType']", "c['entityId']", "c['entityType']"]) {
      expect(
        headline.contains(raw),
        isFalse,
        reason: '$raw is how we find this again, not what it is about',
      );
    }
  });
}
