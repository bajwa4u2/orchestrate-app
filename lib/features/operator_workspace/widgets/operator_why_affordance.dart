import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/guidance/guidance_drawer.dart';

/// Operator-side "Why?" affordance. Universal four-question contract
/// hook (OPERATOR_WORKSPACE_SPECIFICATION.md §3.3, §6).
///
/// Today this delegates to the existing client-mode guidance drawer
/// targets that already match the operator's supervision needs
/// (readiness, sending-identity, dispatch-governance, execution
/// states). When operator-scoped explain endpoints land under
/// /operator/guidance/* this widget is the one swap point.
class OperatorWhyAffordance extends StatelessWidget {
  const OperatorWhyAffordance({
    super.key,
    required this.target,
    this.surface,
    this.label = 'Why?',
  });

  final GuidanceTarget target;
  final String? surface;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => openGuidanceDrawer(
        context,
        target: target,
        surface: surface ?? 'operator_workspace',
      ),
      icon: const Icon(Icons.help_outline, size: 16, color: AppTheme.accent),
      label: Text(label,
          style: const TextStyle(color: AppTheme.accent, fontSize: 13)),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.accent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
