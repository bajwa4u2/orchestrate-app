import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../widgets/operator_panel.dart';

/// Platform Supervision faculty. The doctrine requires a clear
/// distinction between tenant operator (single-org scope) and
/// platform operator (cross-org scope). The role + endpoints land
/// in a later phase; this surface renders an honest empty state
/// per OFD §5.1 rather than fabricating cross-tenant aggregation.
class PlatformSupervisionScreen extends StatelessWidget {
  const PlatformSupervisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Supervision',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppTheme.subdued)),
            const SizedBox(height: 4),
            Text('Cross-tenant operator role',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
                'Cross-tenant supervision (systemic incidents, provider-wide degradation, multi-org operator role) requires a platform-operator role that has not been provisioned in this deployment yet.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.muted, height: 1.35)),
          ],
        ),
        const SizedBox(height: 18),
        const OperatorEmptyState(
          title: 'No platform-operator role is provisioned',
          body:
              'Every operator endpoint today is single-organization-scoped. When the platform-operator role lands, this faculty will render cross-tenant risk, provider-wide incidents, and the org switcher above the shell. Per OPERATIONAL_FULFILLMENT_DIRECTIVE §5.1, no cross-tenant state is shown until it can be proven.',
          icon: Icons.public_outlined,
        ),
        const SizedBox(height: 18),
        OperatorPanel(
          title: 'What this faculty will contain',
          subtitle: 'Per OPERATOR_WORKSPACE_SPECIFICATION §4.1.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in const [
                'Cross-tenant risk: which organizations share a degrading provider, DNS regression, deliverability drift, or governance-blocked cohort.',
                'Provider-wide incidents: composed Google / Microsoft / SMTP health across all tenants.',
                'Org footprint: per-tenant supervision rollup.',
                'Org switcher at shell top bar (platform operator only).',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 7),
                        decoration: const BoxDecoration(
                          color: AppTheme.subdued,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(line,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.muted)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}
