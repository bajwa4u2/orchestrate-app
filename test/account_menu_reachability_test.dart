import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE ONLY DOOR TO HALF THE ACCOUNT MUST BE HITTABLE.
///
/// The account row at the foot of the rail carries People & authority, Plan &
/// billing, Account & security, feedback, the version, and Sign out. Nothing
/// else in the product reaches most of them.
///
/// Its tap target was the avatar: a 30px circle at the left of a row that
/// reads as one control the full width of the rail. Clicking the business name
/// or the email — the obvious place — did nothing at all. Found by clicking
/// where a person clicks rather than where the widget tree says to.
void main() {
  final shell = File('lib/app/shell/client_shell.dart').readAsStringSync();

  test('the identity is inside the button, not beside it', () {
    expect(shell.contains('this.showIdentity = false,'), isTrue);
    expect(shell.contains('if (widget.showIdentity)'), isTrue);
    // The expanded rail must not build a Row that puts the button and the
    // identity side by side again — that is exactly what made the text inert.
    final rail = shell.substring(
      shell.indexOf('child: collapsed'),
      shell.indexOf('class _RailItem'),
    );
    expect(
      rail.contains('showIdentity: true'),
      isTrue,
      reason: 'the name and email must be built inside the button',
    );
    expect(
      rail.contains('session.workspaceName'),
      isFalse,
      reason: 'the shell must not read the name once and hand it over — it '
          'does not rebuild when a profile is saved',
    );
  });

  test('the row follows the session', () {
    final button = shell.substring(shell.indexOf('class _AccountButtonState'));
    expect(button.contains('ListenableBuilder('), isTrue);
    expect(button.contains('listenable: session,'), isTrue);
  });

  test('the row has height to hit', () {
    final button = shell.substring(shell.indexOf('class _AccountButtonState'));
    expect(button.contains('EdgeInsets.symmetric(vertical: 6)'), isTrue);
  });

  test('every account destination is only reachable here', () {
    // If one of these ever gains another entry point this test is not wrong,
    // but the menu breaking would stop being invisible — which is the point.
    for (final destination in <String>[
      '/account/people',
      '/account/plan',
      '/account/security',
    ]) {
      expect(shell.contains("value: '$destination'"), isTrue);
    }
    expect(shell.contains("value: 'signout'"), isTrue);
    expect(shell.contains("value: 'feedback'"), isTrue);
  });
}
