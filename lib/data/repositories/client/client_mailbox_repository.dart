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

  /// Truthful provider availability for the Connect surface. Each entry
  /// is `{ key: 'google'|'microsoft', label, available: bool, reason }`.
  /// Providers without configured OAuth credentials report `available:
  /// false, reason: 'provider_not_configured'` — the UI must not render
  /// a Connect button for those.
  Future<List<Map<String, dynamic>>> fetchProviderAvailability() async {
    try {
      final json = await _apiClient.getJson(
        '/public/mailbox/providers',
        surface: ApiSurface.public,
      );
      final list = _asList(_asMap(json)['providers']);
      return list.map(_asMap).toList();
    } catch (error) {
      debugPrint(
          '[client_mailbox_repository] /public/mailbox/providers failed: $error');
      // Fall back to "neither known available" rather than fake parity.
      // This is conservative: if availability is unknown, the UI surfaces
      // a "Provider availability is unknown" line rather than a Connect
      // button that would dead-end on the backend.
      return const <Map<String, dynamic>>[];
    }
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

  /// Attach a sending domain independently of mailbox connection.
  /// Lets a client publish SPF / DMARC and begin DNS verification
  /// before selecting a transport (Google / Microsoft / SMTP / future
  /// adapters). Returns the same shape as [fetchSendingDomain].
  Future<Map<String, dynamic>> attachSendingDomain(String domain) async {
    final json = await _apiClient.postJson(
      '/client/mailbox/domain/attach',
      body: <String, dynamic>{'domain': domain},
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Provider catalog the chooser renders. Returned as data so the
  /// frontend never hard-codes provider labels.
  Future<List<Map<String, dynamic>>> fetchProviderCatalog() async {
    final json = await _apiClient.getJson(
      '/client/mailbox/smtp/providers/catalog',
      surface: ApiSurface.client,
    );
    final providers = _asMap(json)['providers'];
    if (providers is List) {
      return providers.whereType<Map>().map(_asMap).toList();
    }
    return const <Map<String, dynamic>>[];
  }

  /// Validate SMTP credentials without persisting anything. Used by
  /// the pre-save "Test connection" affordance on the SMTP onboarding
  /// form. Throws ApiException on failure with the upstream SMTP error.
  Future<Map<String, dynamic>> testSmtpConnection({
    required String host,
    required int port,
    required String secure,
    required String username,
    required String password,
    required String fromAddress,
    String? fromName,
    String? replyTo,
    String? providerOverride,
  }) async {
    final json = await _apiClient.postJson(
      '/client/mailbox/smtp/test-connection',
      body: <String, dynamic>{
        'host': host,
        'port': port,
        'secure': secure,
        'username': username,
        'password': password,
        'fromAddress': fromAddress,
        if (fromName != null && fromName.trim().isNotEmpty) 'fromName': fromName,
        if (replyTo != null && replyTo.trim().isNotEmpty) 'replyTo': replyTo,
        if (providerOverride != null && providerOverride.isNotEmpty)
          'providerOverride': providerOverride,
      },
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Validate IMAP credentials without persisting anything.
  Future<Map<String, dynamic>> testImapConnection({
    required String host,
    required int port,
    required String secure,
    required String username,
    required String password,
    String? folder,
  }) async {
    final json = await _apiClient.postJson(
      '/client/mailbox/imap/test-connection',
      body: <String, dynamic>{
        'host': host,
        'port': port,
        'secure': secure,
        'username': username,
        'password': password,
        if (folder != null && folder.trim().isNotEmpty) 'folder': folder,
      },
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Attach IMAP inbound monitoring to an existing SMTP mailbox.
  /// Returns the folder name + message count from the upstream IMAP
  /// server so the client sees the connection was real.
  Future<Map<String, dynamic>> connectImapMailbox({
    required String mailboxId,
    required String host,
    required int port,
    required String secure,
    required String username,
    required String password,
    String? folder,
  }) async {
    final json = await _apiClient.postJson(
      '/client/mailbox/imap/connect',
      body: <String, dynamic>{
        'mailboxId': mailboxId,
        'host': host,
        'port': port,
        'secure': secure,
        'username': username,
        'password': password,
        if (folder != null && folder.trim().isNotEmpty) 'folder': folder,
      },
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Combined custom mail transport setup. Validates SMTP outbound +
  /// (optionally) IMAP inbound in a single backend call. SMTP is
  /// required; IMAP is part of the same flow so a paying client never
  /// lands in an outbound-only state without explicitly opting in.
  Future<Map<String, dynamic>> connectCustomTransport({
    required Map<String, dynamic> smtp,
    Map<String, dynamic>? imap,
  }) async {
    final body = <String, dynamic>{
      'smtp': smtp,
      if (imap != null) 'imap': imap,
    };
    final json = await _apiClient.postJson(
      '/client/mailbox/custom-transport/connect',
      body: body,
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Persist an SMTP transport. Validates credentials, vaults the
  /// bundle, creates the Mailbox row, attaches the sending domain,
  /// and returns the DKIM TXT record the client must publish.
  Future<Map<String, dynamic>> connectSmtpMailbox({
    required String host,
    required int port,
    required String secure,
    required String username,
    required String password,
    required String fromAddress,
    String? fromName,
    String? replyTo,
    String? mailboxId,
  }) async {
    final json = await _apiClient.postJson(
      '/client/mailbox/smtp/connect',
      body: <String, dynamic>{
        'host': host,
        'port': port,
        'secure': secure,
        'username': username,
        'password': password,
        'fromAddress': fromAddress,
        if (fromName != null && fromName.trim().isNotEmpty) 'fromName': fromName,
        if (replyTo != null && replyTo.trim().isNotEmpty) 'replyTo': replyTo,
        if (mailboxId != null && mailboxId.isNotEmpty) 'mailboxId': mailboxId,
      },
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Kick off a backend-owned OAuth mailbox connect for [provider]
  /// (`google` or `microsoft`). Returns `{ authorizeUrl, state,
  /// mailboxId, expiresAtIso }` — the caller opens [authorizeUrl] in
  /// the system browser. Pass [mailboxId] to re-auth an existing
  /// REQUIRES_REAUTH mailbox; omit to create a fresh pending row.
  Future<Map<String, dynamic>> startMailboxOAuth({
    required String provider,
    String? mailboxId,
  }) async {
    final body = <String, dynamic>{};
    if (mailboxId != null && mailboxId.isNotEmpty) {
      body['mailboxId'] = mailboxId;
    }
    final json = await _apiClient.postJson(
      '/client/mailbox/oauth/$provider/start',
      body: body,
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
