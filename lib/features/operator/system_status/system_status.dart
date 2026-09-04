import '../../../core/network/api_client.dart';

/// WHETHER THE THINGS ORCHESTRATE RUNS ON ARE HEALTHY.
///
/// The strip across the top of every operator screen. Four facts, each one a
/// thing an operator can act on: where credentials are stored, how many
/// mailboxes are healthy, how many sending domains are verified, and how many
/// mailboxes are waiting to be re-authorised.
///
/// EXTRACTED, NOT INHERITED. This came out of a 625-line `cognition_models.dart`
/// in an operator estate that was retired — 12,000 lines of adaptation,
/// reasoning-cache, convergence and green-path surfaces that no navigation
/// reached. The strip was the one genuinely live thing in it, so it was lifted
/// out and the rest went.
///
/// Named for what an operator sees rather than for the endpoint that serves it.
/// The backend still calls its composition `cognition`; that is an
/// implementation word, and it does not belong in a product domain.
class SystemStatus {
  const SystemStatus({
    required this.vaultAdapter,
    required this.vaultWarning,
    required this.mailboxesHealthy,
    required this.mailboxesTotal,
    required this.domainsVerified,
    required this.domainsTotal,
    required this.mailboxesAwaitingReauth,
  });

  /// Where credentials are actually held. Worth showing because the wrong
  /// answer here — an in-memory adapter in production — means every stored
  /// credential is one restart from gone.
  final String vaultAdapter;
  final bool vaultWarning;

  final int mailboxesHealthy;
  final int mailboxesTotal;
  final int domainsVerified;
  final int domainsTotal;

  /// Mailboxes whose authorisation has lapsed. Each one is a client who cannot
  /// send until a person does something about it.
  final int mailboxesAwaitingReauth;

  bool get anythingNeedsAttention =>
      vaultWarning ||
      mailboxesAwaitingReauth > 0 ||
      (mailboxesTotal > 0 && mailboxesHealthy < mailboxesTotal) ||
      (domainsTotal > 0 && domainsVerified < domainsTotal);

  static SystemStatus fromJson(Map<String, dynamic> json) {
    final vault = _map(json['vault']);
    final providers = _map(json['providers']);
    final dns = _map(json['dns']);
    return SystemStatus(
      vaultAdapter: (vault['adapter'] ?? 'unknown').toString(),
      vaultWarning: vault['warning'] == true,
      mailboxesHealthy: _int(providers['healthy']),
      mailboxesTotal: _int(providers['total']),
      domainsVerified: _int(dns['verified']),
      domainsTotal: _int(dns['total']),
      mailboxesAwaitingReauth: _int(json['oauthReauthRequired']),
    );
  }
}

class SystemStatusRepository {
  SystemStatusRepository({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  /// Reads the operator composition endpoint and keeps only the four facts the
  /// strip states. The response carries a great deal more; none of the rest
  /// corresponded to an operator responsibility, which is why the surfaces
  /// built on it were retired.
  Future<SystemStatus> fetch() async {
    final json = await _api.getJson(
      '/operator/cognition/home',
      surface: ApiSurface.operator,
    );
    final map = _map(json);
    return SystemStatus.fromJson(_map(map['trustRibbon']));
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}
