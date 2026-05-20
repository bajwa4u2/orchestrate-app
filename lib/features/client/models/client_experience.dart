// Client-side model for the client experience surface.
// Mirrors GET /client/experience — the single client-safe projection
// of operational truth. Outcome-oriented business semantics only;
// no runtime / diagnostic vocabulary ever reaches this model.

class ClientExperience {
  const ClientExperience({
    required this.momentum,
    required this.tone,
    required this.headline,
    required this.narrative,
    required this.ownershipLine,
    required this.confidenceSignals,
    required this.growth,
    required this.clientAction,
  });

  /// One of: action_needed | account_paused | activating |
  /// building_pipeline | outreach_active | optimizing.
  final String momentum;

  /// One of: positive | progressing | attention.
  final String tone;
  final String headline;
  final String narrative;
  final String ownershipLine;
  final List<ClientConfidenceSignal> confidenceSignals;
  final ClientGrowth growth;

  /// Present ONLY when the client genuinely owns the next step.
  final ClientExperienceAction? clientAction;

  factory ClientExperience.fromJson(Map<String, dynamic> json) {
    final actionRaw = json['clientAction'];
    return ClientExperience(
      momentum: (json['momentum'] ?? 'activating').toString(),
      tone: (json['tone'] ?? 'progressing').toString(),
      headline: (json['headline'] ?? '').toString(),
      narrative: (json['narrative'] ?? '').toString(),
      ownershipLine: (json['ownershipLine'] ?? '').toString(),
      confidenceSignals: (json['confidenceSignals'] as List? ?? const [])
          .whereType<Map>()
          .map((m) =>
              ClientConfidenceSignal.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
      growth: ClientGrowth.fromJson(
        json['growth'] is Map
            ? Map<String, dynamic>.from(json['growth'] as Map)
            : const <String, dynamic>{},
      ),
      clientAction: actionRaw is Map
          ? ClientExperienceAction.fromJson(
              Map<String, dynamic>.from(actionRaw))
          : null,
    );
  }
}

class ClientConfidenceSignal {
  const ClientConfidenceSignal({
    required this.key,
    required this.label,
    required this.state,
    required this.detail,
  });

  final String key;
  final String label;

  /// One of: active | progressing | attention.
  final String state;
  final String detail;

  factory ClientConfidenceSignal.fromJson(Map<String, dynamic> json) {
    return ClientConfidenceSignal(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      state: (json['state'] ?? 'progressing').toString(),
      detail: (json['detail'] ?? '').toString(),
    );
  }
}

class ClientGrowth {
  const ClientGrowth({
    required this.opportunitiesIdentified,
    required this.opportunitiesInMarket,
    required this.conversationsActive,
    required this.meetingsCoordinated,
  });

  final int opportunitiesIdentified;
  final int opportunitiesInMarket;
  final int conversationsActive;
  final int meetingsCoordinated;

  factory ClientGrowth.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('${v ?? ''}') ?? 0;
    }

    return ClientGrowth(
      opportunitiesIdentified: asInt(json['opportunitiesIdentified']),
      opportunitiesInMarket: asInt(json['opportunitiesInMarket']),
      conversationsActive: asInt(json['conversationsActive']),
      meetingsCoordinated: asInt(json['meetingsCoordinated']),
    );
  }
}

class ClientExperienceAction {
  const ClientExperienceAction({
    required this.code,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.route,
  });

  final String code;
  final String title;
  final String message;
  final String ctaLabel;
  final String route;

  factory ClientExperienceAction.fromJson(Map<String, dynamic> json) {
    return ClientExperienceAction(
      code: (json['code'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      ctaLabel: (json['ctaLabel'] ?? 'Continue').toString(),
      route: (json['route'] ?? '/client/overview').toString(),
    );
  }
}
