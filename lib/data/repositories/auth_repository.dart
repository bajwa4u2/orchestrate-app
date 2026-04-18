import '../../core/auth/auth_session.dart';
import '../../core/network/api_client.dart';

class AuthRepository {
  AuthRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

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
      if (websiteUrl != null && websiteUrl.trim().isNotEmpty) 'websiteUrl': websiteUrl.trim(),
    });
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> loginClient({
    required String email,
    required String password,
  }) async {
    final json = await _apiClient.postJson('/auth/client/login', body: {
      'email': email,
      'password': password,
    });
    final payload = Map<String, dynamic>.from(json as Map);
    await AuthSessionController.instance.applyAuthResponse(payload);
    return payload;
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
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> loginOperator({
    required String email,
    required String password,
  }) async {
    final json = await _apiClient.postJson('/auth/operator/login', body: {
      'email': email,
      'password': password,
    });
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> currentSession() async {
    final json = await _apiClient.getJson('/auth/me');
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> fetchClientSetup() async {
    final json = await _apiClient.getJson('/clients/me/setup', surface: ApiSurface.client);
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

  Future<void> verifyEmail(String token) async {
    await _apiClient.postJson('/auth/email/verify', body: {
      'token': token,
    });
  }

  Future<void> requestEmailVerification(String email) async {
    await _apiClient.postJson('/auth/email/request-verification', body: {
      'email': email,
    });
  }
}
