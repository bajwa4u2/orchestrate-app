import 'package:flutter/foundation.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';

/// THE LAST ANSWER A SCREEN WAS GIVEN.
///
/// A screen's `State` is destroyed the moment a person navigates away from it,
/// so a screen that fetches in `initState` starts every visit with nothing and
/// paints a spinner over the whole content area — on Credentials, Evidence,
/// Artifacts, Branding, People, Billing and the rest, every single time, even
/// when the answer had not changed since ten seconds ago. That flash is what
/// the workspace looked like from the outside: a blink between every screen.
///
/// The three destinations in the rail already avoided it by holding their
/// answers in a listener that outlives the screen. This is the same idea for
/// the screens that do not warrant one of their own: remember what the server
/// last said, paint it immediately on return, and refresh underneath it.
///
/// WHAT THIS IS NOT. It is not a cache with a policy. There is no expiry and
/// no invalidation, because it never decides anything — every screen still
/// asks the server on every visit, and what it remembers is only what to show
/// while that answer is on its way. Stale for a few hundred milliseconds, and
/// then correct.
///
/// It is keyed to the business, and forgets everything the moment that
/// changes. A remembered answer belonging to another organisation is the one
/// failure this must never have, so the check is on every read and every
/// write rather than on a listener that could be missed.
class ScreenMemory {
  const ScreenMemory._();

  static final Map<String, Object?> _answers = <String, Object?>{};
  static String? _forClientId;

  /// What this screen was last told, or null if it has not been told anything
  /// — or was told it while a different business was signed in.
  static T? recall<T>(String key) {
    if (!_belongsToCurrentClient()) return null;
    final value = _answers[key];
    return value is T ? value : null;
  }

  static void remember(String key, Object? value) {
    _belongsToCurrentClient();
    _answers[key] = value;
  }

  /// Remember whatever this future resolves to, and hand the future straight
  /// back. Written this way so a screen's load site changes by one word.
  static Future<T> keep<T>(String key, Future<T> answer) {
    return answer.then((value) {
      remember(key, value);
      return value;
    });
  }

  /// On sign-out. Also happens automatically on the next read or write once
  /// the session has changed, but doing it at the boundary means nothing is
  /// held while nobody is signed in.
  static void forget() {
    _answers.clear();
    _forClientId = null;
  }

  static bool _belongsToCurrentClient() {
    final clientId = AuthSessionController.instance.clientId;
    if (_forClientId == clientId) return true;
    _answers.clear();
    _forClientId = clientId;
    return false;
  }

  @visibleForTesting
  static int get remembered => _answers.length;
}
