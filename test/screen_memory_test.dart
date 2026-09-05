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

  test('every screen that blinked now recalls', () {
    const screens = <String, String>{
      'client_evidence_screen': 'evidence',
      'client_trust_screen': 'credentials',
      'client_artifacts_screen': 'artifacts',
      'client_branding_screen': 'branding',
      'client_billing_screen': 'billing',
      'client_account_screen': 'account',
      'client_settings_screen': 'settings',
      'client_business_identity_screen': 'representation',
      'client_mailbox_screen': 'mailbox',
    };
    screens.forEach((file, key) {
      final s = source('lib/features/client/screens/$file.dart');
      expect(s.contains("'$key'"), isTrue, reason: '$file must recall');
      expect(s.contains('ScreenMemory'), isTrue, reason: '$file must recall');
    });
  });

  test('a FutureBuilder screen paints data rather than waiting on a state', () {
    // With initialData supplied the connection state is still `waiting`, so a
    // `connectionState != done` check would go on showing the loading view
    // over data that is already there.
    for (final file in <String>[
      'client_billing_screen',
      'client_account_screen',
      'client_settings_screen',
      'client_business_identity_screen',
      'client_mailbox_screen',
    ]) {
      final s = source('lib/features/client/screens/$file.dart');
      expect(s.contains('initialData: ScreenMemory.recall'), isTrue,
          reason: '$file must seed from memory');
      expect(s.contains('!snapshot.hasData && !snapshot.hasError'), isTrue,
          reason: '$file must ask whether there is anything to paint');
      expect(s.contains('connectionState != ConnectionState.done'), isFalse,
          reason: '$file must not wait on the connection state');
    }
  });
}
