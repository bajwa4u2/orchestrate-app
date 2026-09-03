/// WHERE THE PERSON WAS TRYING TO GO.
///
/// The router used to redirect an unauthenticated visitor to `/auth/login`
/// carrying only `plan`, `tier` and `trial`. The destination was discarded, so
/// every deep link into the workspace died at the auth boundary — you signed
/// in and arrived somewhere generic, with no trace of why you had come.
///
/// That was invisible while nothing linked inward. It stopped being invisible
/// the moment an invitation email pointed someone at a specific page and asked
/// them to do a specific thing.
///
/// This is deliberately a shared mechanism rather than an authority-only fix.
/// Verification links, shared relationships, invoices and anything else worth
/// sending someone all have the same shape: arrive → prove who you are →
/// continue what you came for.
library;

/// The query parameter carrying the original destination.
const String kReturnToParam = 'returnTo';

/// Attach a destination to an auth route.
///
/// Paths only. A full URL here would let an outside page bounce someone
/// through our sign-in to a site of its choosing, so anything that is not a
/// simple in-app path is dropped rather than sanitised into something
/// plausible.
String withReturnTo(String authPath, String? destination) {
  final safe = _safeDestination(destination);
  if (safe == null) return authPath;
  final joiner = authPath.contains('?') ? '&' : '?';
  return '$authPath$joiner$kReturnToParam=${Uri.encodeComponent(safe)}';
}

/// Read a destination back, if it is one we are willing to honour.
String? readReturnTo(Map<String, String> queryParameters) =>
    _safeDestination(queryParameters[kReturnToParam]);

/// Carry a destination across an intermediate redirect.
///
/// Sign-in is not always one hop: an unverified person goes to verification
/// first. The destination has to survive each hop or the last one lands them
/// nowhere in particular.
String carryReturnTo(String nextPath, Map<String, String> current) =>
    withReturnTo(nextPath, current[kReturnToParam]);

/// Only in-app absolute paths.
///
/// Rejects: anything not starting with a single `/`, protocol-relative `//`
/// (a host in disguise), any scheme, and control characters.
String? _safeDestination(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (!value.startsWith('/')) return null;
  if (value.startsWith('//')) return null;
  if (value.contains(':')) return null;
  if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) return null;

  // Sending someone back to an auth route after they authenticate is a loop.
  const authRoots = ['/auth', '/client/login', '/ops/login', '/ops-login'];
  if (authRoots.any((r) => value == r || value.startsWith('$r/'))) return null;

  return value;
}
