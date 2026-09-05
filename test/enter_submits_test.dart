import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ENTER SUBMITS.
///
/// Nothing in either sign-in form handled it: a person typed their password,
/// pressed Enter, and the page sat there — no request, no error, nothing to
/// explain it. Found because the certification harness pressed Enter and no
/// auth call left the browser, which for a moment looked like the login was
/// broken. It was, just not in the way it appeared.
void main() {
  final client =
      File('lib/features/auth/screens/client_login_screen.dart').readAsStringSync();
  final ops =
      File('lib/features/auth/screens/ops_login_screen.dart').readAsStringSync();

  test('the shared field can be finished with', () {
    expect(client.contains('final VoidCallback? onSubmitted;'), isTrue);
    expect(client.contains('onFieldSubmitted: onSubmitted == null'), isTrue);
    // A field that is not the last one moves to the next rather than claiming
    // to finish the form.
    expect(
      client.contains(
          'onSubmitted != null ? TextInputAction.done : TextInputAction.next'),
      isTrue,
    );
  });

  test('every terminal field on the client screen submits its own form', () {
    for (final action in <String>[
      'onSubmitted: state._busy ? null : state.login',
      'onSubmitted: state._busy ? null : state.register',
      'onSubmitted: state._busy ? null : state.verifyLoginCode',
      'onSubmitted: state._busy ? null : state.submitReset',
    ]) {
      expect(client.contains(action), isTrue, reason: 'missing: $action');
    }
  });

  test('the operator screen submits too', () {
    expect(ops.contains('onFieldSubmitted:'), isTrue);
    expect(ops.contains('(_) => _verifyCode()'), isTrue);
    expect(ops.contains('(_) => createMode ? _bootstrap() : _login()'), isTrue);
  });

  test('a busy form does not submit twice', () {
    // Enter while a request is in flight must be as inert as the button is.
    //
    // Matched with whitespace collapsed. The original assertion embedded a
    // literal newline and an exact indentation, which made it a test about how
    // the file happened to be wrapped and how git checked out its line
    // endings. It passed on the machine that wrote it and failed on CI, where
    // the file arrives with CRLF — and because `flutter test` gates the iOS
    // build, that is a failed release build over a line ending.
    String flat(String source) => source.replaceAll(RegExp(r'\s+'), ' ');
    expect(flat(client).contains('state._busy ? null : state.login'), isTrue);
    expect(flat(ops).contains('_busy ? null'), isTrue);
  });
}
