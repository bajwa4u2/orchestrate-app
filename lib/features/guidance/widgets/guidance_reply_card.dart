import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/widgets/substrate_chip.dart';
import '../guidance_models.dart';
import 'guidance_ref_chip.dart';

/// Renders a single GuidanceReply following the four-question
/// contract — title (state) / body (why) / whatChangesIt (who owns
/// next step + when) / next-step button (when one exists) / refs row
/// (where the answer came from).
///
/// Calm and visual-rhythm-aligned with the rest of the client
/// workspace. No avatar. No animation. No chat bubble.
class GuidanceReplyCard extends StatelessWidget {
  const GuidanceReplyCard({
    super.key,
    required this.reply,
    this.onNavigate,
    this.onFeedback,
  });

  final GuidanceReply reply;
  final void Function(String route)? onNavigate;
  final void Function(String rating)? onFeedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ownership = _OwnershipBadge(ownership: reply.ownership);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  reply.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ownership,
            ],
          ),
          const SizedBox(height: 10),
          Text(
            reply.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            reply.whatChangesIt,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (reply.nextStep != null) ...[
            const SizedBox(height: 14),
            _NextStepButton(
              nextStep: reply.nextStep!,
              onNavigate: (route) =>
                  onNavigate != null ? onNavigate!(route) : context.go(route),
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: theme.colorScheme.outlineVariant, height: 1),
          const SizedBox(height: 12),
          _RefsRow(refs: reply.refs, templateName: reply.templateName),
          if (onFeedback != null) ...[
            const SizedBox(height: 10),
            _FeedbackRow(onFeedback: onFeedback!),
          ],
        ],
      ),
    );
  }
}

/// Renders the canonical `CanonicalBlockerOwner` enum (client /
/// orchestrate / operator / informational) as a `SubstrateChip`.
/// Color semantics per `system/topology/topology-grammar.md` §6 and
/// `system/diagnostics/diagnostics-grammar.md` §3.1:
///   client          → rose (client_action_required surfaces rose)
///   orchestrate     → teal (company accent for orchestrate-owned)
///   operator        → sun  (operator-mediated escalation surface)
///   informational   → mist (neutral)
class _OwnershipBadge extends StatelessWidget {
  const _OwnershipBadge({required this.ownership});

  final String ownership;

  @override
  Widget build(BuildContext context) {
    final (String label, SubstrateChipState state) = switch (ownership) {
      'client' => ('You', SubstrateChipState.rose),
      'orchestrate' => ('Orchestrate', SubstrateChipState.teal),
      'operator' => ('Operator', SubstrateChipState.sun),
      _ => ('Info', SubstrateChipState.mist),
    };
    return SubstrateChip(label: label, state: state);
  }
}

class _NextStepButton extends StatelessWidget {
  const _NextStepButton({required this.nextStep, required this.onNavigate});

  final GuidanceNextStep nextStep;
  final void Function(String route) onNavigate;

  @override
  Widget build(BuildContext context) {
    if (nextStep.route == null || nextStep.route!.isEmpty) {
      return _NextStepStatic(label: nextStep.label);
    }
    final filled = nextStep.blocking;
    final route = nextStep.route!;
    if (filled) {
      return FilledButton.icon(
        onPressed: () => onNavigate(route),
        icon: const Icon(Icons.arrow_forward, size: 18),
        label: Text(nextStep.label),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => onNavigate(route),
      icon: const Icon(Icons.arrow_forward, size: 18),
      label: Text(nextStep.label),
    );
  }
}

class _NextStepStatic extends StatelessWidget {
  const _NextStepStatic({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RefsRow extends StatelessWidget {
  const _RefsRow({required this.refs, required this.templateName});

  final List<GuidanceRef> refs;
  final String templateName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sources',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final ref in refs) GuidanceRefChip(ref: ref),
          ],
        ),
        if (templateName.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Template: $templateName',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.75),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({required this.onFeedback});

  final void Function(String rating) onFeedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Was this useful?',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: () => onFeedback('helpful'),
          child: const Text('Helpful'),
        ),
        TextButton(
          onPressed: () => onFeedback('not_helpful'),
          child: const Text('Not helpful'),
        ),
        TextButton(
          onPressed: () => onFeedback('incorrect'),
          child: const Text('Report'),
        ),
      ],
    );
  }
}
