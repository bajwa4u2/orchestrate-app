import '../../../core/commercial/client_capabilities.dart' show Entitlement;
import '../../../core/network/api_client.dart';

/// THE SERVER SIDE OF A NATIVE PURCHASE.
///
/// Four calls, and the order is the design. Nothing here decides anything: the
/// device asks what may be offered, says which organisation is about to buy,
/// reports what the store answered, and is told the result.
class StorePurchaseRepository {
  StorePurchaseRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// What this organisation may be offered, and under which product ids.
  ///
  /// The ids come from here rather than from a constant in the app, so a build
  /// from six months ago still asks the store for the right thing.
  Future<StoreOfferings> fetchOfferings() async {
    final json = await _apiClient.getJson(
      '/client/store/offerings',
      surface: ApiSurface.client,
    );
    return StoreOfferings.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Record which organisation is buying, before the store is opened.
  ///
  /// Refusals arrive here rather than after payment — a member without billing
  /// authority, or an organisation that already has service.
  Future<StoreIntent> beginPurchase({
    required String rail,
    required String productId,
  }) async {
    final json = await _apiClient.postJson(
      '/client/store/purchase-intent',
      body: {'rail': rail, 'productId': productId},
      surface: ApiSurface.client,
    );
    return StoreIntent.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Hand the store's answer to the server, which verifies it with the store.
  Future<StoreVerification> deliverPurchase({
    required String rail,
    required Object payload,
  }) async {
    final json = await _apiClient.postJson(
      '/client/store/purchase',
      body: {'rail': rail, 'payload': payload},
      surface: ApiSurface.client,
    );
    return StoreVerification.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Where this subscription is managed, which is wherever it was bought.
  Future<Map<String, dynamic>> fetchManagement() async {
    final json = await _apiClient.getJson(
      '/client/store/management',
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }
}

/// Whether one payment rail can actually complete a purchase right now.
///
/// Asked of the server, which asks the provider. A rail that cannot verify a
/// receipt must not be offered: the money moves at the store and the refusal
/// happens on our side, which is a charge followed by a no.
class RailAvailability {
  const RailAvailability({required this.live, required this.says});

  final bool live;

  /// What to tell a person when it is not. Written by the server, because the
  /// server is the side that knows why.
  final String? says;

  static RailAvailability fromJson(Map<String, dynamic>? json) =>
      RailAvailability(
        // Absent means an older server that does not answer this yet. Treated
        // as live so an existing client is not broken by a deploy order.
        live: json == null || json['live'] != false,
        says: json?['says'] as String?,
      );
}

class StoreOfferings {
  const StoreOfferings({
    required this.alreadyActive,
    this.rails = const {},
    required this.entitlement,
    required this.offerings,
  });

  /// True when this organisation already operates. Selling to it again is a
  /// refund conversation, so the surface refuses before the store opens.
  final bool alreadyActive;

  /// Keyed by rail: APPLE_APP_STORE, GOOGLE_PLAY.
  final Map<String, RailAvailability> rails;
  final Entitlement? entitlement;
  final List<StoreOffering> offerings;

  static StoreOfferings fromJson(Map<String, dynamic> j) => StoreOfferings(
        alreadyActive: j['alreadyActive'] == true,
        rails: {
          for (final entry in (j['rails'] as Map? ?? const {}).entries)
            '${entry.key}': RailAvailability.fromJson(
              entry.value is Map
                  ? Map<String, dynamic>.from(entry.value as Map)
                  : null,
            ),
        },
        entitlement: j['entitlement'] is Map
            ? Entitlement.fromJson(
                Map<String, dynamic>.from(j['entitlement'] as Map))
            : null,
        offerings: [
          for (final raw in (j['offerings'] as List? ?? const []))
            StoreOffering.fromJson(Map<String, dynamic>.from(raw as Map)),
        ],
      );
}

class StoreOffering {
  const StoreOffering({
    required this.code,
    required this.says,
    required this.productIds,
  });

  final String code;
  final String says;

  /// Keyed by rail: `APPLE_APP_STORE`, `GOOGLE_PLAY`.
  final Map<String, String> productIds;

  String? productIdFor(String rail) => productIds[rail];

  static StoreOffering fromJson(Map<String, dynamic> j) => StoreOffering(
        code: (j['code'] as String?) ?? '',
        says: (j['says'] as String?) ?? '',
        productIds: {
          for (final entry in (j['productIds'] as Map? ?? const {}).entries)
            entry.key.toString(): entry.value.toString(),
        },
      );
}

class StoreIntent {
  const StoreIntent({
    required this.ok,
    required this.intentKey,
    required this.code,
    required this.reason,
  });

  final bool ok;

  /// Carried into the store purchase and handed back on the transaction. The
  /// only deterministic way a store purchase can name a company.
  final String? intentKey;
  final String? code;
  final String? reason;

  static StoreIntent fromJson(Map<String, dynamic> j) => StoreIntent(
        ok: j['ok'] == true,
        intentKey: j['intentKey'] as String?,
        code: j['code'] as String?,
        reason: (j['reason'] ?? j['why']) as String?,
      );
}

class StoreVerification {
  const StoreVerification({
    required this.ok,
    required this.says,
    required this.code,
    required this.reason,
    required this.entitlement,
    required this.activatedNow,
  });

  final bool ok;
  final String? says;
  final String? code;
  final String? reason;
  final Entitlement? entitlement;

  /// True when this call is what activated it, rather than a replay.
  final bool activatedNow;

  static StoreVerification fromJson(Map<String, dynamic> j) => StoreVerification(
        ok: j['ok'] == true,
        says: j['says'] as String?,
        code: j['code'] as String?,
        reason: j['reason'] as String?,
        entitlement: j['entitlement'] is Map
            ? Entitlement.fromJson(
                Map<String, dynamic>.from(j['entitlement'] as Map))
            : null,
        activatedNow: j['activatedNow'] == true,
      );
}
