import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';

class ClientRelationshipRepository {
  ClientRelationshipRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Fetch the cached relationship inventory. Returns the current scan
  /// state and all derived contacts. If no scan has ever run, returns
  /// `{ "scanState": "none" }`. Treats 404 as "none" so the screen
  /// degrades gracefully while the backend endpoint is being deployed.
  Future<Map<String, dynamic>> fetchInventory() async {
    try {
      final json = await _apiClient.getJson(
        '/client/intelligence/relationships',
        surface: ApiSurface.client,
      );
      return _asMap(json);
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) rethrow;
      if (error is ApiException && error.statusCode == 404) {
        return const <String, dynamic>{'scanState': 'none'};
      }
      debugPrint('[client_relationship_repository] fetchInventory failed: $error');
      rethrow;
    }
  }

  /// Trigger a new mailbox header scan. The client must attest that
  /// header analysis is approved before the job starts.
  Future<Map<String, dynamic>> triggerScan({int lookbackDays = 90}) async {
    final json = await _apiClient.postJson(
      '/client/intelligence/relationships/scan',
      body: <String, dynamic>{
        'attestedHeaderScan': true,
        'lookbackDays': lookbackDays,
      },
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Poll scan job status. Call repeatedly until status is 'complete'
  /// or 'failed'.
  Future<Map<String, dynamic>> fetchScanStatus(String scanId) async {
    final json = await _apiClient.getJson(
      '/client/intelligence/relationships/scan/$scanId/status',
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Suppress a contact. Suppression is durable — it survives rescans
  /// and prevents the contact from entering the outreach pool.
  Future<Map<String, dynamic>> suppress(
    String email, {
    String reason = 'client_request',
  }) async {
    final json = await _apiClient.postJson(
      '/client/intelligence/relationships/${Uri.encodeComponent(email)}/suppress',
      body: <String, dynamic>{'reason': reason},
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Lift a suppression. Contact becomes eligible for outreach pool again.
  Future<Map<String, dynamic>> unsuppress(String email) async {
    final json = await _apiClient.deleteJson(
      '/client/intelligence/relationships/${Uri.encodeComponent(email)}/suppress',
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Remove a relationship record from Orchestrate. The source (mailbox
  /// messages) is untouched. The email is recorded so future scans
  /// surface a re-discovery prompt rather than silently re-adding it.
  Future<Map<String, dynamic>> deleteContact(String email) async {
    final json = await _apiClient.deleteJson(
      '/client/intelligence/relationships/${Uri.encodeComponent(email)}',
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Incremental resync — processes headers since the last scan only.
  /// Does not reset existing contacts.
  Future<Map<String, dynamic>> resync() async {
    final json = await _apiClient.postJson(
      '/client/intelligence/relationships/sources/mailbox/resync',
      body: const <String, dynamic>{},
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Full rebuild — clears MAILBOX_INTELLIGENCE records and runs a
  /// complete 90-day scan. Suppression decisions are preserved.
  Future<Map<String, dynamic>> rebuild() async {
    final json = await _apiClient.postJson(
      '/client/intelligence/relationships/rebuild',
      body: const <String, dynamic>{},
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Remove mailbox as a relationship intelligence source.
  /// behavior: 'keep' | 'remove_exclusive' | 'remove_all'
  Future<Map<String, dynamic>> removeSource(String behavior) async {
    final json = await _apiClient.deleteJson(
      '/client/intelligence/relationships/sources/mailbox',
      body: <String, dynamic>{'behavior': behavior},
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Confirm re-discovered contact should be kept or skipped again.
  Future<Map<String, dynamic>> resolveReDiscovery(
    String email, {
    required bool keep,
  }) async {
    final json = await _apiClient.postJson(
      '/client/intelligence/relationships/rediscovered/${Uri.encodeComponent(email)}/resolve',
      body: <String, dynamic>{'keep': keep},
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Upload a CSV file and import relationships from it.
  /// Sends multipart/form-data. Returns { imported, updated, skipped, assetFileId }.
  Future<Map<String, dynamic>> importCsv(
    List<int> fileBytes,
    String filename,
  ) async {
    final json = await _apiClient.postMultipart(
      '/client/intelligence/relationships/sources/csv',
      fileBytes: fileBytes,
      filename: filename,
      fieldName: 'file',
      contentType: 'text/csv',
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Remove CSV-imported contacts.
  /// behavior: 'keep' | 'remove_exclusive' | 'remove_all'
  Future<Map<String, dynamic>> removeCsvSource(String behavior) async {
    final json = await _apiClient.deleteJson(
      '/client/intelligence/relationships/sources/csv',
      body: <String, dynamic>{'behavior': behavior},
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Sync relationships from a connected Google mailbox.
  /// Returns { status, count? } — status may be 'synced', 'no_google_mailbox',
  /// 'insufficient_scope', or 'failed'.
  Future<Map<String, dynamic>> syncGoogleContacts() async {
    final json = await _apiClient.postJson(
      '/client/intelligence/relationships/sources/google/sync',
      body: const <String, dynamic>{},
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Remove Google-synced contacts.
  Future<Map<String, dynamic>> removeGoogleSource(String behavior) async {
    final json = await _apiClient.deleteJson(
      '/client/intelligence/relationships/sources/google',
      body: <String, dynamic>{'behavior': behavior},
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Manually add a single contact.
  Future<Map<String, dynamic>> addManual(
    String email, {
    String? name,
    String? organization,
  }) async {
    final json = await _apiClient.postJson(
      '/client/intelligence/relationships/sources/manual',
      body: <String, dynamic>{
        'email': email,
        if (name != null) 'name': name,
        if (organization != null) 'organization': organization,
      },
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Remove manually-added contacts.
  Future<Map<String, dynamic>> removeManualSource(String behavior) async {
    final json = await _apiClient.deleteJson(
      '/client/intelligence/relationships/sources/manual',
      body: <String, dynamic>{'behavior': behavior},
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry('$k', v));
    return const <String, dynamic>{};
  }
}
