import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../widgets/operator_panel.dart';

/// Adaptation hub — landing for the Self-AI subsurfaces. Linked from
/// Cognition Home; routes to each per-row screen.
class AdaptationHubScreen extends StatelessWidget {
  const AdaptationHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _Header(),
        const SizedBox(height: 18),
        OperatorPanel(
          title: 'Convergence layer',
          subtitle:
              'Measures whether the substrate is actually saving AI work. Cache, escalations, AI economy.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HubTile(
                title: 'Convergence metrics',
                description:
                    'Reuse vs escalation, patterns confirmed, recovery success, playbook outcomes. Deterministic counts; no estimates.',
                route: '/ops/adaptation/convergence',
                tone: OperatorTone.positive,
              ),
              _HubTile(
                title: 'AI economy',
                description:
                    'Cache rows by source and model. Token + cost attribution. Active guardrails and breaches.',
                route: '/ops/adaptation/ai-economy',
                tone: OperatorTone.neutral,
              ),
              _HubTile(
                title: 'Escalations',
                description:
                    'Append-only record of why containment had to invoke AI. Filter by reason / severity / open.',
                route: '/ops/adaptation/escalations',
                tone: OperatorTone.caution,
              ),
              _HubTile(
                title: 'Reasoning cache',
                description:
                    'Durable cache of stored AI answers. Inspect hits, expiry, fingerprints. Invalidate stale entries.',
                route: '/ops/adaptation/reasoning-cache',
                tone: OperatorTone.neutral,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OperatorPanel(
          title: 'Self-AI substrate',
          subtitle:
              'Deterministic > memory > AI. Append-only. Nothing auto-applies — every learned change is operator-gated.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HubTile(
                title: 'Suggestions',
                description:
                    'PolicyAdjustmentSuggestion queue. Accept or reject; acceptance creates a SelfHealingAction.',
                route: '/ops/adaptation/suggestions',
                tone: OperatorTone.caution,
              ),
              _HubTile(
                title: 'Playbooks',
                description:
                    'OperationalPlaybook lifecycle (CANDIDATE → ACTIVE → DISABLED → ARCHIVED) and execution history + rollback. LEVEL_3 is reserved.',
                route: '/ops/adaptation/playbooks',
                tone: OperatorTone.neutral,
              ),
              _HubTile(
                title: 'Self-healing',
                description:
                    'SelfHealingAction audit trail. Reversible narrow-blast actions only.',
                route: '/ops/adaptation/healing',
                tone: OperatorTone.neutral,
              ),
              _HubTile(
                title: 'Cost guardrails',
                description:
                    'Tokens / USD / decisions / retries ceilings. Breaches surface deterministically.',
                route: '/ops/adaptation/guardrails',
                tone: OperatorTone.neutral,
              ),
              _HubTile(
                title: 'Patterns',
                description:
                    'RuntimePattern (CANDIDATE → CONFIRMED at threshold). Read-only; status changes are automatic.',
                route: '/ops/adaptation/patterns',
                tone: OperatorTone.neutral,
              ),
              _HubTile(
                title: 'Learning feed',
                description:
                    'LearningEvent timeline. Append-only journal. Operator-safe factsJson.',
                route: '/ops/adaptation/learning-feed',
                tone: OperatorTone.neutral,
              ),
              _HubTile(
                title: 'Operational memory',
                description:
                    'OperationalMemory key/value rollups derived from the journal.',
                route: '/ops/adaptation/memory',
                tone: OperatorTone.neutral,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Adaptation & Cognition',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.subdued)),
        const SizedBox(height: 4),
        Text('Governed adaptation',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
            'Operator-side surface for the Self-AI learning substrate. Open the row that needs attention.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.muted, height: 1.35)),
      ],
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.title,
    required this.description,
    required this.route,
    required this.tone,
  });

  final String title;
  final String description;
  final String route;
  final OperatorTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      OperatorTone.positive => AppTheme.coVerdant,
      OperatorTone.caution => AppTheme.coSun,
      OperatorTone.critical => AppTheme.coRose,
      OperatorTone.neutral => AppTheme.subdued,
    };
    return SizedBox(
      width: 320,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: () => context.go(route),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: AppTheme.panelRaised,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppTheme.lineSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title,
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.subdued, size: 18),
                  ],
                ),
                const SizedBox(height: 6),
                Text(description,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.muted, height: 1.35)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
