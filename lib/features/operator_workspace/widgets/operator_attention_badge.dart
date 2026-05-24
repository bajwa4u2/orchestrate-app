import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';

/// Sidebar attention badge. Zero-truthful: empty count renders no
/// badge (not "0"). Non-zero counts pulse a single warm dot next to
/// the faculty label.
class OperatorAttentionBadge extends StatelessWidget {
  const OperatorAttentionBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.coSun.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.coSun.withValues(alpha: 0.55)),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.coSun,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
      ),
    );
  }
}
