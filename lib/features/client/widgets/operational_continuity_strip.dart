import 'package:flutter/material.dart';

import 'package:orchestrate_app/features/guidance/guidance_models.dart';
import 'package:orchestrate_app/features/guidance/guidance_repository.dart';

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
    switch (bucket) {
      case 'executing':
        lines.add(const _ContinuityLine(
          kind: _ContinuityKind.active,
          text:
              'Managed execution is running — signal discovery, qualification, governed dispatch, and follow-up continuity are all live.',
        ));
        break;
      case 'orchestrate_working':
        lines.add(const _ContinuityLine(
          kind: _ContinuityKind.preparing,
          text: 'Orchestrate is preparing dispatch — the next sends are queued under governed pacing.',
        ));
        break;
      case 'ready_to_execute':
        lines.add(const _ContinuityLine(
          kind: _ContinuityKind.preparing,
          text: 'Readiness gates passed — Orchestrate is activating managed execution.',
        ));
        break;
      case 'recovering':
        lines.add(const _ContinuityLine(
          kind: _ContinuityKind.recovering,
          text:
              'Recovery branch is active — dispatch is paused while Orchestrate stabilizes provider state.',
        ));
        break;
      case 'orchestrate_blocked_internal':
        lines.add(const _ContinuityLine(
          kind: _ContinuityKind.recovering,
          text:
              'Internal dependency being restored — operator attention queued; no client action.',
        ));
        break;
      case 'degraded':
        lines.add(const _ContinuityLine(
          kind: _ContinuityKind.recovering,
          text:
              'Execution is running degraded — operator review queued on the subsystem flagged below.',
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

    // Sending identity continuity line.
    final identityStatus = snap.sendingDomainStatus ?? '';
    if (identityStatus == 'ACTIVE') {
      lines.add(const _ContinuityLine(
        kind: _ContinuityKind.active,
        text: 'Sending identity verified — SPF, DKIM, and DMARC are passing live DNS.',
      ));
    } else if (identityStatus == 'PENDING') {
      lines.add(const _ContinuityLine(
        kind: _ContinuityKind.preparing,
        text:
            'DNS verification in progress — Orchestrate re-checks SPF / DKIM / DMARC on the polling cadence.',
      ));
    } else if (identityStatus.isNotEmpty) {
      lines.add(_ContinuityLine(
        kind: _ContinuityKind.muted,
        text: 'Sending identity status: ${identityStatus.toLowerCase()}.',
      ));
    }

    // Mailbox continuity line.
    final mailboxState = snap.mailboxConnectionState ?? '';
    if (mailboxState == 'REQUIRES_REAUTH' || mailboxState == 'REVOKED') {
      lines.add(const _ContinuityLine(
        kind: _ContinuityKind.action,
        text:
            'Mailbox reconnect required — the OAuth credential is no longer valid. Open Infrastructure to reconnect.',
      ));
    } else if (mailboxState == 'AUTHORIZED' || mailboxState == 'BOOTSTRAPPED') {
      lines.add(const _ContinuityLine(
        kind: _ContinuityKind.active,
        text:
            'Mailbox connection authorized — vault-backed credential is active and refreshable.',
      ));
    } else if (mailboxState == 'PENDING_AUTH') {
      lines.add(const _ContinuityLine(
        kind: _ContinuityKind.action,
        text:
            'Mailbox awaiting OAuth — connect Gmail or Microsoft 365 from Infrastructure to proceed.',
      ));
    }

    // Subscription guard.
    final sub = (snap.subscriptionStatus ?? '').toUpperCase();
    if (sub.isNotEmpty && sub != 'ACTIVE' && sub != 'TRIALING') {
      lines.add(_ContinuityLine(
        kind: _ContinuityKind.action,
        text: 'Subscription status is $sub — readiness orchestration is gated until billing is current.',
      ));
    }
    return lines;
  }

  String _clientActionLine(String blockerCode) {
    switch (blockerCode) {
      case 'SUBSCRIPTION_BLOCKED':
        return 'Awaiting subscription — readiness orchestration is gated until billing is current.';
      case 'BUSINESS_IDENTITY_INCOMPLETE':
        return 'Awaiting business identity — open Representation to teach Orchestrate offer, ICP, and boundaries.';
      case 'SENDING_IDENTITY_UNVERIFIED':
        return 'Awaiting sending-identity verification — Orchestrate is watching DNS for SPF / DKIM / DMARC.';
      case 'MAILBOX_MISSING':
        return 'Awaiting mailbox connection — connect Gmail or Microsoft 365 from Infrastructure.';
      case 'MAILBOX_DISCONNECTED':
        return 'Mailbox connection lost — reconnect from Infrastructure to resume dispatch.';
      case 'MAILBOX_UNVERIFIED':
        return 'Mailbox not verified for sending — complete verification from Infrastructure.';
      case '':
        return 'Awaiting a client-owned step — see the section below for the named gate.';
      default:
        return 'Awaiting client action — $blockerCode.';
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6, right: 10),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: spec.color,
            shape: BoxShape.circle,
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
            'Loading operational continuity…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
