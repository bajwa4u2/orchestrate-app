import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';

/// Talks to /client/business-identity. Read-only or partial save.
/// Never mutates mailbox / sending identity / subscription state.
class ClientBusinessIdentityRepository {
  ClientBusinessIdentityRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchProfile() async {
    final json = await _apiClient.getJson(
      '/client/business-identity',
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> patchProfile(Map<String, dynamic> patch) async {
    final json = await _apiClient.patchJson(
      '/client/business-identity',
      body: patch,
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> fetchReadiness() async {
    try {
      final json = await _apiClient.getJson(
        '/client/business-identity/readiness',
        surface: ApiSurface.client,
      );
      return _asMap(json);
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) rethrow;
      debugPrint('[business_identity_repository] readiness failed: $error');
      return const <String, dynamic>{};
    }
  }

  /// Returns the readiness payload plus a suggested guidance target the
  /// caller can use with the existing GuidanceRepository.
  Future<Map<String, dynamic>> fetchGuidance() async {
    try {
      final json = await _apiClient.getJson(
        '/client/business-identity/guidance',
        surface: ApiSurface.client,
      );
      return _asMap(json);
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) rethrow;
      debugPrint('[business_identity_repository] guidance failed: $error');
      return const <String, dynamic>{};
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry('$k', v));
    return <String, dynamic>{};
  }
}
