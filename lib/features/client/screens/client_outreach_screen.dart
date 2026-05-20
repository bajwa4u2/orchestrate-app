import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/client/models/client_experience.dart';
import 'package:orchestrate_app/features/client/widgets/client_experience_widgets.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';
import 'package:orchestrate_app/features/guidance/guidance_drawer.dart';
import 'package:orchestrate_app/features/guidance/widgets/why_affordance.dart';

/// Operations — a managed business-growth surface.
///
/// Operations shows the client what Orchestrate is doing for their
/// business: outreach momentum, operational confidence, growth
/// numbers, and the single step (if any) the client genuinely owns.
/// It renders the client-safe experience surface only — never
/// readiness chains, dispatch governance, pacing, recovery, or any
/// runtime/diagnostic semantics. That truth lives in the operator
/// workspace.
class ClientOutreachScreen extends StatefulWidget {
  const ClientOutreachScreen({super.key});

  @override
  State<ClientOutreachScreen> createState() => _ClientOutreachScreenState();
}

class _ClientOutreachScreenState extends State<ClientOutreachScreen> {
  final ClientPortalRepository _repository = ClientPortalRepository();
  late Future<ClientExperience> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchClientExperience();
  }

  void _refresh() {
    setState(() => _future = _repository.fetchClientExperience());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ClientExperience>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(
            eyebrow: 'Operations',
            label: 'Loading your growth operation',
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Operations is temporarily unavailable',
            onRetry: _refresh,
          );
        }
        final experience = snapshot.data!;
        final growth = experience.growth;
        final action = experience.clientAction;
        return ClientPage(
          eyebrow: 'Operations',
          title: experience.headline,
          subtitle: experience.narrative,
          banner: action == null
              ? null
              : ClientStatusBanner(
                  tone: _bannerTone(experience.tone),
                  title: action.title,
                  message: action.message,
                  actionLabel: action.ctaLabel,
                  onAction: () => context.go(action.route),
                ),
          actions: _buildActions(context, experience),
          children: [
            _OwnershipNote(line: experience.ownershipLine),
            const SizedBox(height: 18),
            ClientMetricStrip(metrics: [
              ClientMetric(
                  'Opportunities', '${growth.opportunitiesIdentified}'),
              ClientMetric('In market', '${growth.opportunitiesInMarket}'),
              ClientMetric('Conversations', '${growth.conversationsActive}'),
              ClientMetric('Meetings', '${growth.meetingsCoordinated}'),
            ]),
            const SizedBox(height: 18),
            ClientConfidencePanel(signals: experience.confidenceSignals),
            const SizedBox(height: 18),
            _EngagementPanel(growth: growth),
          ],
        );
      },
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    ClientExperience experience,
  ) {
    final widgets = <Widget>[];
    if (experience.growth.conversationsActive > 0) {
      widgets.add(
        OutlinedButton.icon(
          onPressed: () => context.go('/client/replies'),
          icon: const Icon(Icons.forum_outlined, size: 18),
          label: const Text('Review conversations'),
        ),
      );
    }
    widgets.add(
      WhyAffordance(
        target: GuidanceTarget.readiness,
        surface: 'client_operations_experience',
        label: 'Explain this',
      ),
    );
    return widgets;
  }

  ClientBannerTone _bannerTone(String tone) {
    switch (tone) {
      case 'attention':
        return ClientBannerTone.warning;
      case 'positive':
        return ClientBannerTone.success;
      default:
        return ClientBannerTone.info;
    }
  }
}

/// A calm, reassuring one-liner naming who owns the next step.
class _OwnershipNote extends StatelessWidget {
  const _OwnershipNote({required this.line});
  final String line;

  @override
  Widget build(BuildContext context) {
    if (line.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined,
              size: 18, color: AppTheme.publicMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(line,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _EngagementPanel extends StatelessWidget {
  const _EngagementPanel({required this.growth});
  final ClientGrowth growth;

  @override
  Widget build(BuildContext context) {
    return ClientPanel(
      title: 'Engagement',
      subtitle: 'Conversations and meetings Orchestrate is coordinating.',
      children: [
        ClientInfoRow(
          title: 'Conversations',
          primary: growth.conversationsActive > 0
              ? '${growth.conversationsActive} active conversations underway.'
              : 'Conversations appear here as businesses reply.',
          trailing: FilledButton.tonal(
            onPressed: () => context.go('/client/replies'),
            child: const Text('Open'),
          ),
        ),
        const Divider(height: 18),
        ClientInfoRow(
          title: 'Meetings',
          primary: growth.meetingsCoordinated > 0
              ? '${growth.meetingsCoordinated} meetings being coordinated.'
              : 'Meetings appear here as conversations progress.',
          trailing: FilledButton.tonal(
            onPressed: () => context.go('/client/meetings'),
            child: const Text('Open'),
          ),
        ),
      ],
    );
  }
}
