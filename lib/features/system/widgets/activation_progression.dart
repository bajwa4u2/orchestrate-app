import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/system/widgets/trust_primitives.dart';

/// Activation progression. The canonical post-subscription activation
/// chain, rendered as a vertical flow with per-step state, ownership,
/// next-action CTA, and operational explanation. The widget itself is
/// stateless — it takes a list of {@link ActivationStep}s and renders
/// them. State derivation belongs to the caller (typically the home
/// screen or a dedicated activation orchestrator), so the same chain
/// can be driven by either the eligibility-authority response from the
/// backend or by a static "this is what activation looks like" preview
/// on the public site.
class ActivationProgression extends StatelessWidget {
  const ActivationProgression({
    super.key,
    required this.steps,
    this.title = 'Activation progression',
    this.subtitle,
  });

  final List<ActivationStep> steps;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.publicMuted),
            ),
          ],
          const SizedBox(height: 18),
          for (var i = 0; i < steps.length; i++)
            _ActivationStepRow(
              index: i,
              isLast: i == steps.length - 1,
              step: steps[i],
              theme: theme,
            ),
        ],
      ),
    );
  }
}

class ActivationStep {
  const ActivationStep({
    required this.label,
    required this.body,
    required this.state,
    required this.ownership,
    this.actionLabel,
    this.actionRoute,
    this.blockerReason,
  });

  final String label;
  final String body;
  final TrustState state;
  final OperationalOwnership ownership;

  /// CTA label rendered when state == pending and ownership == client.
  /// If null, no CTA is rendered.
  final String? actionLabel;
  final String? actionRoute;

  /// Optional reason rendered when state == blocked or waiting — names
  /// the dependency that is not yet resolved.
  final String? blockerReason;
}

class _ActivationStepRow extends StatelessWidget {
  const _ActivationStepRow({
    required this.index,
    required this.isLast,
    required this.step,
    required this.theme,
  });

  final int index;
  final bool isLast;
  final ActivationStep step;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colour = step.state.color(theme);
    final stepNumber = '${index + 1}'.padLeft(2, '0');
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rail
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.publicSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: colour, width: 2),
                  ),
                  child: step.state == TrustState.verified
                      ? Icon(Icons.check, size: 18, color: colour)
                      : PulsingDot(
                          color: colour,
                          size: 8,
                          pulse: step.state.shouldPulse,
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppTheme.publicLine,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.publicSurfaceSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radius - 6),
                  border: Border.all(color: AppTheme.publicLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          stepNumber,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.publicMuted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InfrastructureOwnershipChip(ownership: step.ownership),
                        const SizedBox(width: 8),
                        TrustStateBadge(state: step.state, dense: true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.publicText,
                        height: 1.45,
                      ),
                    ),
                    if (step.blockerReason != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        step.blockerReason!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.publicMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (step.state == TrustState.pending &&
                        step.ownership == OperationalOwnership.client &&
                        step.actionLabel != null &&
                        step.actionRoute != null) ...[
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => context.go(step.actionRoute!),
                        child: Text(step.actionLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Static preview of the activation chain, suitable for public surfaces
/// (post-pricing landing, /how-it-works, evaluator path). Every step
/// shows the architecture order and ownership without claiming any
/// real account state.
ActivationProgression buildActivationPreview() {
  return const ActivationProgression(
    title: 'Activation progression',
    subtitle:
        'The eight-stage chain every account walks through. The platform tracks state per stage; the workspace renders the same chain with live state when you sign in.',
    steps: [
      ActivationStep(
        label: 'Business identity',
        body:
            'Define market, offer, target segments. The inputs Orchestrate needs before discovery can be tied to your business.',
        state: TrustState.pending,
        ownership: OperationalOwnership.client,
      ),
      ActivationStep(
        label: 'Sending domain',
        body:
            'Confirm or attach the domain Orchestrate will dispatch from. Domain identity is the operational center; transports plug in beneath.',
        state: TrustState.waiting,
        ownership: OperationalOwnership.client,
        blockerReason: 'Waiting for business identity to be recorded.',
      ),
      ActivationStep(
        label: 'DNS readiness',
        body:
            'Publish SPF, DKIM, DMARC at your DNS provider. Orchestrate verifies with live DNS lookups and re-checks automatically until propagation lands.',
        state: TrustState.waiting,
        ownership: OperationalOwnership.client,
        blockerReason: 'Waiting for a sending domain.',
      ),
      ActivationStep(
        label: 'Transport authorization',
        body:
            'Connect Google Workspace, Microsoft 365, or custom SMTP + IMAP. Credentials are sealed by the encrypted vault adapter; tokens never touch the browser.',
        state: TrustState.waiting,
        ownership: OperationalOwnership.client,
        blockerReason: 'Waiting for DNS verification to land.',
      ),
      ActivationStep(
        label: 'Reply continuity',
        body:
            'For custom transports, attach IMAP inbound monitoring in the same setup flow. Replies are matched only to operations Orchestrate sent.',
        state: TrustState.waiting,
        ownership: OperationalOwnership.client,
        blockerReason: 'Waiting for a transport to be authorized.',
      ),
      ActivationStep(
        label: 'Trust readiness',
        body:
            'Trust classification reflects SPF / DKIM / DMARC verification, mailbox health, and recent transport events. Drives dispatch eligibility at the platform layer.',
        state: TrustState.waiting,
        ownership: OperationalOwnership.orchestrate,
        blockerReason: 'Waiting for transport + DNS to settle.',
      ),
      ActivationStep(
        label: 'Operational readiness',
        body:
            'A single backend authority evaluates the dependency chain end to end. Every client surface reads the same authoritative state.',
        state: TrustState.waiting,
        ownership: OperationalOwnership.orchestrate,
        blockerReason: 'Waiting for trust readiness.',
      ),
      ActivationStep(
        label: 'Governed activation',
        body:
            'Dispatch eligibility flips. Managed execution operates against the active execution scope under per-mailbox pacing, with reply continuity, suppression, and recovery all governed.',
        state: TrustState.waiting,
        ownership: OperationalOwnership.orchestrate,
        blockerReason: 'Waiting for operational readiness.',
      ),
    ],
  );
}
