import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// DD-26: COLOUR HAS ONE MEANING EACH.
///
/// Green says money; amber says "waiting for your yes". The day either is
/// used to decorate a heading or mark something "healthy", the owner stops
/// reading it, and the two facts that matter most stop being glanceable. So
/// the places allowed to reach for them are listed here, and a new one has to
/// be added on purpose, with a reason, rather than drift in.
void main() {
  Set<String> usersOf(RegExp pattern) => {
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File &&
              f.path.endsWith('.dart') &&
              pattern.hasMatch(f.readAsStringSync()))
            f.path.replaceAll(r'\', '/'),
      };

  test('green is reached for only where money is shown', () {
    final users = usersOf(
        RegExp(r'Ob\.(money|moneyBright|moneySoft|moneyInk|moneyOnInk)\b|PillTone\.money'));
    const allowed = {
      'lib/core/ui/ob_widgets.dart', // MoneyText, the money pill
      'lib/features/client/money/money_screen.dart', // Money
      'lib/features/client/screens/today_screen.dart', // "This month"
      'lib/features/client/setup/one_path_setup_screen.dart', // plan prices
      'lib/features/public/b/public_b.dart', // paid, prices
    };
    expect(users.difference(allowed), isEmpty,
        reason: 'green is money; a new use must be money and be listed here');
  });

  test('amber is reached for only where something waits for a yes', () {
    final users = usersOf(RegExp(
        r'Ob\.(yes|yesDeep|yesSoft|yesInk)\b|PillTone\.yes|waitingOnYes: true'));
    const allowed = {
      'lib/core/ui/ob_widgets.dart', // path bar, yes count, pills
      'lib/core/layout/workspace.dart', // a row that needs the owner
      'lib/core/theme/app_theme.dart', // the attention tint, same meaning
      'lib/core/theme/workspace_theme.dart', // caution: a decision owed
      'lib/features/client/money/money_screen.dart', // proposals, invoices ready
      'lib/features/client/screens/today_screen.dart', // the yes-cards
      'lib/features/client/setup/one_path_setup_screen.dart', // permission
      'lib/features/public/b/public_b.dart', // examples of a yes
    };
    expect(users.difference(allowed), isEmpty,
        reason: 'amber is the owner\'s yes; a new use must mean that');
  });
}
