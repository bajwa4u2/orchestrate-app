import 'package:flutter/material.dart';

import '../models/support_message.dart';
import 'followup_chips.dart';

class ResponseStream extends StatelessWidget {
  final List<SupportMessage> messages;
  final bool isLoading;
  final ValueChanged<String> onFollowUpTap;

  const ResponseStream({
    super.key,
    required this.messages,
    required this.isLoading,
    required this.onFollowUpTap,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !isLoading) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final message in messages)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: message.role == 'user'
                ? _UserMessageBlock(message: message)
                : _SystemMessageBlock(
                    message: message,
                    onFollowUpTap: onFollowUpTap,
                  ),
          ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: _LoadingBlock(),
          ),
      ],
    );
  }
}

class _UserMessageBlock extends StatelessWidget {
  const _UserMessageBlock({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(message.content),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemMessageBlock extends StatelessWidget {
  const _SystemMessageBlock({
    required this.message,
    required this.onFollowUpTap,
  });

  final SupportMessage message;
  final ValueChanged<String> onFollowUpTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusKey = _normalizeStatus(message.status);
    final isReviewState = message.isEscalated || message.caseCreated || statusKey == 'escalated';
    final isFollowUpState = message.followUps.isNotEmpty || statusKey == 'follow_up';
    final isResolvedState = statusKey == 'resolved' || statusKey == 'answered';

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isReviewState
                  ? scheme.outline.withOpacity(0.8)
                  : scheme.outlineVariant.withOpacity(0.55),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StateHeader(
                label: _stateLabel(
                  isReviewState: isReviewState,
                  isFollowUpState: isFollowUpState,
                  isResolvedState: isResolvedState,
                ),
              ),
              const SizedBox(height: 12),
              Text(message.content),
              if (message.category != null || message.priority != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (message.category != null && message.category!.isNotEmpty)
                      _MetaPill(label: message.category!),
                    if (message.priority != null && message.priority!.isNotEmpty)
                      _MetaPill(label: 'Priority: ${message.priority}'),
                  ],
                ),
              ],
              if (isReviewState) ...[
                const SizedBox(height: 14),
                _ReviewStateBlock(message: message),
              ],
              if (message.followUps.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Next details',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 10),
                FollowUpChips(
                  items: message.followUps,
                  onTap: onFollowUpTap,
                ),
              ],
              if (isResolvedState && !isReviewState) ...[
                const SizedBox(height: 14),
                _ResolvedStateBlock(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _normalizeStatus(String? value) {
    if (value == null) return '';
    final normalized = value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (normalized == 'needs_follow_up') return 'follow_up';
    return normalized;
  }

  static String _stateLabel({
    required bool isReviewState,
    required bool isFollowUpState,
    required bool isResolvedState,
  }) {
    if (isReviewState) return 'Under review';
    if (isFollowUpState) return 'Follow-up';
    if (isResolvedState) return 'Response';
    return 'Support';
  }
}

class _StateHeader extends StatelessWidget {
  const _StateHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ReviewStateBlock extends StatelessWidget {
  const _ReviewStateBlock({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caseId = message.caseId?.trim() ?? '';
    final hasCaseId = caseId.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasCaseId ? 'Case created' : 'Review in progress',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            hasCaseId
                ? 'Reference: $caseId'
                : 'We captured this for follow-up and will continue from the same thread.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ResolvedStateBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.45)),
      ),
      child: Text(
        'You can continue here if you need anything else.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Working on it',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;

  const _MetaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
