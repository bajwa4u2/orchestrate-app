import 'package:flutter/material.dart';

import '../guidance_drawer.dart';

/// Small, low-emphasis "Why?" trigger placed next to a readiness
/// banner, blocked state, sending-identity record, or execution state.
/// Tapping it opens the guidance drawer pre-seeded with the right
/// explain target — no free-text required, no chat surface.
///
/// Doctrine: SYSTEM_GUIDANCE_SPECIFICATION.md §13.4 — inline guidance
/// hooks render explanations in place without forcing the user to
/// re-state context.
class WhyAffordance extends StatelessWidget {
  const WhyAffordance({
    super.key,
    required this.target,
    this.surface,
    this.label = 'Why?',
  });

  /// Explain target — one of the GuidanceTarget cases (readiness,
  /// sendingIdentity, dispatchGovernance, or a specific operational
  /// state kind).
  final GuidanceTarget target;

  /// Surface tag persisted for audit ("client_mailbox_screen",
  /// "client_outreach_banner", etc.).
  final String? surface;

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton.icon(
      onPressed: () =>
          openGuidanceDrawer(context, target: target, surface: surface),
      icon: Icon(Icons.help_outline, size: 16, color: theme.colorScheme.primary),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
