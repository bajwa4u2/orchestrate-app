import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/network/api_client.dart';

/// What a person can be telling us.
///
/// Three, and deliberately only three. A longer list makes someone classify
/// their own experience into our engineering categories before they are
/// allowed to say anything, which taxes exactly the people most worth hearing.
enum FeedbackIntent {
  problem('PROBLEM', 'Report a problem', 'Something is not working.'),
  feedback('FEEDBACK', 'Share feedback', 'How Orchestrate feels to use.'),
  idea('IDEA', 'Suggest an idea', 'Something Orchestrate does not do yet.');

  const FeedbackIntent(this.wire, this.label, this.hint);

  final String wire;
  final String label;
  final String hint;
}

enum FeedbackState {
  received('RECEIVED', 'Received'),
  reviewed('REVIEWED', 'Read'),
  actioned('ACTIONED', 'Acted on'),
  closed('CLOSED', 'Closed');

  const FeedbackState(this.wire, this.label);

  final String wire;
  final String label;

  /// A backend one version ahead must not blank the screen of a client that
  /// has not updated yet.
  static FeedbackState fromWire(String? raw) => values.firstWhere(
        (v) => v.wire == raw,
        orElse: () => FeedbackState.received,
      );
}

class FeedbackRecord {
  const FeedbackRecord({
    required this.id,
    required this.ref,
    required this.intent,
    required this.state,
    required this.message,
    this.outcome,
  });

  final String id;
  final String ref;
  final FeedbackIntent intent;
  final FeedbackState state;
  final String message;

  /// What was done. The only operator-written field a person sees — the
  /// internal note is never sent to this client.
  final String? outcome;

  factory FeedbackRecord.fromJson(Map<String, dynamic> json) => FeedbackRecord(
        id: (json['id'] ?? '').toString(),
        ref: (json['ref'] ?? '').toString(),
        intent: FeedbackIntent.values.firstWhere(
          (v) => v.wire == json['intent'],
          orElse: () => FeedbackIntent.feedback,
        ),
        state: FeedbackState.fromWire(json['state']?.toString()),
        message: (json['message'] ?? '').toString(),
        outcome: ((json['outcome'] ?? '') as String).trim().isEmpty
            ? null
            : (json['outcome'] as String).trim(),
      );
}

/// THE DIAGNOSTIC CONTEXT, AND NOTHING BESIDE IT.
///
/// Everything here is about the SOFTWARE. Nothing is about what the person was
/// doing in it. A build number tells us where to look; a campaign id tells us
/// which client they were working on.
class FeedbackContext {
  const FeedbackContext({
    required this.product,
    required this.platform,
    this.appVersion,
    this.buildNumber,
    this.osVersion,
    this.surface,
    this.locale,
  });

  final String product;
  final String platform;
  final String? appVersion;
  final String? buildNumber;
  final String? osVersion;
  final String? surface;
  final String? locale;

  Map<String, dynamic> toJson() => {
        'product': product,
        'platform': platform,
        if (appVersion != null) 'appVersion': appVersion,
        if (buildNumber != null) 'buildNumber': buildNumber,
        if (osVersion != null) 'osVersion': osVersion,
        if (surface != null) 'surface': surface,
        if (locale != null) 'locale': locale,
      };

  static Future<FeedbackContext> resolve({
    String? surface,
    String? locale,
  }) async {
    String? version;
    String? build;
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version.trim();
      build = info.buildNumber.trim();
    } catch (_) {
      // Never block someone with something to say on telemetry.
    }
    return FeedbackContext(
      product: 'orchestrate',
      platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      appVersion: (version?.isEmpty ?? true) ? null : version,
      buildNumber: (build?.isEmpty ?? true) ? null : build,
      // The OS version only. Never a device identifier or a model that
      // narrows to one person.
      osVersion: kIsWeb ? null : _osVersion(),
      surface: surface,
      locale: locale,
    );
  }

  static String? _osVersion() {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return null;
    }
  }
}

class ProductFeedbackRepository {
  ProductFeedbackRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<FeedbackRecord> submit({
    required FeedbackIntent intent,
    required String message,
    required FeedbackContext context,
  }) async {
    final json = await _apiClient.postJson(
      '/feedback',
      body: {
        'intent': intent.wire,
        'message': message,
        ...context.toJson(),
      },
      surface: ApiSurface.operator,
    );
    return FeedbackRecord.fromJson(_unwrap(json));
  }

  Future<List<FeedbackRecord>> listMine() async {
    final json = await _apiClient.getJson(
      '/feedback/mine',
      surface: ApiSurface.operator,
    );
    final list = json is Map ? (json['data'] ?? json) : json;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => FeedbackRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// The operator's queue.
  Future<List<Map<String, dynamic>>> queue({String? state}) async {
    final json = await _apiClient.getJson(
      '/operator/feedback',
      query: state == null || state.isEmpty ? null : {'state': state},
      surface: ApiSurface.operator,
    );
    final list = json is Map ? (json['data'] ?? json) : json;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  Future<void> triage({
    required String id,
    required String state,
    String? outcome,
    String? operatorNote,
    String? releaseRef,
  }) async {
    await _apiClient.postJson(
      '/operator/feedback/$id/triage',
      body: {
        'state': state,
        if (outcome != null && outcome.trim().isNotEmpty) 'outcome': outcome.trim(),
        if (operatorNote != null && operatorNote.trim().isNotEmpty)
          'operatorNote': operatorNote.trim(),
        if (releaseRef != null && releaseRef.trim().isNotEmpty)
          'releaseRef': releaseRef.trim(),
      },
      surface: ApiSurface.operator,
    );
  }

  Map<String, dynamic> _unwrap(dynamic json) {
    if (json is! Map) return <String, dynamic>{};
    final data = json['data'];
    return Map<String, dynamic>.from(data is Map ? data : json);
  }
}
