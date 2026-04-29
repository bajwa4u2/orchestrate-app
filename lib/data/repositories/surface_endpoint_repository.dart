import 'package:orchestrate_app/core/network/api_client.dart';

class SurfaceEndpointRepository {
  SurfaceEndpointRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<EndpointSnapshot> get(
    String path, {
    Map<String, String>? query,
    ApiSurface surface = ApiSurface.public,
  }) async {
    try {
      final json =
          await _apiClient.getJson(path, query: query, surface: surface);
      return EndpointSnapshot.available(path: path, data: _normalize(json));
    } on ApiException catch (error) {
      return EndpointSnapshot.unavailable(
        path: path,
        statusCode: error.statusCode,
        reason: error.displayMessage,
        requestId: error.requestId,
        correlationId: error.correlationId,
      );
    } catch (error) {
      return EndpointSnapshot.unavailable(path: path, reason: error.toString());
    }
  }

  dynamic _normalize(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry('$key', item));
    if (value is List) {
      return value
          .map((item) => item is Map
              ? item.map((key, value) => MapEntry('$key', value))
              : item)
          .toList();
    }
    return value;
  }

}

class EndpointSnapshot {
  const EndpointSnapshot({
    required this.path,
    required this.available,
    this.data,
    this.statusCode,
    this.reason,
    this.requestId,
    this.correlationId,
  });

  factory EndpointSnapshot.available({
    required String path,
    required dynamic data,
  }) {
    return EndpointSnapshot(path: path, available: true, data: data);
  }

  factory EndpointSnapshot.unavailable({
    required String path,
    int? statusCode,
    String? reason,
    String? requestId,
    String? correlationId,
  }) {
    return EndpointSnapshot(
      path: path,
      available: false,
      statusCode: statusCode,
      reason: reason,
      requestId: requestId,
      correlationId: correlationId,
    );
  }

  final String path;
  final bool available;
  final dynamic data;
  final int? statusCode;
  final String? reason;
  final String? requestId;
  final String? correlationId;

  List<dynamic> get items {
    final value = data;
    if (value is List) return value;
    if (value is Map) {
      final raw = value['items'] ??
          value['data'] ??
          value['results'] ??
          value['dispatches'] ??
          value['notifications'] ??
          value['alerts'] ??
          value['mailboxes'] ??
          value['domains'] ??
          value['policies'] ??
          value['suppressions'];
      if (raw is List) return raw;
    }
    return const <dynamic>[];
  }

  Map<String, dynamic> get map {
    final value = data;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry('$key', item));
    return const <String, dynamic>{};
  }
}
