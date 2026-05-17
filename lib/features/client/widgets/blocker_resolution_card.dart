import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

/// Renders a list of readiness blockers, each with an actionable CTA
/// pointing at the route that resolves it. Client-owned blockers get a
/// CTA; operator-owned blockers render a neutral "Orchestrate is handling
/// this" line. Never a dead diagnostic.
///
/// Used by Settings, Home, and Operations so the resolution path is
/// identical wherever a blocker is surfaced.
class BlockerResolutionList extends StatelessWidget {
  const BlockerResolutionList({
    super.key,
    required this.blockers,
    this.authorized = true,
    this.authAcceptedAt,
    this.onReturned,
  });

  /// Raw blocker list from the readiness payload. Each entry is expected
  /// to be a Map with `code`, `label`, and `detail` fields.
  final List<dynamic> blockers;

  /// Whether representation authorization is recorded. When false and
  /// the backend has not enumerated an explicit authorization blocker,
  /// this widget still surfaces the "Authorize representation" CTA so
  /// the user is never stranded.
  final bool authorized;

  /// ISO date when authorization was last accepted (used in the cleared
  /// state line). Ignored when not authorized.
  final dynamic authAcceptedAt;

  /// Invoked after the user returns from a CTA route. Caller typically
  /// wires this to a state refresh.
  final VoidCallback? onReturned;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final refresh = onReturned ?? () {};

    if (authorized && blockers.isEmpty) {
      children.add(ClientInfoRow(
        title: 'Representation authorization',
        primary: 'Current authorization is recorded.',
        secondary: dateLabel(authAcceptedAt),
      ));
      children.add(const ClientInfoRow(
        title: 'Outreach readiness',
        primary: 'No blockers reported.',
      ));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    final hasAuthBlocker = blockers.any((b) {
      final code = readText(asMap(b), 'code');
      return code == 'REPRESENTATION_AUTH_MISSING' ||
          code == 'REPRESENTATION_AUTH_REQUIRED' ||
          code == 'AUTHORIZATION_MISSING';
    });

    if (!authorized && !hasAuthBlocker) {
      children.add(BlockerResolutionRow(
        title: 'Authorization required',
        explanation:
            'Representation authorization is required before Orchestrate can send outreach on your behalf.',
        owner: 'You',
        ctaLabel: 'Authorize representation',
        route: '/client/representation',
        onReturned: refresh,
      ));
    }

    for (final raw in blockers) {
      final blocker = asMap(raw);
      final code = readText(blocker, 'code');
      final label = readText(blocker, 'label');
      final detail = readText(blocker, 'detail');
      final action = resolveBlockerAction(code);

      children.add(BlockerResolutionRow(
        title: label.isEmpty ? action.fallbackTitle : label,
        explanation: detail.isEmpty ? action.fallbackDetail : detail,
        addendum: action.addendum,
        owner: action.owner,
        ctaLabel: action.ctaLabel,
        route: action.route,
        onReturned: refresh,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class BlockerAction {
  const BlockerAction({
    required this.owner,
    required this.ctaLabel,
    required this.route,
    required this.fallbackTitle,
    required this.fallbackDetail,
    this.addendum,
  });

  final String owner;
  final String? ctaLabel;
  final String? route;
  final String fallbackTitle;
  final String fallbackDetail;
  final String? addendum;
}

BlockerAction resolveBlockerAction(String code) {
  switch (code) {
    case 'REPRESENTATION_AUTH_MISSING':
    case 'REPRESENTATION_AUTH_REQUIRED':
    case 'AUTHORIZATION_MISSING':
      return const BlockerAction(
        owner: 'You',
        ctaLabel: 'Authorize representation',
        route: '/client/representation',
        fallbackTitle: 'Authorization required',
        fallbackDetail:
            'Representation authorization is required before Orchestrate can send outreach on your behalf.',
      );
    case 'SUBSCRIPTION_BLOCKED':
    case 'BILLING_BLOCKED':
      return const BlockerAction(
        owner: 'You',
        ctaLabel: 'Resolve billing',
        route: '/client/billing',
        fallbackTitle: 'Subscription blocked',
        fallbackDetail:
            'Billing must be current before managed execution can run.',
      );
    case 'MAILBOX_MISSING':
      return const BlockerAction(
        owner: 'You',
        ctaLabel: 'Connect mailbox',
        route: '/client/infrastructure',
        fallbackTitle: 'Mailbox missing',
        fallbackDetail: 'No sending mailbox is connected yet.',
        addendum:
            'Google sign-in does not connect your sending mailbox. Connect the mailbox Orchestrate should operate from.',
      );
    case 'MAILBOX_DISCONNECTED':
      return const BlockerAction(
        owner: 'You',
        ctaLabel: 'Reconnect mailbox',
        route: '/client/infrastructure',
        fallbackTitle: 'Mailbox connection lost',
        fallbackDetail:
            'The mailbox credential is no longer valid. Reconnect to resume dispatch.',
      );
    case 'MAILBOX_NOT_READY':
    case 'MAILBOX_UNVERIFIED':
    case 'MAILBOX_ACTIVATION_FAILED':
    case 'MAILBOX_BLOCKED':
      return const BlockerAction(
        owner: 'You',
        ctaLabel: 'Open infrastructure',
        route: '/client/infrastructure',
        fallbackTitle: 'Mailbox not ready',
        fallbackDetail:
            'The connected mailbox is not yet ready for sending. Open Infrastructure to resolve.',
      );
    case 'MAILBOX_PROVIDER_ERROR':
      return const BlockerAction(
        owner: 'Orchestrate',
        ctaLabel: null,
        route: null,
        fallbackTitle: 'Outbound provider is being reconfigured',
        fallbackDetail:
            'Orchestrate is handling this — the provider dependency is internal. Execution resumes automatically.',
      );
    case 'SENDING_IDENTITY_UNVERIFIED':
      return const BlockerAction(
        owner: 'You',
        ctaLabel: 'Verify sending identity',
        // Domain-first continuity: focus=domain anchors the user on
        // the Sending domain panel instead of the transport area.
        route: '/client/infrastructure?focus=domain',
        fallbackTitle: 'Sending identity unverified',
        fallbackDetail:
            'SPF, DKIM, and DMARC must match before managed execution dispatches from this domain.',
      );
    case 'BUSINESS_IDENTITY_INCOMPLETE':
      return const BlockerAction(
        owner: 'You',
        ctaLabel: 'Complete business identity',
        route: '/client/representation',
        fallbackTitle: 'Business identity incomplete',
        fallbackDetail:
            'Teach Orchestrate your business identity, offer, and ideal customer profile.',
      );
    case 'SETUP_INCOMPLETE':
      return const BlockerAction(
        owner: 'You',
        ctaLabel: 'Complete setup',
        route: '/client/setup',
        fallbackTitle: 'Setup incomplete',
        fallbackDetail: 'Finish setup before outreach can run.',
      );
    case 'NO_LEADS':
    case 'ALL_LEADS_SUPPRESSED':
    case 'NO_CAMPAIGN':
    case 'OUTREACH_NEEDS_ATTENTION':
      return const BlockerAction(
        owner: 'You',
        ctaLabel: 'View operations',
        route: '/client/operations',
        fallbackTitle: 'Operations needs attention',
        fallbackDetail: 'Open Operations to see the named step.',
      );
    default:
      return const BlockerAction(
        owner: 'You',
        ctaLabel: 'View operations',
        route: '/client/operations',
        fallbackTitle: 'Readiness blocker',
        fallbackDetail: 'Open Operations to see the named step.',
      );
  }
}

class BlockerResolutionRow extends StatelessWidget {
  const BlockerResolutionRow({
    super.key,
    required this.title,
    required this.explanation,
    required this.owner,
    required this.ctaLabel,
    required this.route,
    required this.onReturned,
    this.addendum,
  });

  final String title;
  final String explanation;
  final String? addendum;
  final String owner;
  final String? ctaLabel;
  final String? route;
  final VoidCallback onReturned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: theme.textTheme.titleLarge),
              ),
              const SizedBox(width: 12),
              ClientBadge(label: 'Owner: $owner'),
            ],
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(explanation, style: theme.textTheme.bodyLarge),
          ],
          if (addendum != null && addendum!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              addendum!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          if (ctaLabel != null && route != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () async {
                await context.push(route!);
                onReturned();
              },
              child: Text(ctaLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
