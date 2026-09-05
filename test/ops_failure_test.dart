import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/features/ops_console/ops_failure.dart';

/// A REFUSAL IS NOT A FAILURE, AND NEITHER IS A CLASS NAME.
///
/// The refused state rendered
///
///     ApiException(statusCode: 403, message: This is work Orchestrate does on
///     behalf of the platform. An operator of a client organisation acts inside
///     that organisation.)
///
/// with a "Try again" button underneath it. The backend had written a good
/// sentence; the console wrapped it in a Dart type name and an HTTP code, and
/// then offered to repeat a question that had already been answered. Found by
/// rendering the state and looking at it.
void main() {
  ApiException refusal(String message) =>
      ApiException(403, message, '{"statusCode":403}');

  test('a refusal shows the reason somebody wrote, and nothing else', () {
    const written = 'This is work Orchestrate does on behalf of the platform.';
    final text = OpsFailure.readable(refusal(written));

    expect(text, written);
    expect(text.contains('ApiException'), isFalse);
    expect(text.contains('403'), isFalse);
    expect(text.contains('statusCode'), isFalse);
  });

  test('a refusal is distinguished from an outage', () {
    expect(OpsFailure.isRefusal(refusal('no')), isTrue);
    expect(OpsFailure.isRefusal(ApiException(401, 'no', '')), isTrue);
    // Retrying these is reasonable; retrying a refusal is not.
    expect(OpsFailure.isRefusal(ApiException(500, 'boom', '')), isFalse);
    expect(OpsFailure.isRefusal(Exception('socket')), isFalse);
  });

  test('a transport failure never shows its own stringification', () {
    // "ClientFailed to fetch, uri=http://localhost:4310/v1/operator/platform/
    // clients" — a type name run into a message, then an internal URL. It
    // rendered exactly like that.
    for (final error in [
      Exception('ClientException with SocketException: Failed host lookup'),
      Exception('Failed to fetch, uri=http://api.internal/v1/operator/clients'),
      StateError('Instance of ClientException'),
    ]) {
      final text = OpsFailure.readable(error);
      expect(text.contains('uri='), isFalse, reason: text);
      expect(text.contains('http'), isFalse, reason: text);
      expect(text.contains('Exception'), isFalse, reason: text);
      expect(text.length > 20, isTrue, reason: 'still has to say something');
    }
  });

  test('an empty server message does not leave a blank', () {
    expect(OpsFailure.readable(ApiException(500, '', '')).isNotEmpty, isTrue);
    expect(OpsFailure.readable(ApiException(500, 'Request failed', '')),
        isNot('Request failed'));
  });
}
