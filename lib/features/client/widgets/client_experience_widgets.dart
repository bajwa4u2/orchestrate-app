import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/client/models/client_experience.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

/// Outcome-confidence surfaces for the client workspace.
///
/// These widgets render the client experience as a managed
/// business-growth story — momentum, confidence, and the one step
/// (if any) the client genuinely owns. They never render runtime or
/// diagnostic semantics; that truth lives only in the operator
/// workspace.

Color _toneColor(String tone) {
  switch (tone) {
    case 'attention':
      return AppTheme.coSun;
    case 'positive':
    case 'progressing':
    default:
      return AppTheme.publicAccent;
  }
}

Color _toneSoft(String tone) {
  switch (tone) {
    case 'attention':
      return AppTheme.publicAmberSoft;
    case 'positive':
    case 'progressing':
    default:
      return AppTheme.publicAccentSoft;
  }
}

/// The prominent momentum card — the client's "where is my growth
/// right now" headline. Used as the lead surface on Home and
/// Operations.
class ClientMomentumCard extends StatelessWidget {
  const ClientMomentumCard({
    super.key,
    required this.experience,
    this.eyebrow,
    this.onAction,
  });

  final ClientExperience experience;
  final String? eyebrow;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _toneColor(experience.tone);
    final action = experience.clientAction;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radius),
                topRight: Radius.circular(AppTheme.radius),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration:
                          BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      (eyebrow ?? 'Your growth operation').toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.publicMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  experience.headline,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  experience.narrative,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: AppTheme.publicText, height: 1.4),
                ),
                if (experience.ownershipLine.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    experience.ownershipLine,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppTheme.publicMuted),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _toneSoft(experience.tone),
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: accent.withOpacity(0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(action.title,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Text(action.message,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.publicText)),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: onAction,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: Text(action.ctaLabel),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Truthful confidence panel — what Orchestrate has operating for
/// the client's business. Every signal state is a real fact.
class ClientConfidencePanel extends StatelessWidget {
  const ClientConfidencePanel({super.key, required this.signals});

  final List<ClientConfidenceSignal> signals;

  @override
  Widget build(BuildContext context) {
    if (signals.isEmpty) {
      return const ClientPanel(
        title: 'Operational confidence',
        subtitle: 'What Orchestrate has running for your business.',
        children: [
          ClientEmptyState(
            message: 'Your growth operation is coming online.',
          ),
        ],
      );
    }
    return ClientPanel(
      title: 'Operational confidence',
      subtitle: 'What Orchestrate has running for your business.',
      children: [
        for (var i = 0; i < signals.length; i++) ...[
          ClientInfoRow(
            title: signals[i].label,
            primary: signals[i].detail,
            trailing: _ConfidencePill(state: signals[i].state),
          ),
          if (i != signals.length - 1) const Divider(height: 18),
        ],
      ],
    );
  }
}

class _ConfidencePill extends StatelessWidget {
  const _ConfidencePill({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (state) {
      'active' => (
          'Active',
          AppTheme.publicAccent,
          AppTheme.publicAccentSoft,
        ),
      'attention' => (
          'Your input',
          AppTheme.coSun,
          AppTheme.publicAmberSoft,
        ),
      _ => (
          'In progress',
          AppTheme.publicMuted,
          AppTheme.publicSurfaceSoft,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
