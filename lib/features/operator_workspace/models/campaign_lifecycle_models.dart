// Operator-side typed model for the campaign-lifecycle truth
// surface. Mirrors GET /campaigns/lifecycle — the canonical,
// runtime-backed view of every real campaign. Same Campaign source
// the client workspace and the discovery sweep read.

class OperatorCampaignLifecycleView {
  const OperatorCampaignLifecycleView({
    required this.asOf,
    required this.total,
    required this.active,
    required this.byState,
    required this.campaigns,
  });

  final DateTime asOf;
  final int total;
  final int active;
  final Map<String, int> byState;
  final List<OperatorCampaignRow> campaigns;

  factory OperatorCampaignLifecycleView.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : <String, dynamic>{};
    final byStateRaw = summary['byLifecycleState'] is Map
        ? Map<String, dynamic>.from(summary['byLifecycleState'] as Map)
        : <String, dynamic>{};
    final byState = <String, int>{};
    byStateRaw.forEach((k, v) => byState[k.toString()] = _int(v));
    return OperatorCampaignLifecycleView(
      asOf: _date(json['asOf']),
      total: _int(summary['total']),
      active: _int(summary['active']),
      byState: byState,
      campaigns: (json['campaigns'] is List ? json['campaigns'] as List : const [])
          .whereType<Map>()
          .map((m) => OperatorCampaignRow.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
    );
  }
}

class OperatorCampaignRow {
  const OperatorCampaignRow({
    required this.campaignId,
    required this.campaignName,
    required this.clientName,
    required this.isPrimaryAutomation,
    required this.status,
    required this.lifecycleState,
    required this.lifecycleDetail,
    required this.shouldActivate,
    required this.discoveryLabel,
    required this.discoveryPaused,
    required this.continuityStatus,
    required this.blockerReason,
  });

  final String campaignId;
  final String campaignName;
  final String clientName;
  final bool isPrimaryAutomation;
  final String status;
  final String lifecycleState;
  final String lifecycleDetail;
  final bool shouldActivate;
  final String discoveryLabel;
  final bool discoveryPaused;
  final String? continuityStatus;
  final String? blockerReason;

  bool get isActive => lifecycleState == 'active';
  bool get isPaused => lifecycleState == 'paused';

  factory OperatorCampaignRow.fromJson(Map<String, dynamic> json) {
    final lifecycle = json['lifecycle'] is Map
        ? Map<String, dynamic>.from(json['lifecycle'] as Map)
        : <String, dynamic>{};
    final discovery = json['discovery'] is Map
        ? Map<String, dynamic>.from(json['discovery'] as Map)
        : <String, dynamic>{};
    final continuity = json['continuity'] is Map
        ? Map<String, dynamic>.from(json['continuity'] as Map)
        : <String, dynamic>{};
    return OperatorCampaignRow(
      campaignId: (json['campaignId'] ?? '').toString(),
      campaignName: (json['campaignName'] ?? 'Untitled campaign').toString(),
      clientName: (json['clientName'] ?? 'Unknown client').toString(),
      isPrimaryAutomation: json['isPrimaryAutomation'] == true,
      status: (json['status'] ?? '').toString(),
      lifecycleState: (lifecycle['state'] ?? 'unknown').toString(),
      lifecycleDetail: (lifecycle['detail'] ?? '').toString(),
      shouldActivate: lifecycle['shouldActivate'] == true,
      discoveryLabel: (discovery['label'] ?? '').toString(),
      discoveryPaused: discovery['paused'] == true,
      continuityStatus: continuity['status']?.toString(),
      blockerReason: json['blockerReason']?.toString(),
    );
  }
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

DateTime _date(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}
