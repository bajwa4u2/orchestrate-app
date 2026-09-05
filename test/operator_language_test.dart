import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/features/operator/screens/operator_workspace_screen.dart';

/// DATABASE VALUES ARE NOT PRODUCT LANGUAGE.
///
/// The inquiry queue rendered "ACKNOWLEDGED · General Inquiry". The status came
/// straight out of the column it lives in, shouted at a person reading a list
/// of people who had written in. Every list in the console carried one.
void main() {
  test('an enum value reads as words', () {
    expect(humaniseEnum('ACKNOWLEDGED'), 'Acknowledged');
    expect(humaniseEnum('IN_PROGRESS'), 'In progress');
    expect(humaniseEnum('RETRYABLE_FAILED'), 'Retryable failed');
    expect(humaniseEnum('CLOSED'), 'Closed');
  });

  test('anything a person wrote passes through untouched', () {
    // The transform must never touch a name, a subject line or a sentence.
    for (final untouched in [
      'Asghar Ali',
      'General Inquiry',
      'Growing Across the Country, One Partner at a Time',
      'info@myfirstinsurance.com',
      '4',
      '',
      'iPhone',
      'eGDG',
    ]) {
      expect(humaniseEnum(untouched), untouched, reason: untouched);
    }
  });

  test('an acronym is already how a person writes it', () {
    expect(humaniseEnum('DNS'), 'DNS');
    expect(humaniseEnum('SPF'), 'SPF');
    // And inside a longer value.
    expect(humaniseEnum('DNS_FAILED'), 'DNS failed');
  });
}
