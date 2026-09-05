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

  /// THE STRIP HAS TO BE ABOUT THE PLATFORM, BECAUSE IT SITS ON EVERY SCREEN.
  ///
  /// It read the organisation of the session, which for a platform operator
  /// holds nothing — so it said "Mailboxes 0 / 0 · Domains 0 / 0 · Re-auth 0"
  /// above a Transport page listing three mailboxes, every one of which needed
  /// reconnecting. A permanent strip that quietly describes a different scope
  /// from the page under it is worse than no strip: it is read as the headline
  /// and it was wrong on every screen.
  ///
  /// Now read from the platform transport projection, under the capability that
  /// already governs exactly this state. The vault fact still comes from the
  /// organisation composition — where credentials are held is a property of the
  /// deployment, not of a tenant.
  Future<SystemStatus> fetch() async {
    final results = await Future.wait([
      _api.getJson('/operator/cognition/home', surface: ApiSurface.operator),
      _api.getJson('/operator/platform/transport', surface: ApiSurface.operator),
    ]);
    final vault = _map(_map(_map(results[0])['trustRibbon'])['vault']);
    final transport = _map(results[1]);

    final mailboxes = (transport['mailboxes'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final domains = (transport['domains'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    return SystemStatus(
      vaultAdapter: (vault['adapter'] ?? 'unknown').toString(),
      vaultWarning: vault['warning'] == true,
      mailboxesHealthy:
          mailboxes.where((m) => m['connection'] == 'AUTHORIZED').length,
      mailboxesTotal: mailboxes.length,
      domainsVerified: domains.where((d) => d['status'] == 'ACTIVE').length,
      domainsTotal: domains.length,
      mailboxesAwaitingReauth:
          mailboxes.where((m) => m['needsReconnect'] == true).length,
    );
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}
