/// WHAT IS STILL REQUIRED, IN ONE READING.
///
/// `/client/execution-eligibility` returns every standing condition as a
/// `ResolvableBlocker`: `{code, label, detail, owner, resolutionRoute,
/// resolutionCta}`. The backend already knows, per blocker type, what it is
/// called, what it means and where it is resolved.
///
/// Surfaces used to read this themselves, differently. Today read it
/// correctly. Business read a different endpoint whose raw blockers carry no
/// title, so every condition there was called "Sending is held" and every row
/// opened mailbox settings, including the plan. This is the one reader, so
/// the name, the explanation and the destination of a condition are the same
/// wherever it appears.
class StandingCondition {
  const StandingCondition({
    required this.code,
    required this.title,
    this.detail,
    this.route,
    this.cta,
  });

  final String code;
  final String title;
  final String? detail;

  /// An in-app route, or null when the backend named none. A condition with
  /// no destination stays unclickable rather than guessing at one.
  final String? route;
  final String? cta;
}

/// Codes that describe the representation grant itself. A surface reporting
/// what the grant left outstanding excludes these.
const representationConditionCodes = <String>{
  'AUTHORIZATION_MISSING',
  'REPRESENTATION_AUTH_MISSING',
  'REPRESENTATION_AUTH_REQUIRED',
};

List<StandingCondition> standingConditionsFrom(Object? eligibility) {
  if (eligibility is! Map) return const [];
  final blockers = eligibility['blockers'];
  if (blockers is! List) return const [];
  final out = <StandingCondition>[];
  for (final b in blockers.whereType<Map>()) {
    // `reason` and `message` are still accepted so an older payload, or the
    // degraded envelope the evaluator emits when it catches its own error,
    // still renders.
    final detail = _text(b['detail']) ?? _text(b['reason']) ?? _text(b['message']);
    final label = _text(b['label']) ?? _text(b['title']);
    // Nothing to say in either field: a blocker that cannot describe itself
    // carries no information a person can act on.
    if (detail == null && label == null) continue;
    final rawRoute = _text(b['resolutionRoute']);
    out.add(StandingCondition(
      code: _text(b['code']) ?? '',
      // A blocker the backend did not name is still named for what it is — a
      // condition — not guessed at as a sending problem.
      title: label ?? 'Something still needs resolving',
      // AN INTERNAL ERROR IS NOT AN ATTENTION ITEM. When the backend hits its
      // own defect the detail is a stack trace; the row still appears, and
      // says honestly that it needs us rather than the business.
      detail: detail == null
          ? null
          : looksInternal(detail)
              ? 'Held by a fault on our side. Nothing is wrong with your '
                  'setup, and it needs us rather than you.'
              : detail,
      route: rawRoute != null && rawRoute.startsWith('/') ? rawRoute : null,
      cta: _text(b['resolutionCta']),
    ));
  }
  return out;
}

/// Does this read like our failure rather than the client's situation?
bool looksInternal(String reason) {
  const fingerprints = [
    // '.js:' matters most. Production runs COMPILED JavaScript, so a real
    // backend stack trace reads
    // "/app/dist/src/workers/first_send/first-send.worker.service.js:268".
    'invocation in', 'prisma.', 'at Object.', '.ts:', '.js:', '.dart:',
    'Traceback', 'stack', 'Unhandled', 'internal error',
    'Exception:', 'Exception at', 'BadRequestException',
  ];
  final lower = reason.toLowerCase();
  return reason.contains('\n') ||
      reason.length > 400 ||
      fingerprints.any((f) => lower.contains(f.toLowerCase()));
}

String? _text(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty || s == 'null' ? null : s;
}
