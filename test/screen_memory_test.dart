import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/core/ui/screen_memory.dart';

/// THE BLINK BETWEEN EVERY SCREEN.
///
/// Reported from the live product: the screens under Account and under
/// Business blink on every visit. They did, and it was the same cause on all
/// of them — the screen fetches in `initState` with nothing to show, and
/// `State` is destroyed the moment a person navigates away, so every return
/// started from nothing and painted a spinner over the whole content area.
///
/// The three destinations in the rail already avoided it by holding their
/// answers outside the screen. These screens now recall the last answer they
/// were given, paint it immediately, and refresh underneath.
void main() {
  String source(String path) => File(path).readAsStringSync();

  tearDown(ScreenMemory.forget);

  test('an answer is recalled, and typed', () {
    ScreenMemory.remember('evidence', <String>['a', 'b']);
    expect(ScreenMemory.recall<List<String>>('evidence'), <String>['a', 'b']);
    // A key that was never written, and a key written with another type, both
    // come back as nothing rather than as a wrong answer.
    expect(ScreenMemory.recall<List<String>>('nothing'), isNull);
    expect(ScreenMemory.recall<Map<String, String>>('evidence'), isNull);
  });

  test('forgetting leaves nothing behind', () {
    ScreenMemory.remember('billing', 1);
    expect(ScreenMemory.remembered, 1);
    ScreenMemory.forget();
    expect(ScreenMemory.remembered, 0);
    expect(ScreenMemory.recall<int>('billing'), isNull);
  });

  test('signing out forgets', () {
    final shell = source('lib/app/shell/client_shell.dart');
    final signOut = shell.substring(
      shell.indexOf('Future<void> _signOut('),
      shell.indexOf('Widget build(BuildContext context)'),
    );
    expect(signOut.contains('ScreenMemory.forget()'), isTrue);
  });

  // The screens these two tests named (Evidence, Credentials, Artifacts,
  // Branding, Billing, Your account, Business identity, Mailbox) are retired
  // (DD-34); their work moved into Setup and Account.


}
