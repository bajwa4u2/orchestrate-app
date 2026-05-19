import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../widgets/operator_panel.dart';

/// AI approvals stub. The backend AI decision approval endpoints
/// exist under /ai/governance/decisions/* but require a richer
/// approval workflow than this pass scopes. Honest empty state
/// (OFD §5.1) — does not fabricate an approvals UI.
///
/// Wiring this surface to /ai/governance/decisions/pending is the
/// next iteration; this screen names exactly what is missing.
class AiApprovalsScreen extends StatelessWidget {
  const AiApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Governance',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppTheme.subdued)),
            const SizedBox(height: 4),
            Text('AI decision approvals',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
                'Surface for /ai/governance/decisions/pending. The backend endpoint exists; the operator approval workflow ships in the next iteration so this surface does not invent approvals state.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.muted, height: 1.35)),
          ],
        ),
        const SizedBox(height: 18),
        const OperatorEmptyState(
          title: 'AI approvals UI is not provisioned yet',
          body:
              'Backend endpoints: GET /ai/governance/decisions/pending and POST /ai/governance/decisions/:id/approve are available. This operator surface will render the queue and approval action in the next iteration. Per OPERATIONAL_FULFILLMENT_DIRECTIVE §5.1, nothing is shown that cannot be proven.',
          icon: Icons.gavel_outlined,
        ),
        const SizedBox(height: 18),
        OperatorPanel(
          title: 'Until then',
          subtitle:
              'Operator can review existing dispatch governance and the cognition feed (cost guardrails, suggestions, healing) on the Adaptation surfaces.',
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }
}
