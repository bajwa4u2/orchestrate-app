import 'package:flutter/foundation.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/data/repositories/auth_repository.dart';

/// A RESTORED SESSION IS BROUGHT UP TO DATE ONCE (4 Oct 2026).
///
/// The app kept the session it was given at sign-in and never asked again, so
/// the business's own name (sent since 4 Oct) never replaced the
/// organisation's "Orchestrate (Aura Platform LLC)" in the sidebar until the
/// next sign-in. Once per start, a signed-in client session is refreshed from
/// /auth/me. A failure changes nothing: the saved session stays as it was and
/// nobody is signed out by a refresh.
Future<void> refreshRestoredSession({AuthRepository? repository}) async {
  final session = AuthSessionController.instance;
  if (session.token.isEmpty || session.surface != 'client') return;
  try {
    final payload = await (repository ?? AuthRepository()).currentSession();
    await session.applyAuthResponse(payload);
  } catch (error) {
    debugPrint('[session] refresh skipped: $error');
  }
}
