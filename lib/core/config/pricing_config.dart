class PricingPlanOption {
  const PricingPlanOption({
    required this.lane,
    required this.tier,
    required this.label,
    required this.amountCents,
    required this.displayPrice,
    required this.currencyCode,
    required this.interval,
    this.description,
    this.code,
    this.name,
    this.trialDays,
  });

  final String lane;
  final String tier;
  final String label;
  final int amountCents;
  final int displayPrice;
  final String currencyCode;
  final String interval;
  final String? description;
  final String? code;
  final String? name;
  final int? trialDays;

  String get priceLabel => '\$${displayPrice.toString()}';
  String get monthlyLabel => '$priceLabel / month';

  factory PricingPlanOption.fromMap(Map<String, dynamic> json) {
    return PricingPlanOption(
      lane: (json['lane'] ?? '').toString().trim().toLowerCase(),
      tier: _normalizeTier((json['tier'] ?? '').toString()),
      label: _readLabel(json),
      amountCents: _readInt(json['amountCents']),
      displayPrice: _readDisplayPrice(json),
      currencyCode: ((json['currencyCode'] ?? json['currency'] ?? 'USD').toString()).toUpperCase(),
      interval: (json['interval'] ?? 'month').toString().trim().toLowerCase(),
      description: json['description']?.toString() ?? json['summary']?.toString(),
      code: json['code']?.toString(),
      name: json['name']?.toString(),
      trialDays: json['trialDays'] == null ? null : _readInt(json['trialDays']),
    );
  }

  static String _readLabel(Map<String, dynamic> json) {
    final label = json['label']?.toString().trim();
    if (label != null && label.isNotEmpty) return label;

    final tier = _normalizeTier((json['tier'] ?? '').toString());
    switch (tier) {
      case 'precision':
        return 'Precision';
      case 'multi':
        return 'Multi-Market';
      default:
        return 'Focused';
    }
  }

  static int _readDisplayPrice(Map<String, dynamic> json) {
    if (json['displayPrice'] != null) {
      return _readInt(json['displayPrice']);
    }
    final amountCents = _readInt(json['amountCents']);
    return amountCents <= 0 ? 0 : amountCents ~/ 100;
  }
}

class PricingCatalog {
  const PricingCatalog({
    required this.trialDays,
    required this.opportunity,
    required this.revenue,
    required this.plans,
  });

  final int trialDays;
  final List<PricingPlanOption> opportunity;
  final List<PricingPlanOption> revenue;
  final List<PricingPlanOption> plans;

  List<PricingPlanOption> plansForLane(String lane) {
    final normalized = lane.trim().toLowerCase();
    if (normalized == 'revenue') return revenue;
    return opportunity;
  }

  PricingPlanOption? find(String lane, String tier) {
    final normalizedLane = lane.trim().toLowerCase();
    final normalizedTier = _normalizeTier(tier);
    return plans.firstWhereOrNull(
      (plan) => plan.lane == normalizedLane && plan.tier == normalizedTier,
    );
  }

  static PricingCatalog fromMap(Map<String, dynamic> json) {
    final grouped = Map<String, dynamic>.from(
      (json['grouped'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
    );

    final flatPlans = ((json['plans'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => PricingPlanOption.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    final opportunityPlans = _readGroupedPlans(grouped['opportunity'], lane: 'opportunity', fallback: flatPlans);
    final revenuePlans = _readGroupedPlans(grouped['revenue'], lane: 'revenue', fallback: flatPlans);

    final mergedPlans = <PricingPlanOption>[
      ...opportunityPlans,
      ...revenuePlans,
    ];

    return PricingCatalog(
      trialDays: _readInt(json['trialDays'] ?? 15),
      opportunity: _sortByTier(opportunityPlans),
      revenue: _sortByTier(revenuePlans),
      plans: _sortByLaneAndTier(mergedPlans.isNotEmpty ? mergedPlans : flatPlans),
    );
  }

  static List<PricingPlanOption> _readGroupedPlans(
    dynamic raw, {
    required String lane,
    required List<PricingPlanOption> fallback,
  }) {
    final items = ((raw as List?) ?? const [])
        .whereType<Map>()
        .map((item) => PricingPlanOption.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    if (items.isNotEmpty) return items;
    return fallback.where((plan) => plan.lane == lane).toList();
  }
}

class PricingConfig {
  const PricingConfig._();

  static PricingCatalog fromApi(Map<String, dynamic> json) => PricingCatalog.fromMap(json);

  static int getPrice(PricingCatalog catalog, String lane, String tier) {
    return catalog.find(lane, tier)?.displayPrice ?? 0;
  }

  static String getPriceLabel(PricingCatalog catalog, String lane, String tier) {
    final option = catalog.find(lane, tier);
    return option?.priceLabel ?? '\$0';
  }
}

extension _IterablePlanOptionX on Iterable<PricingPlanOption> {
  PricingPlanOption? firstWhereOrNull(bool Function(PricingPlanOption element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _normalizeTier(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == 'multi-market' || normalized == 'multi_market') return 'multi';
  return normalized;
}

List<PricingPlanOption> _sortByTier(List<PricingPlanOption> items) {
  const order = <String, int>{
    'focused': 0,
    'multi': 1,
    'precision': 2,
  };

  final list = List<PricingPlanOption>.from(items);
  list.sort((a, b) => (order[a.tier] ?? 99).compareTo(order[b.tier] ?? 99));
  return list;
}

List<PricingPlanOption> _sortByLaneAndTier(List<PricingPlanOption> items) {
  const laneOrder = <String, int>{
    'opportunity': 0,
    'revenue': 1,
  };
  const tierOrder = <String, int>{
    'focused': 0,
    'multi': 1,
    'precision': 2,
  };

  final list = List<PricingPlanOption>.from(items);
  list.sort((a, b) {
    final laneCompare = (laneOrder[a.lane] ?? 99).compareTo(laneOrder[b.lane] ?? 99);
    if (laneCompare != 0) return laneCompare;
    return (tierOrder[a.tier] ?? 99).compareTo(tierOrder[b.tier] ?? 99);
  });
  return list;
}
