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

    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final message in messages)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: message.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: message.role == 'user'
                        ? scheme.surfaceContainerHigh
                        : scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message.content),
                      if (message.role == 'system' &&
                          (message.category != null || message.priority != null)) ...[
                        const SizedBox(height: 10),
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
                      if (message.followUps.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        FollowUpChips(
                          items: message.followUps,
                          onTap: onFollowUpTap,
                        ),
                      ],
                      if (message.isEscalated || message.caseCreated) ...[
                        const SizedBox(height: 12),
                        Text(
                          message.caseCreated && (message.caseId?.isNotEmpty ?? false)
                              ? 'A case has been created. Reference: ${message.caseId}.'
                              : 'We’ll review this and follow up shortly.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
