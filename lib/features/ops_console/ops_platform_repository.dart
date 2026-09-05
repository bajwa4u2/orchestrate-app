import '../../core/network/api_client.dart';

/// WHAT THE PLATFORM MAY SEE ACROSS THE BUSINESSES IT SERVES.
///
/// A separate repository from `OpsConsoleRepository` on purpose. That one reads
/// the organisation the session belongs to, which for a platform operator holds
/// nothing at all — no clients, no mailboxes, no domains, no campaigns. These
/// read across organisations, under named capabilities, and return operational
/// state rather than the content a business keeps in Orchestrate.
///
/// Keeping them apart means a screen has to choose which it is asking, and a
/// cross-organisation read cannot be reached by accident from a tenant-scoped
/// call site.
class OpsPlatformRepository {
  OpsPlatformRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query}) async {
    final json = await _api.getJson(
      path,
      query: query,
      surface: ApiSurface.operator,
    );
    return json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};
  }

  /// Which businesses exist, what state each is in, and what is blocking it.
  Future<Map<String, dynamic>> clients() => _get('/operator/platform/clients');

  /// Whether client mailboxes and sending domains can get mail out.
  Future<Map<String, dynamic>> transport() => _get('/operator/platform/transport');

  /// Imports that did not land, and how far they got.
  Future<Map<String, dynamic>> imports() => _get('/operator/platform/imports');

  /// Campaign execution state where Orchestrate owes the delivery.
  Future<Map<String, dynamic>> campaigns() => _get('/operator/platform/campaigns');

  /// What authority exists, why, and what was decided along the way.
  Future<Map<String, dynamic>> authority({String? clientId}) => _get(
        '/operator/platform/authority',
        query: clientId == null ? null : {'clientId': clientId},
      );

  /// Re-check held messages against the relevance authority.
  ///
  /// Counts by default. `apply` performs the withdrawal, which is a correction
  /// of the platform's own over-collection and never a decision about anybody's
  /// mail.
  Future<Map<String, dynamic>> reconcileQuarantineRelevance({bool apply = false}) async {
    final json = await _api.postJson(
      '/operator/platform/quarantine/reconcile-relevance${apply ? '?apply=true' : ''}',
      body: const {},
      surface: ApiSurface.operator,
    );
    return json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};
  }
}
