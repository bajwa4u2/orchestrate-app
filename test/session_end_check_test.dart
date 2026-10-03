import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A 401 IS NOT PROOF THE SESSION ENDED (founder walk, 3 Oct 2026).
///
/// Reloading a page signed a person out of a valid session: one refused
/// request deleted the saved session, though the server also says 401 for
/// "this endpoint is not for you", and a request sent before the session was
/// read carries no token. Only a session the server itself refuses ends.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthSessionController.instance.clear();
    await AuthSessionController.instance.init();
    await AuthSessionController.instance.applyAuthResponse({
      'token': 'live-token',
      'session': {'surface': 'client', 'clientId': 'c1', 'organizationId': 'o1'},
      'user': {'email': 'owner@example.test', 'emailVerified': true},
      'setup': {'completed': true},
    });
  });

  tearDown(() => SessionEndCheck.instance.probe = null);

  ApiClient refusing() => ApiClient(
        httpClient: MockClient((_) async => http.Response('{"message":"Operator access is not allowed"}', 401)),
      );

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('a refusal on one endpoint keeps a session the server still knows', () async {
    var asked = 0;
    SessionEndCheck.instance.probe = (token, _) async {
      asked++;
      expect(token, 'live-token');
      return 200;
    };
    await expectLater(refusing().getJson('/operator/overview'), throwsA(isA<ApiException>()));
    await settle();
    expect(asked, 1, reason: 'the session is asked about once');
    expect(AuthSessionController.instance.token, 'live-token');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('orch_client_session_v1'), isNotNull, reason: 'still saved for the next reload');
  });

  test('a session the server refuses is ended', () async {
    SessionEndCheck.instance.probe = (_, __) async => 401;
    await expectLater(refusing().getJson('/client/today'), throwsA(isA<ApiException>()));
    await settle();
    expect(AuthSessionController.instance.token, isEmpty);
  });

  test('no answer is not a refusal', () async {
    SessionEndCheck.instance.probe = (_, __) async => throw Exception('offline');
    await expectLater(refusing().getJson('/client/today'), throwsA(isA<ApiException>()));
    await settle();
    expect(AuthSessionController.instance.token, 'live-token');
  });

  test('a request sent without a token never ends a session', () async {
    var asked = 0;
    SessionEndCheck.instance.probe = (_, __) async {
      asked++;
      return 401;
    };
    // As if the request left before the saved session was read.
    SessionEndCheck.instance.afterRefusal('', http.Client());
    await settle();
    expect(asked, 0);
    expect(AuthSessionController.instance.token, 'live-token');
  });

  test('a refusal for an older token does not end the new session', () async {
    SessionEndCheck.instance.probe = (_, __) async => 401;
    SessionEndCheck.instance.afterRefusal('old-token', http.Client());
    await settle();
    expect(AuthSessionController.instance.token, 'live-token');
  });
}
