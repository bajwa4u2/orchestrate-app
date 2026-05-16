import 'package:flutter/material.dart';

import '../guidance_models.dart';

/// Small, low-emphasis chip identifying which backend subsystem the
/// guidance reply was grounded in. Surfaces explainability — the user
/// can see exactly where the answer came from.
class GuidanceRefChip extends StatelessWidget {
  const GuidanceRefChip({super.key, required this.ref});

  final GuidanceRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Tooltip(
        message: ref.detail,
        child: Text(
          ref.sourceLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
