import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';

class ClientMailboxRepository {
  ClientMailboxRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchMailbox() async {
    final json =
        await _apiClient.getJson('/client/mailbox', surface: ApiSurface.client);
    return _asMap(json);
  }

  Future<Map<String, dynamic>> activateMailbox() async {
    final json = await _apiClient.postJson(
      '/client/mailbox/activate',
      body: const <String, dynamic>{},
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> fetchSendingDomain() async {
    try {
      final json = await _apiClient.getJson('/client/mailbox/domain',
          surface: ApiSurface.client);
      return _asMap(json);
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) rethrow;
      if (error is ApiException && error.statusCode == 404) {
        return const <String, dynamic>{};
      }
      debugPrint('[client_mailbox_repository] /client/mailbox/domain failed: $error');
      return const <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> verifySendingDomain() async {
    final json = await _apiClient.postJson(
      '/client/mailbox/domain/verify',
      body: const <String, dynamic>{},
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> fetchResponseEligibility(String replyId) async {
    final json = await _apiClient.getJson(
      '/client/replies/$replyId/response-eligibility',
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> sendReplyResponse({
    required String replyId,
    required String subject,
    required String bodyText,
  }) async {
    final json = await _apiClient.postJson(
      '/client/replies/$replyId/respond',
      body: <String, dynamic>{
        'subject': subject,
        'bodyText': bodyText,
      },
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  Future<List<Map<String, dynamic>>> fetchReplies({int limit = 12}) async {
    final json = await _apiClient.getJson(
      '/replies',
      query: <String, String>{'limit': '$limit'},
      surface: ApiSurface.client,
    );
    return _asList(json).map(_asMap).toList();
  }

  Future<List<Map<String, dynamic>>> fetchRepliesSafe({int limit = 12}) async {
    try {
      return await fetchReplies(limit: limit);
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) rethrow;
      debugPrint('[client_mailbox_repository] /replies failed: $error');
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchEmailDispatches() async {
    final json = await _apiClient.getJson('/client/email-dispatches',
        surface: ApiSurface.client);
    return _asList(json).map(_asMap).toList();
  }

  Future<List<Map<String, dynamic>>> fetchEmailDispatchesSafe() async {
    try {
      return await fetchEmailDispatches();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) rethrow;
      debugPrint('[client_mailbox_repository] /client/email-dispatches failed: $error');
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final json = await _apiClient.getJson('/client/notifications',
        surface: ApiSurface.client);
    return _asList(json).map(_asMap).toList();
  }

  Future<List<Map<String, dynamic>>> fetchNotificationsSafe() async {
    try {
      return await fetchNotifications();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) rethrow;
      debugPrint('[client_mailbox_repository] /client/notifications failed: $error');
      return const <Map<String, dynamic>>[];
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry('$key', item));
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) =>
      value is List ? value : const <dynamic>[];
}
