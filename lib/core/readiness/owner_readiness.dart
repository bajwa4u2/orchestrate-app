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
    this.waiting = false,
  });

  /// Shown, but not something that needs a yes now: being checked on our
  /// side, or not open until an earlier step is done.
  final bool waiting;

  final String key;
  final String title;
  final String line;
  final String cta;
  final String route;
  final bool done;
}

/// The four steps in the order an owner meets them, or an empty list when the
/// server did not send its chain (unknown is never shown as open or done).
///
/// [authority] is `/client/representative`'s `organizationalAuthority.state`
/// (ESTABLISHED | UNDER_REVIEW | NOT_ESTABLISHED), when known.
List<OwnerStep> ownerStepsFrom(Object? eligibility, {String? authority}) {
  if (eligibility is! Map) return const [];
  final chain = eligibility['chain'];
  if (chain is! List) return const [];
  final ready = <String>{
    for (final layer in chain.whereType<Map>())
      if (layer['state'] == 'ready') '${layer['key']}',
  };
  final blockers = eligibility['blockers'];
  final codes = <String>{
    if (blockers is List)
      for (final b in blockers.whereType<Map>()) '${b['code']}',
  };
  // A connected mailbox that can no longer send is still the email step.
  final mailboxTrouble = codes.any(mailboxProblemCodes.contains);
  final planDone = ready.contains('subscription');
  final emailDone = ready.contains('sending_transport') && !mailboxTrouble;
  final actDone = ready.contains('representation') && authority == 'ESTABLISHED';
  final actChecking = authority == 'UNDER_REVIEW';
  // Setup opens this step only after the plan and email (and the business,
  // buyers and offer a finished setup already has). A card that sends someone
  // to a locked step promises what the step cannot give (founder walk,
  // 2 Oct 2026): say what comes first, and go there.
  final actLocked = !actDone && !actChecking && (!planDone || !emailDone);
  return [
    OwnerStep(
      key: 'act',
      title: 'Who acts for this business',
      line: actChecking
          ? 'Checking your document. Nothing is needed from you.'
          : actLocked
              ? 'Opens once your plan and email are set.'
              : 'You, your registration document, and your yes.',
      cta: actChecking
          ? 'See where it stands'
          : actLocked
              ? 'See what comes first'
              : 'Finish this step',
      route: actLocked ? '/client/setup' : '/client/setup?step=permission',
      done: actDone,
      waiting: actChecking || actLocked,
    ),
    OwnerStep(
      key: 'email',
      title: 'Connect your email',
      line: mailboxTrouble
          ? 'Your email needs connecting again before notes can go out.'
          : 'Notes go out from your address. Replies land in your inbox.',
      cta: mailboxTrouble ? 'Reconnect email' : 'Connect email',
      route: '/client/setup?step=email',
      done: emailDone,
    ),
    OwnerStep(
      key: 'domain',
      title: 'Make your domain trusted',
      line: 'So your notes reach inboxes, not spam.',
      cta: 'Check your domain',
      route: '/client/setup?step=email',
      done: ready.contains('trust'),
    ),
    // Last, on the founder's word (4 Oct 2026): the work first, the plan at the end.
    OwnerStep(
      key: 'plan',
      title: 'Choose your plan',
      line: 'Setting up is free. A plan starts finding businesses and writing to the ones you say yes to.',
      cta: 'Choose a plan',
      route: '/client/setup?step=plan',
      done: planDone,
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
  ...mailboxProblemCodes,
};

/// A mailbox that is connected but cannot send: the email card speaks for it.
const mailboxProblemCodes = <String>{
  'MAILBOX_DISCONNECTED',
  'MAILBOX_CREDENTIAL_MISSING',
  'MAILBOX_UNVERIFIED',
  'MAILBOX_NOT_READY',
  'MAILBOX_BLOCKED',
  'MAILBOX_ACTIVATION_FAILED',
  'MAILBOX_PROVIDER_ERROR',
};

/// Where a remaining condition is resolved. The server names today's places
/// (2 Oct 2026); with no route, Setup is where conditions are met.
String setupRouteFor(String? route) => route ?? '/client/setup';
