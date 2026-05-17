import '../../core/auth/auth_session.dart';
import '../../core/network/api_client.dart';

class AuthRepository {
  AuthRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> registerClient({
    required String fullName,
    required String email,
    required String password,
    required String companyName,
    String? websiteUrl,
  }) async {
    final json = await _apiClient.postJson('/auth/client/register', body: {
      'fullName': fullName,
      'email': email,
      'password': password,
      'companyName': companyName,
      if (websiteUrl != null && websiteUrl.trim().isNotEmpty)
        'websiteUrl': websiteUrl.trim(),
    });
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> loginClient({
    required String email,
    required String password,
  }) async {
    final trustedDeviceToken =
        await AuthSessionController.instance.trustedDeviceToken(
      surface: 'client',
    );
    final json = await _apiClient.postJson('/auth/client/login', body: {
      'email': email,
      'password': password,
      if (trustedDeviceToken.isNotEmpty)
        'trustedDeviceToken': trustedDeviceToken,
      'deviceName': 'Current device',
    });
    final payload = Map<String, dynamic>.from(json as Map);
    if (payload['requiresEmailCodeChallenge'] != true) {
      await AuthSessionController.instance.applyAuthResponse(payload);
    }
    return payload;
  }

  Future<Map<String, dynamic>> verifyClientLoginCode({
    required String challengeId,
    required String code,
    required bool trustDevice,
  }) async {
    final json =
        await _apiClient.postJson('/auth/client/login/verify-code', body: {
      'challengeId': challengeId,
      'code': code,
      'trustDevice': trustDevice,
      'deviceName': 'Current device',
    });
    final payload = Map<String, dynamic>.from(json as Map);
    final trustedDeviceToken = payload['trustedDeviceToken']?.toString() ?? '';
    if (trustedDeviceToken.isNotEmpty) {
      await AuthSessionController.instance.saveTrustedDeviceToken(
        trustedDeviceToken,
        surface: 'client',
      );
    }
    await AuthSessionController.instance.applyAuthResponse(payload);
    return payload;
  }

  Future<Map<String, dynamic>> resendClientLoginCode(String challengeId) async {
    final json =
        await _apiClient.postJson('/auth/client/login/resend-code', body: {
      'challengeId': challengeId,
    });
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> loginClientWithGoogle({
    String? idToken,
    String? accessToken,
    String? email,
    String? fullName,
  }) async {
    final normalizedIdToken = idToken?.trim();
    final normalizedAccessToken = accessToken?.trim();

    if ((normalizedIdToken == null || normalizedIdToken.isEmpty) &&
        (normalizedAccessToken == null || normalizedAccessToken.isEmpty)) {
      throw Exception('Google sign-in did not return a usable token.');
    }

    final json = await _apiClient.postJson('/auth/client/oauth/google', body: {
      if (normalizedIdToken != null && normalizedIdToken.isNotEmpty)
        'idToken': normalizedIdToken,
      if (normalizedAccessToken != null && normalizedAccessToken.isNotEmpty)
        'accessToken': normalizedAccessToken,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (fullName != null && fullName.trim().isNotEmpty)
        'fullName': fullName.trim(),
    });
    final payload = Map<String, dynamic>.from(json as Map);
    await AuthSessionController.instance.applyAuthResponse(payload);
    return payload;
  }

  Future<Map<String, dynamic>> bootstrapOperator({
    required String fullName,
    required String email,
    required String password,
    String? workspaceName,
  }) async {
    final json = await _apiClient.postJson('/auth/operator/bootstrap', body: {
      'fullName': fullName,
      'email': email,
      'password': password,
      if (workspaceName != null && workspaceName.trim().isNotEmpty)
        'workspaceName': workspaceName.trim(),
    });
    final payload = Map<String, dynamic>.from(json as Map);
    await AuthSessionController.instance.applyAuthResponse(payload);
    return payload;
  }

  Future<Map<String, dynamic>> loginOperator({
    required String email,
    required String password,
  }) async {
    final trustedDeviceToken =
        await AuthSessionController.instance.trustedDeviceToken(
      surface: 'operator',
    );
    final json = await _apiClient.postJson('/auth/operator/login', body: {
      'email': email,
      'password': password,
      if (trustedDeviceToken.isNotEmpty)
        'trustedDeviceToken': trustedDeviceToken,
      'deviceName': 'Current device',
    });
    final payload = Map<String, dynamic>.from(json as Map);
    if (payload['requiresEmailCodeChallenge'] != true) {
      await AuthSessionController.instance.applyAuthResponse(payload);
    }
    return payload;
  }

  Future<Map<String, dynamic>> verifyOperatorLoginCode({
    required String challengeId,
    required String code,
    required bool trustDevice,
  }) async {
    final json =
        await _apiClient.postJson('/auth/operator/login/verify-code', body: {
      'challengeId': challengeId,
      'code': code,
      'trustDevice': trustDevice,
      'deviceName': 'Current device',
    });
    final payload = Map<String, dynamic>.from(json as Map);
    final trustedDeviceToken = payload['trustedDeviceToken']?.toString() ?? '';
    if (trustedDeviceToken.isNotEmpty) {
      await AuthSessionController.instance.saveTrustedDeviceToken(
        trustedDeviceToken,
        surface: 'operator',
      );
    }
    await AuthSessionController.instance.applyAuthResponse(payload);
    return payload;
  }

  Future<Map<String, dynamic>> fetchTrustedDevices() async {
    final json = await _apiClient.getJson('/auth/trusted-devices',
        surface: ApiSurface.client);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<void> revokeTrustedDevice(String deviceId) async {
    await _apiClient.postJson('/auth/trusted-devices/revoke',
        surface: ApiSurface.client, body: {'deviceId': deviceId});
  }

  Future<void> revokeAllTrustedDevices() async {
    await _apiClient.deleteJson('/auth/trusted-devices',
        surface: ApiSurface.client);
  }

  Future<Map<String, dynamic>> currentSession() async {
    final json = await _apiClient.getJson('/auth/me');
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> fetchClientSetup() async {
    final json = await _apiClient.getJson('/clients/me/setup',
        surface: ApiSurface.client);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> saveClientSetup({
    required String serviceType,
    required String scopeMode,
    required List<Map<String, String>> countries,
    required List<Map<String, String>> regions,
    required List<Map<String, String>> industries,
    List<Map<String, String>> metros = const [],
    List<String> includeGeo = const [],
    List<String> excludeGeo = const [],
    List<String> priorityMarkets = const [],
    String? notes,
    String? selectedPlan,
    String? selectedTier,
    Map<String, dynamic>? metadata,
  }) async {
    final json = await _apiClient.postJson(
      '/clients/me/setup',
      surface: ApiSurface.client,
      body: {
        'serviceType': serviceType.trim().toLowerCase(),
        'scopeMode': scopeMode.trim().toLowerCase(),
        'countries': countries,
        'regions': regions,
        'metros': metros,
        'industries': industries,
        if (includeGeo.isNotEmpty) 'includeGeo': includeGeo,
        if (excludeGeo.isNotEmpty) 'excludeGeo': excludeGeo,
        if (priorityMarkets.isNotEmpty) 'priorityMarkets': priorityMarkets,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (selectedPlan != null && selectedPlan.trim().isNotEmpty)
          'selectedPlan': selectedPlan.trim().toLowerCase(),
        if (selectedTier != null && selectedTier.trim().isNotEmpty)
          'selectedTier': selectedTier.trim().toLowerCase(),
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      },
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<void> logout() async {
    await _apiClient.postJson('/auth/logout', body: const {});
  }

  Future<void> requestPasswordReset(String email) async {
    await _apiClient.postJson('/auth/password/request-reset', body: {
      'email': email,
    });
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await _apiClient.postJson('/auth/password/reset', body: {
      'token': token,
      'password': password,
    });
  }

  /// Verify an email-verification token. When the response includes
  /// `trustedDeviceToken` (the backend issues one for the device that
  /// clicked the link), persist it locally so the next JWT expiry on
  /// this device does not force a 2FA code challenge. Without this
  /// step the user has to do one code-challenge round after their
  /// initial session expires, just to bootstrap the first trusted
  /// device — the doctrine is to start the trusted window at email
  /// verification time, since the link was delivered to the user's
  /// own email and the click happens in their browser.
  Future<Map<String, dynamic>> verifyEmail(String token) async {
    final json = await _apiClient.postJson('/auth/email/verify', body: {
      'token': token,
      'deviceName': 'Current device',
    });
    final payload = json is Map
        ? json.map((k, v) => MapEntry('$k', v))
        : <String, dynamic>{};
    final trustedDeviceToken =
        payload['trustedDeviceToken']?.toString() ?? '';
    if (trustedDeviceToken.isNotEmpty) {
      await AuthSessionController.instance.saveTrustedDeviceToken(
        trustedDeviceToken,
        surface: 'client',
      );
    }
    return payload;
  }

  Future<void> requestEmailVerification(String email) async {
    await _apiClient.postJson('/auth/email/request-verification', body: {
      'email': email,
    });
  }
}
