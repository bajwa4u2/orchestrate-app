import '../../../core/network/api_client.dart';

/// The authorised-representative designation, from the client's side.
///
/// The backend owns every word of the designation itself — what it establishes,
/// what it explicitly does not, and the sentence a person is agreeing to. This
/// repository never composes that text. Restating it here would create a second
/// copy that drifts, and the thing being agreed to is exactly the thing that
/// must not drift.
///
/// The artifact hash comes back with the artifact and is submitted unchanged,
/// so the record says which version of the wording the person actually saw.
class ClientRepresentativeRepository {
  ClientRepresentativeRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// The designation to read, and where this business currently stands.
  Future<Map<String, dynamic>> fetchCurrent() async {
    final json = await _apiClient.getJson(
      '/client/representative',
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  /// The people this business recognises, and what each is recognised for.
  Future<Map<String, dynamic>> fetchPeople() async {
    final json = await _apiClient.getJson(
      '/client/representative/people',
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  /// Submit the designation.
  ///
  /// [requested] is what the person says the business authorises them to do.
  /// An operator may narrow it and may never widen it, so asking for more than
  /// is true costs the person time rather than gaining them anything.
  Future<Map<String, dynamic>> submit({
    required List<Map<String, dynamic>> requested,
    required bool acknowledgedRepresentation,
    required String artifactHash,
    String? roleTitleText,
    String? supportingReference,
    String? supportingKind,
  }) async {
    final json = await _apiClient.postJson(
      '/client/representative',
      surface: ApiSurface.client,
      body: {
        'requested': requested,
        'acknowledgedRepresentation': acknowledgedRepresentation,
        'artifactHash': artifactHash,
        if (roleTitleText != null && roleTitleText.trim().isNotEmpty)
          'roleTitleText': roleTitleText.trim(),
        if (supportingReference != null && supportingReference.trim().isNotEmpty)
          'supportingReference': supportingReference.trim(),
        if (supportingKind != null && supportingKind.trim().isNotEmpty)
          'supportingKind': supportingKind.trim(),
      },
    );
    return Map<String, dynamic>.from(json as Map);
  }

  /// Send the confirmation email again.
  ///
  /// Exists because a refusal that says "confirm your email" and offers no way
  /// to do it is a dead end.
  Future<Map<String, dynamic>> resendVerification() async {
    final json = await _apiClient.postJson(
      '/client/representative/resend-verification',
      surface: ApiSurface.client,
      body: const {},
    );
    return Map<String, dynamic>.from(json as Map);
  }

  /// Invite a colleague to be recognised, and say what for.
  ///
  /// Inviting is not granting. The business proposes; the person acknowledges
  /// the designation themselves; an operator admits it.
  Future<Map<String, dynamic>> invite({
    required String email,
    String? name,
    String? roleTitleText,
    List<Map<String, dynamic>> suggested = const [],
  }) async {
    final json = await _apiClient.postJson(
      '/client/representative/invite',
      surface: ApiSurface.client,
      body: {
        'email': email.trim(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (roleTitleText != null && roleTitleText.trim().isNotEmpty)
          'roleTitleText': roleTitleText.trim(),
        'suggested': suggested,
      },
    );
    return Map<String, dynamic>.from(json as Map);
  }

  /// Withdraw one person's authority in one area.
  ///
  /// This stops that person authorising anything further. It does not unwind
  /// what was already done under authority that was valid at the time, and the
  /// screen says so rather than implying a reversal.
  Future<Map<String, dynamic>> withdraw({
    required String userId,
    required String area,
    String? reason,
  }) async {
    final json = await _apiClient.postJson(
      '/client/representative/people/$userId/withdraw',
      surface: ApiSurface.client,
      body: {
        'area': area,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return Map<String, dynamic>.from(json as Map);
  }
}
