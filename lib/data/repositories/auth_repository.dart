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

  Future<void> logout() async {
    await _apiClient.postJson('/auth/logout', body: const {});
  }

  Future<void> requestPasswordReset(String email) async {
    await _apiClient.postJson('/auth/password/request-reset', body: {
      'email': email,
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
