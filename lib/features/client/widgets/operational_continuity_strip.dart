import 'package:flutter/material.dart';

import 'package:orchestrate_app/features/guidance/guidance_models.dart';
import 'package:orchestrate_app/features/guidance/guidance_repository.dart';
import 'package:orchestrate_app/features/system/widgets/trust_primitives.dart';

/// Calm operational-continuity strip. Renders deterministic motion
/// lines derived from real backend state (readiness bucket, mailbox
/// state, sending identity, recent transitions) — never fakes activity.
///
/// Doctrine: the runtime must feel operationally alive without AI
/// theater. Each line names a concrete operational truth the user
/// can verify in Operations / Infrastructure / Representation.
class OperationalContinuityStrip extends StatefulWidget {
  const OperationalContinuityStrip({super.key, this.surface});

  /// Surface tag for guidance audit traceability.
  final String? surface;

  @override
  State<OperationalContinuityStrip> createState() =>
      _OperationalContinuityStripState();
}

class _OperationalContinuityStripState
    extends State<OperationalContinuityStrip> {
  late final GuidanceRepository _repository = GuidanceRepository();
  late final Future<GuidanceContextSnapshot> _future = _load();

  Future<GuidanceContextSnapshot> _load() =>
      _repository.fetchClientContext(surface: widget.surface);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GuidanceContextSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _Skeleton();
        }
        if (snapshot.hasError || snapshot.data == null) {
          // Honest failure: name that the live state is temporarily
          // unavailable. Never invent activity.
          return _StripContainer(
            lines: const [
              _ContinuityLine(
                kind: _ContinuityKind.muted,
                text: 'Live operational state is temporarily unavailable.',
              ),
            ],
          );
        }
        final lines = _composeLines(snapshot.data!);
        return _StripContainer(lines: lines);
      },
    );
  }

  List<_ContinuityLine> _composeLines(GuidanceContextSnapshot snap) {
    final lines = <_ContinuityLine>[];
    final bucket = snap.readinessBucket ?? '';
    final blocker = snap.readinessBlockerCode ?? '';

    // Readiness headline — always the first line.
    //
    // Important doctrine fix: the readiness engine's bucket flips on
    // CAMPAIGN STATUS, not on actual runtime activity. The labels
    // below were previously over-confident ("Orchestrate is
    // operating the active execution scope", "Recovery branch is
    // active", etc.) — they implied runtime activity the bucket
    // could not prove. Each label has been narrowed to assert only
    // what the bucket actually proves. The authoritative runtime
    // state (queue depth, recent activity, recent failures) lands
    // on a SEPARATE line below, sourced from /client/runtime-state
    // and rendered by the parent screen.
    switch (bucket) {
      case 'executing':
        lines.add(const _ContinuityLine(
          kind: _ContinuityKind.active,
          text:
              'Readiness gates passed and at least one campaign is active. Whether dispatch is in flight right now is named on the runtime line.',
        ));
        break;
      case 'orchestrate_working':
        lines.add(const _ContinuityLine(
          kind: _ContinuityKind.preparing,
          text:
              'Readiness has cleared activation. The dispatch governor decides when first sends leave; the runtime line names what is in flight.',
        ));
        break;
      case 'ready_to_execute':
        lines.add(const _ContinuityLine(
          kind: _ContinuityKind.preparing,
          text:
              'Readiness gates passed.',
        ));
        break;
      case 'recovering':
        lines.add(const _ContinuityLine(
          kind: _ContinuityKind.recovering,
          text:
              'Readiness reports a recovery state on at least one subsystem. The runtime line below names what is actually in flight; check Operations for the named dependency.',
        ));
        break;
      case 'orchestrate_blocked_internal':
        lines.add(const _ContinuityLine(
          kind: _ContinuityKind.recovering,
          text:
              'Internal dependency being restored. Operator attention queued.',
        ));
        break;
      case 'degraded':
        lines.add(const _ContinuityLine(
          kind: _ContinuityKind.recovering,
          text:
              'Execution is running degraded. Operator review queued.',
        ));
        break;
      case 'client_action_required':
        lines.add(_ContinuityLine(
          kind: _ContinuityKind.action,
          text: _clientActionLine(blocker),
        ));
        break;
      default:
        lines.add(const _ContinuityLine(
          kind: _ContinuityKind.muted,
          text: 'Readiness state is loading…',
        ));
    }

    // Sending identity — `status=ACTIVE` only proves the last DNS check
    // passed; it does NOT prove DNS is still correct *right now*. The
    // poll worker re-verifies on a cadence; until then "at the last
    // check" is the honest read.
    final identityStatus = snap.sendingDomainStatus ?? '';
    if (identityStatus == 'ACTIVE') {
      lines.add(const _ContinuityLine(
        kind: _ContinuityKind.active,
        text:
            'Sending identity verified. SPF, DKIM, and DMARC matched.',
      ));
    } else if (identityStatus == 'PENDING') {
      lines.add(const _ContinuityLine(
        kind: _ContinuityKind.preparing,
        text:
            'DNS verification in progress. Rechecking SPF, DKIM, and DMARC.',
      ));
    } else if (identityStatus.isNotEmpty) {
      lines.add(_ContinuityLine(
        kind: _ContinuityKind.muted,
        text: 'Sending identity status: ${identityStatus.toLowerCase()}.',
      ));
    }

    // Mailbox — `connectionState=AUTHORIZED` only proves OAuth completed;
    // it does NOT prove a refresh would succeed right now. State is
    // sourced from the latest connection record; a live refresh probe
    // is not part of this snapshot.
    final mailboxState = snap.mailboxConnectionState ?? '';
    if (mailboxState == 'REQUIRES_REAUTH' || mailboxState == 'REVOKED') {
      lines.add(const _ContinuityLine(
        kind: _ContinuityKind.action,
        text:
            'Mailbox reconnect required. Open Infrastructure to reconnect.',
      ));
    } else if (mailboxState == 'AUTHORIZED' || mailboxState == 'BOOTSTRAPPED') {
      lines.add(const _ContinuityLine(
        kind: _ContinuityKind.active,
        text:
            'Mailbox connected.',
      ));
    } else if (mailboxState == 'PENDING_AUTH') {
      lines.add(const _ContinuityLine(
        kind: _ContinuityKind.action,
        text:
            'Mailbox awaiting connection. Open Infrastructure to connect.',
      ));
    }

    // Subscription degradation line. ACTIVE and TRIALING are
    // healthy execution states — no line is added so the strip
    // stays calm. The SubscriptionContinuityCard on the workspace
    // home carries the full lifecycle narrative; this line just
    // signals the operational consequence inside the readiness
    // continuity rhythm.
    final sub = (snap.subscriptionStatus ?? '').toUpperCase();
    final subLine = _subscriptionLine(sub);
    if (subLine != null) {
      lines.add(subLine);
    }
    return lines;
  }

  _ContinuityLine? _subscriptionLine(String upperStatus) {
    switch (upperStatus) {
      case '':
      case 'ACTIVE':
      case 'TRIALING':
      case 'TRIAL':
        return null;
      case 'PAST_DUE':
        return const _ContinuityLine(
          kind: _ContinuityKind.action,
          text:
              'Billing past due. New dispatch is gated. Open billing to resolve.',
        );
      case 'PAUSED':
        return const _ContinuityLine(
          kind: _ContinuityKind.recovering,
          text:
              'Subscription paused. Dispatch paused. Reply ingestion continues.',
        );
      case 'CANCELED':
      case 'CANCELLED':
        return const _ContinuityLine(
          kind: _ContinuityKind.recovering,
          text:
              'Subscription canceled. Dispatch continues through the paid period.',
        );
      case 'EXPIRED':
        return const _ContinuityLine(
          kind: _ContinuityKind.action,
          text:
              'Subscription expired. Dispatch ended.',
        );
      case 'INCOMPLETE':
      case 'INCOMPLETE_EXPIRED':
      case 'UNPAID':
        return const _ContinuityLine(
          kind: _ContinuityKind.action,
          text:
              'Activation incomplete. Dispatch gated until billing confirms.',
        );
      case 'NONE':
        return null;
      default:
        return _ContinuityLine(
          kind: _ContinuityKind.muted,
          text: 'Subscription status: ${upperStatus.toLowerCase()}.',
        );
    }
  }

  String _clientActionLine(String blockerCode) {
    switch (blockerCode) {
      case 'SUBSCRIPTION_BLOCKED':
        return 'Awaiting subscription.';
      case 'BUSINESS_IDENTITY_INCOMPLETE':
        return 'Awaiting business identity. Open Representation.';
      case 'SENDING_IDENTITY_UNVERIFIED':
        return 'Awaiting sending domain verification.';
      case 'MAILBOX_MISSING':
        return 'Awaiting mailbox connection. Open Infrastructure.';
      case 'MAILBOX_DISCONNECTED':
        return 'Mailbox connection lost. Open Infrastructure to reconnect.';
      case 'MAILBOX_UNVERIFIED':
        return 'Mailbox not verified. Complete verification in Infrastructure.';
      case '':
        return 'Awaiting your action. See the gate below.';
      default:
        return 'Action required: $blockerCode.';
    }
  }
}

class _StripContainer extends StatelessWidget {
  const _StripContainer({required this.lines});

  final List<_ContinuityLine> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_outlined,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Operational continuity',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in lines) ...[
            _ContinuityRow(line: line),
            if (line != lines.last) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _ContinuityRow extends StatelessWidget {
  const _ContinuityRow({required this.line});

  final _ContinuityLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = _spec(line.kind, theme);
    // Calm operational motion: pulse the dot for kinds that represent
    // actively-progressing or attention-requiring states. Terminal
    // states stay static so the strip reads as calm continuity rather
    // than constant blinking.
    final shouldPulse = line.kind == _ContinuityKind.preparing ||
        line.kind == _ContinuityKind.recovering ||
        line.kind == _ContinuityKind.action;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 6),
          child: PulsingDot(
            color: spec.color,
            size: 8,
            pulse: shouldPulse,
          ),
        ),
        Expanded(
          child: Text(
            line.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  _ContinuitySpec _spec(_ContinuityKind kind, ThemeData theme) {
    switch (kind) {
      case _ContinuityKind.active:
        return _ContinuitySpec(color: theme.colorScheme.primary);
      case _ContinuityKind.preparing:
        return _ContinuitySpec(color: theme.colorScheme.tertiary);
      case _ContinuityKind.recovering:
        return _ContinuitySpec(color: theme.colorScheme.secondary);
      case _ContinuityKind.action:
        return _ContinuitySpec(color: theme.colorScheme.error);
      case _ContinuityKind.muted:
        return _ContinuitySpec(color: theme.colorScheme.outlineVariant);
    }
  }
}

enum _ContinuityKind { active, preparing, recovering, action, muted }

class _ContinuityLine {
  const _ContinuityLine({required this.kind, required this.text});
  final _ContinuityKind kind;
  final String text;
}

class _ContinuitySpec {
  const _ContinuitySpec({required this.color});
  final Color color;
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text(
            'Loading…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
