import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/release/release_identity.dart';

/// TELLING US SOMETHING, FROM INSIDE THE PRODUCT.
///
/// Sends to the feedback authority that already exists — the same domain the
/// operator console triages from. Deliberately not a second feedback system:
/// a report that lands somewhere nobody reads is worse than no button, and two
/// places to look is how that happens.
///
/// WHAT TRAVELS WITH A REPORT, AND WHAT DOES NOT.
///
/// The build, the platform, the OS version and which surface they were on —
/// because "it did not work" is unanswerable without them, and a person should
/// not have to know their build number to be helped.
///
/// Not the workspace's data, not the message they were writing, not a screen
/// capture, not a log. Nothing is attached that the person did not type, and
/// the sheet says so before they send.
class ClientFeedbackRepository {
  ClientFeedbackRepository({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  /// Send one report. `surface` is where they were when they opened it.
  Future<({bool ok, String? reason})> send({
    required FeedbackIntent intent,
    required String message,
    required String surface,
  }) async {
    final trimmed = message.trim();
    if (trimmed.length < 4) {
      return (ok: false, reason: 'Tell us what happened, in your own words.');
    }

    final release = await ReleaseIdentity.load();
    try {
      await _api.postJson(
        '/feedback',
        surface: ApiSurface.client,
        body: {
          'intent': intent.wire,
          'message': trimmed,
          'product': 'ORCHESTRATE',
          'platform': release.platform,
          if (release.version.isNotEmpty) 'appVersion': release.version,
          if (release.build.isNotEmpty) 'buildNumber': release.build,
          if (_osVersion != null) 'osVersion': _osVersion,
          'surface': surface,
          'locale': _locale,
        },
      );
      return (ok: true, reason: null);
    } on ApiException catch (error) {
      // The server's own words where it wrote any; never the exception.
      final said = error.message.trim();
      return (
        ok: false,
        reason: said.isNotEmpty && said != 'Request failed'
            ? said
            : 'We could not send that just now. Nothing was lost — try again.',
      );
    } catch (_) {
      return (
        ok: false,
        reason: 'We could not reach the server. Nothing was lost — try again.',
      );
    }
  }

  /// The operating system, where the platform will tell us. Never on web,
  /// where the equivalent is a user-agent string and is not ours to collect.
  static String? get _osVersion {
    if (kIsWeb) return null;
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return null;
    }
  }

  static String get _locale {
    try {
      return PlatformDispatcher.instance.locale.toLanguageTag();
    } catch (_) {
      return 'und';
    }
  }
}

/// The three the domain already recognises: PROBLEM, IDEA, FEEDBACK. Named
/// here for what a person is doing, not for the enum value they never see.
enum FeedbackIntent {
  problem('PROBLEM', 'Something is wrong'),
  idea('IDEA', 'Something could be better'),
  other('FEEDBACK', 'Something else');

  const FeedbackIntent(this.wire, this.label);

  final String wire;
  final String label;
}
