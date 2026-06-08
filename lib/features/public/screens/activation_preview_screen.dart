import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/system/widgets/activation_progression.dart';

/// Public preview of the activation progression chain.
///
/// Shows the 8-stage activation flow as a visual, ownership-aware,
/// state-aware progression — the same chain the client workspace
/// renders with live state when signed in. Used on the public site
/// to give visitors a concrete view of what setup looks like before
/// they commit, and as a procurement aid to evaluators.
class ActivationPreviewScreen extends StatelessWidget {
  const ActivationPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(theme: theme),
              const SizedBox(height: 24),
              buildActivationPreview(),
              const SizedBox(height: 24),
              _CrossLinks(theme: theme),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.publicAccentSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Activation progression',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppTheme.publicAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Eight stages from business identity to governed activation.',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(
              'The chain the platform walks every account through. Ownership is tagged per stage (Client vs Orchestrate); the readiness engine drives each stage forward in dependency order. Stripe checkout sets up the subscription first, the 15-day trial runs first when selected, and this same activation chain begins as soon as checkout completes. When signed in, the workspace renders the same chain with live state — there is no separate activation wizard sitting alongside the runtime.',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: AppTheme.publicMuted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrossLinks extends StatelessWidget {
  const _CrossLinks({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton(
          onPressed: () => context.go('/auth/join?trial=15d'),
          child: const Text('Start 15-Day Trial'),
        ),
        OutlinedButton(
          onPressed: () => context.go('/how-orchestrate-operates'),
          child: const Text('How Orchestrate operates'),
        ),
        OutlinedButton(
          onPressed: () => context.go('/trust-architecture'),
          child: const Text('Trust architecture'),
        ),
        TextButton(
          onPressed: () => context.go('/for-evaluators'),
          child: const Text('For evaluators →'),
        ),
      ],
    );
  }
}
