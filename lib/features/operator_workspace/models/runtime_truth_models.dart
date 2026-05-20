// Operator-side typed models for the canonical runtime-truth faculty.
// Mirror /operator/runtime-truth/canonical, /green-path, /budgets.
// Every field is a real backend read — no fabricated metrics.

class RuntimeBudgetSnapshot {
  const RuntimeBudgetSnapshot({
    required this.asOf,
    required this.budgets,
    required this.stabilization,
    required this.economy,
  });

  final DateTime asOf;
  final List<ActionBudgetEntry> budgets;
  final Map<String, dynamic> stabilization;
  final BudgetEconomy economy;

  factory RuntimeBudgetSnapshot.fromJson(Map<String, dynamic> json) {
    return RuntimeBudgetSnapshot(
      asOf: _date(json['asOf']),
      budgets: _list(json['budgets'])
          .whereType<Map>()
          .map((m) => ActionBudgetEntry.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
      stabilization: _map(json['stabilization']),
      economy: BudgetEconomy.fromJson(_map(json['economy'])),
    );
  }
}

class ActionBudgetEntry {
  const ActionBudgetEntry({
    required this.category,
    required this.hourCount,
    required this.dayCount,
    required this.hourCap,
    required this.dayCap,
    required this.hourExceeded,
    required this.dayExceeded,
  });

  final String category;
  final int hourCount;
  final int dayCount;
  final int hourCap;
  final int dayCap;
  final bool hourExceeded;
  final bool dayExceeded;

  double get hourRatio => hourCap == 0 ? 0 : hourCount / hourCap;

  factory ActionBudgetEntry.fromJson(Map<String, dynamic> json) {
    return ActionBudgetEntry(
      category: (json['category'] ?? 'OTHER').toString(),
      hourCount: _int(json['hourCount']),
      dayCount: _int(json['dayCount']),
      hourCap: _int(json['hourCap']),
      dayCap: _int(json['dayCap']),
      hourExceeded: json['hourExceeded'] == true,
      dayExceeded: json['dayExceeded'] == true,
    );
  }
}

class BudgetEconomy {
  const BudgetEconomy({
    required this.totalDecisions,
    required this.aiCalls,
    required this.deterministicBypasses,
    required this.budgetSafeMode,
    required this.deterministicBypassRate,
  });

  final int totalDecisions;
  final int aiCalls;
  final int deterministicBypasses;
  final int budgetSafeMode;
  final double deterministicBypassRate;

  factory BudgetEconomy.fromJson(Map<String, dynamic> json) {
    return BudgetEconomy(
      totalDecisions: _int(json['totalDecisions']),
      aiCalls: _int(json['aiCalls']),
      deterministicBypasses: _int(json['deterministicBypasses']),
      budgetSafeMode: _int(json['budgetSafeMode']),
      deterministicBypassRate: _double(json['deterministicBypassRate']),
    );
  }
}

/// One unsatisfied gate in the canonical blocker chain.
class CanonicalBlockerView {
  const CanonicalBlockerView({
    required this.code,
    required this.layer,
    required this.message,
    required this.ownedBy,
  });

  final String code;
  final String layer;
  final String message;
  final String ownedBy;

  factory CanonicalBlockerView.fromJson(Map<String, dynamic> json) {
    return CanonicalBlockerView(
      code: (json['code'] ?? '').toString(),
      layer: (json['layer'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      ownedBy: (json['ownedBy'] ?? 'orchestrate').toString(),
    );
  }
}

/// The single canonical runtime-truth object.
class CanonicalTruthView {
  const CanonicalTruthView({
    required this.generatedAt,
    required this.fingerprint,
    required this.billingActive,
    required this.mailboxAuthorized,
    required this.providerHealthy,
    required this.oauthValid,
    required this.domainVerified,
    required this.spf,
    required this.dkim,
    required this.dmarc,
    required this.governanceHold,
    required this.continuityWindowOpen,
    required this.continuityHeld,
    required this.pacingAvailable,
    required this.sendingAllowed,
    required this.campaignExecutable,
    required this.dataComplete,
    required this.blockerChain,
  });

  final DateTime generatedAt;
  final String fingerprint;
  final bool billingActive;
  final bool mailboxAuthorized;
  final bool providerHealthy;
  final bool oauthValid;
  final bool domainVerified;
  final String spf;
  final String dkim;
  final String dmarc;
  final String? governanceHold;
  final bool continuityWindowOpen;
  final bool continuityHeld;
  final bool pacingAvailable;
  final bool sendingAllowed;
  final bool campaignExecutable;
  final bool dataComplete;
  final List<CanonicalBlockerView> blockerChain;

  factory CanonicalTruthView.fromJson(Map<String, dynamic> json) {
    return CanonicalTruthView(
      generatedAt: _date(json['generatedAt']),
      fingerprint: (json['fingerprint'] ?? '').toString(),
      billingActive: json['billingActive'] == true,
      mailboxAuthorized: json['mailboxAuthorized'] == true,
      providerHealthy: json['providerHealthy'] == true,
      oauthValid: json['oauthValid'] == true,
      domainVerified: json['domainVerified'] == true,
      spf: (json['spf'] ?? 'unknown').toString(),
      dkim: (json['dkim'] ?? 'unknown').toString(),
      dmarc: (json['dmarc'] ?? 'unknown').toString(),
      governanceHold: json['governanceHold']?.toString(),
      continuityWindowOpen: json['continuityWindowOpen'] == true,
      continuityHeld: json['continuityHeld'] == true,
      pacingAvailable: json['pacingAvailable'] == true,
      sendingAllowed: json['sendingAllowed'] == true,
      campaignExecutable: json['campaignExecutable'] == true,
      dataComplete: json['dataComplete'] == true,
      blockerChain: _list(json['blockerChain'])
          .whereType<Map>()
          .map((m) =>
              CanonicalBlockerView.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
    );
  }
}

/// Deterministic green-path verdict for an action.
class GreenPathView {
  const GreenPathView({
    required this.action,
    required this.greenPath,
    required this.reason,
    required this.blockers,
    required this.truth,
  });

  final String action;
  final bool greenPath;
  final String reason;
  final List<CanonicalBlockerView> blockers;
  final CanonicalTruthView truth;

  factory GreenPathView.fromJson(Map<String, dynamic> json) {
    return GreenPathView(
      action: (json['action'] ?? 'SOURCE_LEADS').toString(),
      greenPath: json['greenPath'] == true,
      reason: (json['reason'] ?? '').toString(),
      blockers: _list(json['blockers'])
          .whereType<Map>()
          .map((m) =>
              CanonicalBlockerView.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
      truth: CanonicalTruthView.fromJson(_map(json['truth'])),
    );
  }
}

// helpers
Map<String, dynamic> _map(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, vv) => MapEntry('$k', vv));
  return <String, dynamic>{};
}

List<dynamic> _list(dynamic v) => v is List ? v : const <dynamic>[];

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _double(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

DateTime _date(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}
