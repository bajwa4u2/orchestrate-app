/// THE FOUR THINGS ONLY THE OWNER CAN DO (DD-26, Today).
///
/// Orchestrate can do everything else itself. These four it cannot: choose a
/// plan, give permission to write in the business's name, connect the email
/// notes go out from, and make that email's domain trusted. Today shows each
/// one that is still open as a card, with one line and one button that opens
/// the exact setup step.
///
/// Whether a step is done is read from `/client/execution-eligibility`'s
/// `chain`, the server's own layer-by-layer reading. Nothing is decided here
/// beyond which layer answers which step.
class OwnerStep {
  const OwnerStep({
    required this.key,
    required this.title,
    required this.line,
    required this.cta,
    required this.route,
    required this.done,
  });

  final String key;
  final String title;
  final String line;
  final String cta;
  final String route;
  final bool done;
}

/// The four steps in the order an owner meets them, or an empty list when the
/// server did not send its chain (unknown is never shown as open or done).
List<OwnerStep> ownerStepsFrom(Object? eligibility) {
  if (eligibility is! Map) return const [];
  final chain = eligibility['chain'];
  if (chain is! List) return const [];
  final ready = <String>{
    for (final layer in chain.whereType<Map>())
      if (layer['state'] == 'ready') '${layer['key']}',
  };
  return [
    OwnerStep(
      key: 'plan',
      title: 'Choose your plan',
      line: 'Finding businesses is free. Sending starts the day you choose.',
      cta: 'Choose a plan',
      route: '/client/setup?step=plan',
      done: ready.contains('subscription'),
    ),
    OwnerStep(
      key: 'permission',
      title: 'Give your permission',
      line: 'Orchestrate writes in your name only after you say yes.',
      cta: 'Give permission',
      route: '/client/setup?step=permission',
      done: ready.contains('representation'),
    ),
    OwnerStep(
      key: 'email',
      title: 'Connect your email',
      line: 'Notes go out from your address. Replies land in your inbox.',
      cta: 'Connect email',
      route: '/client/setup?step=email',
      done: ready.contains('sending_transport'),
    ),
    OwnerStep(
      key: 'domain',
      title: 'Make your domain trusted',
      line: 'So your notes reach inboxes, not spam.',
      cta: 'Check your domain',
      route: '/client/setup?step=email',
      done: ready.contains('trust'),
    ),
  ];
}

/// Blocker codes the four steps already speak for, so Today does not show
/// the same thing twice in the server's longer words.
/// (A plan that lapsed, a mailbox that lost its connection or a fault are not
/// here: those are not first-time steps and keep their own card.)
const ownerStepBlockerCodes = <String>{
  'PLAN_ACTIVATION_REQUIRED',
  'AUTHORIZATION_MISSING',
  'REPRESENTATION_AUTH_MISSING',
  'REPRESENTATION_AUTH_REQUIRED',
  'MAILBOX_MISSING',
  'SENDING_IDENTITY_UNVERIFIED',
};

/// Where a remaining condition is resolved, in today's screens. The server
/// still names some older pages; each has a setup step that does the same job.
String setupRouteFor(String? route) {
  if (route == null) return '/client/setup';
  if (route.startsWith('/client/infrastructure')) return '/client/setup?step=email';
  if (route.startsWith('/client/representation')) return '/client/setup?step=business';
  if (route.startsWith('/client/billing')) return '/client/setup?step=plan';
  return route;
}
