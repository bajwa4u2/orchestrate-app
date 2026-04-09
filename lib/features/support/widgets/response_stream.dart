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
                ? _UserMessageCard(message: message)
                : _SystemMessageCard(
                    message: message,
                    onFollowUpTap: onFollowUpTap,
                  ),
          ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _UserMessageCard extends StatelessWidget {
  const _UserMessageCard({required this.message});

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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.65),
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

class _SystemMessageCard extends StatelessWidget {
  const _SystemMessageCard({
    required this.message,
    required this.onFollowUpTap,
  });

  final SupportMessage message;
  final ValueChanged<String> onFollowUpTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalizedStatus = (message.status ?? '').trim().toLowerCase();
    final isReviewState = message.isEscalated ||
        message.caseCreated ||
        normalizedStatus == 'escalated' ||
        normalizedStatus == 'review' ||
        normalizedStatus == 'needs_review';

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isReviewState
                  ? scheme.primary.withValues(alpha: 0.30)
                  : scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StateHeader(
                status: message.status,
                isReviewState: isReviewState,
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
                      _MetaPill(label: _formatCategory(message.category!)),
                    if (message.priority != null && message.priority!.isNotEmpty)
                      _MetaPill(label: 'Priority: ${_formatLabel(message.priority!)}'),
                  ],
                ),
              ],
              if (isReviewState) ...[
                const SizedBox(height: 14),
                _ReviewStateCard(
                  caseCreated: message.caseCreated,
                  caseId: message.caseId,
                ),
              ],
              if (message.followUps.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Continue with one of these',
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
            ],
          ),
        ),
      ),
    );
  }
}

class _StateHeader extends StatelessWidget {
  const _StateHeader({
    required this.status,
    required this.isReviewState,
  });

  final String? status;
  final bool isReviewState;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = _statusTitle(status, isReviewState);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isReviewState ? scheme.primary : scheme.secondary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface.withValues(alpha: 0.85),
              ),
        ),
      ],
    );
  }
}

class _ReviewStateCard extends StatelessWidget {
  const _ReviewStateCard({
    required this.caseCreated,
    required this.caseId,
  });

  final bool caseCreated;
  final String? caseId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasCaseId = caseId != null && caseId!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caseCreated ? 'Under review' : 'Review state',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            caseCreated
                ? hasCaseId
                    ? 'A support case has been created for this issue. Reference: $caseId.'
                    : 'A support case has been created for this issue.'
                : 'This issue needs follow-up review.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

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

String _statusTitle(String? status, bool isReviewState) {
  final normalized = (status ?? '').trim().toLowerCase();
  if (isReviewState) return 'Needs review';
  if (normalized == 'resolved' || normalized == 'answered') return 'Answered';
  if (normalized == 'follow_up' || normalized == 'follow-up') {
    return 'Follow-up';
  }
  if (normalized == 'needs_follow_up' || normalized == 'needs-follow-up') {
    return 'Follow-up';
  }
  return 'Response';
}

String _formatCategory(String value) {
  return _formatLabel(value).replaceFirstMapped(
    RegExp(r'^[a-z]'),
    (match) => match.group(0)!.toUpperCase(),
  );
}

String _formatLabel(String value) {
  return value
      .trim()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}
