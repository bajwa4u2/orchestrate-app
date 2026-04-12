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
    return Map<String, dynamic>.from(json as Map);
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
    required String countryCode,
    required String countryName,
    required String regionType,
    required String regionCode,
    required String regionName,
    String? localityName,
    required String industryCode,
    required String industryLabel,
    required String selectedPlan,
  }) async {
    final json = await _apiClient.postJson(
      '/clients/me/setup',
      surface: ApiSurface.client,
      body: {
        'countryCode': countryCode,
        'countryName': countryName,
        'regionType': regionType,
        'regionCode': regionCode,
        'regionName': regionName,
        if (localityName != null && localityName.trim().isNotEmpty)
          'localityName': localityName.trim(),
        'industryCode': industryCode,
        'industryLabel': industryLabel,
        'selectedPlan': selectedPlan,
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

  Future<Map<String, dynamic>> verifyEmail(String token) async {
    final json = await _apiClient.postJson('/auth/email/verify', body: {
      'token': token,
    });
    return Map<String, dynamic>.from(json as Map);
  }

  Future<void> requestEmailVerification(String email) async {
    await _apiClient.postJson('/auth/email/request-verification', body: {
      'email': email,
    });
  }
}
