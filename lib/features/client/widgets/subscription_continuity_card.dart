import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/system/widgets/trust_primitives.dart';

/// Calm, persistent workspace surface for subscription continuity.
///
/// Renders the backend `/billing/subscription` (or workspace overview
/// subscription) shape:
///   { status, lane, tier, displayPlanLabel, currentPeriodStart,
///     currentPeriodEnd, isTrialing, trialEndsAt, trialDays, ... }
///
/// Reports operational truth at every state:
///   - what operational lane + execution tier the client is on,
///   - the lifecycle state by name (active / trialing / past due /
///     paused / canceled / expired / inactive),
///   - the operational consequence (what dispatch is doing, what
///     reply ingestion is doing, what stays attached, what is gated),
///   - the next concrete action when one is owed to the client.
///
/// Doctrine: subscription is *not* a SaaS lockout switch. Reply
/// ingestion continues regardless of subscription state once a
/// mailbox transport is attached (operation-scoped, header-first).
/// Dispatch is what gates on subscription. The wording here reflects
/// that infrastructure truth — never "service ends" / "account
/// frozen" / "upgrade to keep your data."
class SubscriptionContinuityCard extends StatelessWidget {
  const SubscriptionContinuityCard({
    super.key,
    required this.subscription,
  });

  /// The /billing/subscription (or workspace overview subscription)
  /// map. May be empty if the workspace has no subscription record
  /// yet — the card falls back to AuthSessionController state.
  final Map<String, dynamic> subscription;

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;
    final theme = Theme.of(context);

    final state = _resolveState(subscription, session);
    final identityLabel = _identityLabel(subscription, session);
    final ownerSpec = _ownerSpec(state.kind);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined,
                  size: 16, color: AppTheme.publicMuted),
              const SizedBox(width: 8),
              Text(
                'Subscription continuity',
                style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.publicMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 720;

              final lead = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identityLabel,
                    style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _LifecyclePill(
                    label: state.lifecycleLabel,
                    tone: ownerSpec,
                    pulse: state.pulse,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    state.consequence,
                    style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.publicText,
                          height: 1.45,
                        ),
                  ),
                  if (state.timeline.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.timeline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.publicMuted,
                          ),
                    ),
                  ],
                ],
              );

              final actions = _CardActions(
                actions: state.actions,
                stacked: stacked,
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    lead,
                    const SizedBox(height: 14),
                    actions,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: lead),
                  const SizedBox(width: 18),
                  actions,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LifecyclePill extends StatelessWidget {
  const _LifecyclePill({
    required this.label,
    required this.tone,
    required this.pulse,
  });

  final String label;
  final _OwnerSpec tone;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingDot(color: tone.dot, size: 8, pulse: pulse),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tone.text,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CardActions extends StatelessWidget {
  const _CardActions({required this.actions, required this.stacked});

  final List<_ContinuityAction> actions;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: stacked ? WrapAlignment.start : WrapAlignment.end,
      children: [
        for (final action in actions) _ActionButton(action: action),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final _ContinuityAction action;

  @override
  Widget build(BuildContext context) {
    final onPressed =
        action.route == null ? null : () => context.go(action.route!);
    if (action.filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.publicText,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
        ),
        child: Text(action.label),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.publicText,
        side: const BorderSide(color: AppTheme.publicLine),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
      ),
      child: Text(action.label),
    );
  }
}

class _ContinuityAction {
  const _ContinuityAction({
    required this.label,
    required this.route,
    this.filled = false,
  });
  final String label;
  final String? route;
  final bool filled;
}

enum _LifecycleKind {
  active,
  trialing,
  pastDue,
  paused,
  canceled,
  expired,
  inactive,
}

class _LifecycleState {
  const _LifecycleState({
    required this.kind,
    required this.lifecycleLabel,
    required this.consequence,
    required this.timeline,
    required this.actions,
    required this.pulse,
  });
  final _LifecycleKind kind;
  final String lifecycleLabel;
  final String consequence;
  final String timeline;
  final List<_ContinuityAction> actions;
  final bool pulse;
}

class _OwnerSpec {
  const _OwnerSpec({
    required this.dot,
    required this.background,
    required this.border,
    required this.text,
  });
  final Color dot;
  final Color background;
  final Color border;
  final Color text;
}

_OwnerSpec _ownerSpec(_LifecycleKind kind) {
  switch (kind) {
    case _LifecycleKind.active:
      return const _OwnerSpec(
        dot: Color(0xFF2563EB), // active blue
        background: Color(0xFFEFF4FF),
        border: AppTheme.publicLine,
        text: Color(0xFF1D4ED8),
      );
    case _LifecycleKind.trialing:
      return const _OwnerSpec(
        dot: Color(0xFF7C3AED), // preparing violet
        background: Color(0xFFF3EFFF),
        border: AppTheme.publicLine,
        text: Color(0xFF6D28D9),
      );
    case _LifecycleKind.pastDue:
    case _LifecycleKind.expired:
      return const _OwnerSpec(
        dot: Color(0xFFB45309), // action amber
        background: Color(0xFFFEF3C7),
        border: AppTheme.publicLine,
        text: Color(0xFF92400E),
      );
    case _LifecycleKind.paused:
    case _LifecycleKind.canceled:
      return const _OwnerSpec(
        dot: Color(0xFF6B7280), // muted grey
        background: Color(0xFFF3F4F6),
        border: AppTheme.publicLine,
        text: Color(0xFF374151),
      );
    case _LifecycleKind.inactive:
      return const _OwnerSpec(
        dot: Color(0xFF9CA3AF),
        background: Color(0xFFF9FAFB),
        border: AppTheme.publicLine,
        text: Color(0xFF4B5563),
      );
  }
}

String _identityLabel(
    Map<String, dynamic> subscription, AuthSessionController session) {
  final display = _readText(subscription, 'displayPlanLabel');
  if (display.isNotEmpty) return display;

  final lane =
      _readText(subscription, 'lane', fallback: session.selectedPlan ?? '');
  final tier =
      _readText(subscription, 'tier', fallback: session.selectedTier ?? '');

  final laneText = _humanizeLane(lane);
  final tierText = _humanizeTier(tier);

  if (laneText.isEmpty && tierText.isEmpty) {
    return 'Lane and tier not yet selected';
  }
  if (laneText.isEmpty) return tierText;
  if (tierText.isEmpty) return laneText;
  return '$laneText  →  $tierText';
}

_LifecycleState _resolveState(
  Map<String, dynamic> subscription,
  AuthSessionController session,
) {
  final rawStatus = _readText(subscription, 'status',
          fallback: session.subscriptionStatus)
      .toLowerCase()
      .trim();
  final periodEnd =
      DateTime.tryParse(_readText(subscription, 'currentPeriodEnd'));
  final trialEnd = DateTime.tryParse(_readText(subscription, 'trialEndsAt'));
  final isTrialing = subscription['isTrialing'] == true ||
      rawStatus == 'trialing' ||
      rawStatus == 'trial';

  switch (rawStatus) {
    case 'active':
      return _LifecycleState(
        kind: _LifecycleKind.active,
        lifecycleLabel: 'Active',
        consequence:
            'Managed execution is running. Dispatch, reply ingestion, and the readiness engine are all active under your lane.',
        timeline: _renewalTimelineLabel(periodEnd),
        actions: const [
          _ContinuityAction(
            label: 'Open billing',
            route: '/client/billing',
          ),
          _ContinuityAction(
            label: 'Expand execution scope',
            route: '/client/subscribe',
            filled: true,
          ),
        ],
        pulse: false,
      );
    case 'trialing':
    case 'trial':
      return _LifecycleState(
        kind: _LifecycleKind.trialing,
        lifecycleLabel: 'Trial active',
        consequence:
            'Full managed execution runs during the trial. Dispatch, reply ingestion, and readiness all operate under your lane.',
        timeline: _trialTimelineLabel(trialEnd, periodEnd),
        actions: const [
          _ContinuityAction(
            label: 'Open billing',
            route: '/client/billing',
          ),
          _ContinuityAction(
            label: 'Expand execution scope',
            route: '/client/subscribe',
            filled: true,
          ),
        ],
        pulse: true,
      );
    case 'past_due':
    case 'past due':
      return _LifecycleState(
        kind: _LifecycleKind.pastDue,
        lifecycleLabel: 'Billing past due',
        consequence:
            'New dispatch is gated until billing is current. Reply ingestion on already-engaged threads continues. Mailbox transport, sending domain, and audit trail remain attached.',
        timeline: _renewalTimelineLabel(periodEnd, label: 'Period ends'),
        actions: const [
          _ContinuityAction(
            label: 'Resolve billing',
            route: '/client/billing',
            filled: true,
          ),
        ],
        pulse: true,
      );
    case 'paused':
      return _LifecycleState(
        kind: _LifecycleKind.paused,
        lifecycleLabel: 'Paused',
        consequence:
            'Dispatch is paused. Reply ingestion continues for matched threads. Mailbox transport and sending domain remain attached so resuming does not require reconnect.',
        timeline: _renewalTimelineLabel(periodEnd, label: 'Resume window ends'),
        actions: const [
          _ContinuityAction(
            label: 'Open billing',
            route: '/client/billing',
            filled: true,
          ),
        ],
        pulse: false,
      );
    case 'canceled':
    case 'cancelled':
      return _LifecycleState(
        kind: _LifecycleKind.canceled,
        lifecycleLabel: 'Canceled',
        consequence:
            'Subscription is canceled. Dispatch continues through the end of the current paid period. Reply ingestion continues until then. Mailbox transport stays attached for reactivation.',
        timeline: _renewalTimelineLabel(periodEnd, label: 'Active through'),
        actions: const [
          _ContinuityAction(
            label: 'Open billing',
            route: '/client/billing',
          ),
          _ContinuityAction(
            label: 'Reactivate plan',
            route: '/client/subscribe',
            filled: true,
          ),
        ],
        pulse: false,
      );
    case 'expired':
      return _LifecycleState(
        kind: _LifecycleKind.expired,
        lifecycleLabel: 'Expired',
        consequence:
            'Dispatch has ended. Reply ingestion continues as long as the mailbox transport remains attached. Reactivating the plan restores managed execution under the same lane + tier.',
        timeline: '',
        actions: const [
          _ContinuityAction(
            label: 'Open billing',
            route: '/client/billing',
          ),
          _ContinuityAction(
            label: 'Reactivate plan',
            route: '/client/subscribe',
            filled: true,
          ),
        ],
        pulse: false,
      );
    case 'incomplete':
    case 'incomplete_expired':
    case 'unpaid':
      return _LifecycleState(
        kind: _LifecycleKind.pastDue,
        lifecycleLabel: 'Activation incomplete',
        consequence:
            'Activation has not completed at the billing provider yet. Dispatch is gated until the initial payment posts. Mailbox transport and sending domain remain attached.',
        timeline: '',
        actions: const [
          _ContinuityAction(
            label: 'Resolve billing',
            route: '/client/billing',
            filled: true,
          ),
        ],
        pulse: true,
      );
    case 'none':
    case '':
      if (isTrialing) {
        return _LifecycleState(
          kind: _LifecycleKind.trialing,
          lifecycleLabel: 'Trial active',
          consequence:
              'Full managed execution runs during the trial. Dispatch, reply ingestion, and readiness all operate under your lane.',
          timeline: _trialTimelineLabel(trialEnd, periodEnd),
          actions: const [
            _ContinuityAction(
              label: 'Open billing',
              route: '/client/billing',
            ),
            _ContinuityAction(
              label: 'Expand execution scope',
              route: '/client/subscribe',
              filled: true,
            ),
          ],
          pulse: true,
        );
      }
      return const _LifecycleState(
        kind: _LifecycleKind.inactive,
        lifecycleLabel: 'Awaiting activation',
        consequence:
            'Subscription has not been activated yet. Identity, sending domain, and mailbox transport can be prepared in parallel; managed execution starts once activation completes.',
        timeline: '',
        actions: [
          _ContinuityAction(
            label: 'Activate subscription',
            route: '/client/subscribe',
            filled: true,
          ),
        ],
        pulse: false,
      );
    default:
      return _LifecycleState(
        kind: _LifecycleKind.inactive,
        lifecycleLabel: 'Status: ${_titleCase(rawStatus)}',
        consequence:
            'Subscription state is reported by the billing provider as "$rawStatus". Mailbox transport and reply ingestion remain attached. Open billing to review.',
        timeline: '',
        actions: const [
          _ContinuityAction(
            label: 'Open billing',
            route: '/client/billing',
            filled: true,
          ),
        ],
        pulse: false,
      );
  }
}

String _renewalTimelineLabel(DateTime? periodEnd, {String label = 'Renews on'}) {
  if (periodEnd == null) return '';
  final local = periodEnd.toLocal();
  final diffDays = local.difference(DateTime.now()).inDays;
  final dateText = _formatDate(local);
  if (diffDays >= 0 && diffDays <= 14) {
    final dayWord = diffDays == 1 ? 'day' : 'days';
    return '$label $dateText ($diffDays $dayWord)';
  }
  return '$label $dateText';
}

String _trialTimelineLabel(DateTime? trialEnd, DateTime? periodEnd) {
  final end = trialEnd ?? periodEnd;
  if (end == null) return '';
  final local = end.toLocal();
  final diffDays = local.difference(DateTime.now()).inDays;
  final dateText = _formatDate(local);
  if (diffDays >= 0 && diffDays <= 14) {
    final dayWord = diffDays == 1 ? 'day' : 'days';
    return 'Trial ends $dateText ($diffDays $dayWord)';
  }
  return 'Trial ends $dateText';
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _readText(Map<String, dynamic> map, String key, {String fallback = ''}) {
  final value = map[key];
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String _humanizeLane(String value) {
  switch (value.trim().toLowerCase()) {
    case 'opportunity':
      return 'Opportunity';
    case 'revenue':
      return 'Revenue';
  }
  return '';
}

String _humanizeTier(String value) {
  switch (value.trim().toLowerCase()) {
    case 'focused':
      return 'Focused';
    case 'multi':
    case 'multi-market':
    case 'multi_market':
      return 'Multi-Market';
    case 'precision':
      return 'Precision';
  }
  return '';
}

String _titleCase(String value) {
  final t = value.trim();
  if (t.isEmpty) return 'Unknown';
  return t
      .split(RegExp(r'[_\s-]+'))
      .map((part) => part.isEmpty
          ? part
          : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}
