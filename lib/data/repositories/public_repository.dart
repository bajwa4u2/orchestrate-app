import '../../core/network/api_client.dart';

class PublicRepository {
  PublicRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchPricing() async {
    final json = await _apiClient.getJson('/public/pricing');
    return Map<String, dynamic>.from(json as Map);
  }
}
