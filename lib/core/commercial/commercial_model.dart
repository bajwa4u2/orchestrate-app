/// WHAT ORCHESTRATE COSTS, AS THE SERVER STATES IT.
///
/// One paid product, billed monthly or annually, and an account that costs
/// nothing. That is the whole model, and this file is deliberately too small to
/// express anything else.
///
/// It replaces a catalog of six packages arranged as two lanes by three tiers,
/// with a trial length and a ranking function. That shape was not merely
/// unused: while it existed, every screen that touched pricing had to decide
/// which package was better than which, and a customer had to be sold a
/// position on a ladder before they could buy anything. There is no ladder now,
/// so there is nothing to rank.
///
/// Nothing here is written by the client. The prices, the sentences and whether
/// anything can be bought at all come from the commercial projection, so the
/// public site and the API cannot come to disagree about what the business
/// model is.
library;

/// One cadence of the one paid product.
///
/// `entitlement` is the same value on every offer, and that repetition is not
/// redundancy — it is the thing a reader checks to see that the cheaper offer
/// is not a smaller product.
class CommercialOffer {
  const CommercialOffer({
    required this.period,
    required this.entitlement,
    required this.amountUsdCents,
    required this.says,
  });

  /// `MONTHLY` or `ANNUAL`. A billing cadence, never a capability level.
  final String period;

  /// `ORCHESTRATE_PLATFORM`, on both.
  final String entitlement;

  /// The published US list price.
  ///
  /// Correct for this page, which is our own storefront. It is NOT what a
  /// phone shows: Apple and Google return a localized price for the person's
  /// own storefront, and that string is the truth on a device.
  final int amountUsdCents;

  final String says;

  bool get isAnnual => period == 'ANNUAL';

  /// `$29.99`. Two decimals always — `$29.9` reads as a rendering fault, and a
  /// price a customer distrusts is worse than one they dislike.
  String get priceLabel => '\$${(amountUsdCents / 100).toStringAsFixed(2)}';

  static CommercialOffer fromJson(Map<String, dynamic> j) => CommercialOffer(
        period: (j['period'] as String?) ?? '',
        entitlement: (j['entitlement'] as String?) ?? '',
        amountUsdCents: _readInt(j['amountUsdCents']),
        says: (j['says'] as String?) ?? '',
      );
}

/// What an account costs before anyone pays: nothing.
///
/// Carried apart from the paid offers on purpose. Modelled as a plan with a
/// zero in it, free entry sorts to the bottom of a price list and eventually
/// gets described as the thing a subscription lapses into — and somebody who
/// has simply not bought anything is told they have lost something.
class FreeEntry {
  const FreeEntry({required this.amountUsdCents, required this.says});

  final int amountUsdCents;
  final String says;

  static const FreeEntry unknown = FreeEntry(amountUsdCents: 0, says: '');

  static FreeEntry fromJson(Map<String, dynamic>? j) => j == null
      ? unknown
      : FreeEntry(
          amountUsdCents: _readInt(j['amountUsdCents']),
          says: (j['says'] as String?) ?? '',
        );
}

/// WHETHER ANYTHING CAN BE BOUGHT RIGHT NOW, AND WHAT TO SAY IF NOT.
///
/// Served by the same commercial projection every rail reads, so no screen
/// decides this for itself. The workspace previously did, and offered
/// "Activate a plan" leading to a checkout the server had already frozen shut.
class CommercialActivation {
  const CommercialActivation({
    required this.open,
    required this.says,
    required this.resolution,
  });

  final bool open;

  /// Why, in the customer's terms. Never a code, never a provider status.
  final String says;

  /// What they can do instead. A refusal with no path is a dead end.
  final String resolution;

  /// A server that predates the field is assumed to be selling — the same
  /// direction the store rails take, so an older deployment does not silently
  /// shut commerce off for everyone.
  static CommercialActivation fromJson(dynamic raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    if (map.isEmpty) {
      return const CommercialActivation(open: true, says: '', resolution: '');
    }
    return CommercialActivation(
      open: map['open'] != false,
      says: (map['says'] ?? '').toString().trim(),
      resolution: (map['resolution'] ?? '').toString().trim(),
    );
  }
}

/// One part of what a business is paying for, in the customer's terms.
class CommercialDimension {
  const CommercialDimension({required this.dimension, required this.means});

  final String dimension;
  final String means;

  static CommercialDimension fromJson(Map<String, dynamic> j) =>
      CommercialDimension(
        dimension: (j['dimension'] as String?) ?? '',
        means: (j['means'] as String?) ?? '',
      );
}

class CommercialModel {
  const CommercialModel({
    required this.says,
    required this.dimensions,
    required this.pricingSays,
    required this.free,
    required this.offers,
    required this.cadenceMeans,
    required this.activation,
    required this.startSays,
    required this.startAction,
  });

  final String says;
  final List<CommercialDimension> dimensions;
  final String pricingSays;
  final FreeEntry free;

  /// Monthly first. The smaller commitment is the easier decision, and the
  /// annual price beside it then reads as a saving rather than a bill.
  final List<CommercialOffer> offers;

  final String cadenceMeans;
  final CommercialActivation activation;
  final String startSays;
  final String startAction;

  CommercialOffer? offerFor(String period) {
    for (final offer in offers) {
      if (offer.period == period) return offer;
    }
    return null;
  }

  static CommercialModel fromJson(Map<String, dynamic> j) {
    final pricing = j['pricing'] is Map
        ? Map<String, dynamic>.from(j['pricing'] as Map)
        : const <String, dynamic>{};
    final start = j['start'] is Map
        ? Map<String, dynamic>.from(j['start'] as Map)
        : const <String, dynamic>{};

    final offers = [
      for (final raw in (pricing['plans'] as List? ?? const []))
        CommercialOffer.fromJson(Map<String, dynamic>.from(raw as Map)),
    ]..sort((a, b) => a.isAnnual == b.isAnnual ? 0 : (a.isAnnual ? 1 : -1));

    return CommercialModel(
      says: (j['says'] as String?) ?? '',
      dimensions: [
        for (final raw in (j['dimensions'] as List? ?? const []))
          CommercialDimension.fromJson(Map<String, dynamic>.from(raw as Map)),
      ],
      pricingSays: (pricing['says'] as String?) ?? '',
      free: FreeEntry.fromJson(pricing['free'] is Map
          ? Map<String, dynamic>.from(pricing['free'] as Map)
          : null),
      offers: offers,
      cadenceMeans: (pricing['cadenceMeans'] as String?) ?? '',
      activation: CommercialActivation.fromJson(j['activation']),
      startSays: (start['says'] as String?) ?? '',
      startAction: (start['action'] as String?) ?? '/auth/register',
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
