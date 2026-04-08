import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth/auth_session.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/client_portal_repository.dart';

class ClientSubscribeScreen extends StatefulWidget {
  const ClientSubscribeScreen({super.key});

  @override
  State<ClientSubscribeScreen> createState() => _ClientSubscribeScreenState();
}

class _ClientSubscribeScreenState extends State<ClientSubscribeScreen> {
  bool _loading = true;
  bool _subscribing = false;
  String? _error;

  String _planCode = 'opportunity';
  String _tierCode = 'focused';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    try {
      final uri = GoRouterState.of(context).uri;
      final session = AuthSessionController.instance;

      final queryPlan = uri.queryParameters['plan']?.trim().toLowerCase();
      final queryTier = uri.queryParameters['tier']?.trim().toLowerCase();

      final selectedPlan =
          (queryPlan != null && queryPlan.isNotEmpty) ? queryPlan : (session.selectedPlan ?? 'opportunity');
      final selectedTier =
          (queryTier != null && queryTier.isNotEmpty) ? queryTier : (session.selectedTier ?? 'focused');

      await session.rememberSelection(plan: selectedPlan, tier: selectedTier);

      if (!mounted) return;
      setState(() {
        _planCode = selectedPlan;
        _tierCode = selectedTier;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The subscription screen could not load right now.';
      });
    }
  }

  Future<void> _applySelection({
    String? plan,
    String? tier,
  }) async {
    final nextPlan = (plan ?? _planCode).trim().toLowerCase();
    final nextTier = (tier ?? _tierCode).trim().toLowerCase();

    await AuthSessionController.instance.rememberSelection(
      plan: nextPlan,
      tier: nextTier,
    );

    if (!mounted) return;
    setState(() {
      _planCode = nextPlan;
      _tierCode = nextTier;
      _error = null;
    });

    final target = Uri(
      path: '/client/subscribe',
      queryParameters: {
        'plan': nextPlan,
        'tier': nextTier,
      },
    ).toString();

    if (mounted) {
      context.go(target);
    }
  }

  Future<void> _activate() async {
    setState(() {
      _subscribing = true;
      _error = null;
    });

    try {
      await AuthSessionController.instance.rememberSelection(
        plan: _planCode,
        tier: _tierCode,
      );

      final response = await ClientPortalRepository().createSubscription(
        _planCode,
        _tierCode,
      );

      final url = response['checkoutUrl'];

      if (url == null || url.toString().isEmpty) {
        throw Exception('Missing checkout URL');
      }

      final launched = await launchUrl(
        Uri.parse(url.toString()),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Checkout launch failed');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Secure checkout could not open right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _subscribing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = _selectionFor(_planCode, _tierCode);

    return Scaffold(
      backgroundColor: AppTheme.publicBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SubscribeHero(),
                        const SizedBox(height: 18),
                        if (_error != null) ...[
                          _SubscribeBanner(message: _error!, error: true),
                          const SizedBox(height: 18),
                        ],
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 940;

                            final left = Column(
                              children: [
                                _SelectionCard(
                                  planCode: _planCode,
                                  tierCode: _tierCode,
                                  onPlanChanged: (value) => _applySelection(plan: value),
                                  onTierChanged: (value) => _applySelection(tier: value),
                                ),
                                const SizedBox(height: 18),
                                _PlanSummaryCard(selection: selection),
                              ],
                            );

                            final right = _ReadinessCard(
                              selection: selection,
                              onReviewAccount: () => context.go('/client/account'),
                              onReviewWorkspace: () => context.go('/client/workspace'),
                              onActivate: _subscribing ? null : _activate,
                              activating: _subscribing,
                            );

                            if (stacked) {
                              return Column(
                                children: [
                                  left,
                                  const SizedBox(height: 18),
                                  right,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 7, child: left),
                                const SizedBox(width: 18),
                                Expanded(flex: 5, child: right),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubscribeHero extends StatelessWidget {
  const _SubscribeHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscription',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.publicMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Activate your operating model',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.02,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            'Your setup is already in place. Confirm the service plan and market coverage you want active before secure checkout opens.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.planCode,
    required this.tierCode,
    required this.onPlanChanged,
    required this.onTierChanged,
  });

  final String planCode;
  final String tierCode;
  final ValueChanged<String> onPlanChanged;
  final ValueChanged<String> onTierChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose plan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PlanChoiceTile(
                  title: 'Opportunity',
                  subtitle: 'Lead generation to meetings',
                  selected: planCode == 'opportunity',
                  onTap: () => onPlanChanged('opportunity'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PlanChoiceTile(
                  title: 'Revenue',
                  subtitle: 'Execution plus billing continuity',
                  selected: planCode == 'revenue',
                  onTap: () => onPlanChanged('revenue'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Choose coverage',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          _TierChoiceRow(
            title: 'Focused',
            subtitle: 'One country across multiple regions',
            selected: tierCode == 'focused',
            onTap: () => onTierChanged('focused'),
          ),
          const SizedBox(height: 10),
          _TierChoiceRow(
            title: 'Multi-Market',
            subtitle: 'Multiple countries with broader regional reach',
            selected: tierCode == 'multi',
            onTap: () => onTierChanged('multi'),
          ),
          const SizedBox(height: 10),
          _TierChoiceRow(
            title: 'Precision',
            subtitle: 'Advanced geography control and market priority order',
            selected: tierCode == 'precision',
            onTap: () => onTierChanged('precision'),
          ),
        ],
      ),
    );
  }
}

class _PlanChoiceTile extends StatelessWidget {
  const _PlanChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.publicSurfaceSoft : const Color(0xFFF7F8F5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.publicText : AppTheme.publicLine,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.publicMuted,
                    height: 1.35,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierChoiceRow extends StatelessWidget {
  const _TierChoiceRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.publicSurfaceSoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.publicText : AppTheme.publicLine,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.publicMuted,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: selected ? AppTheme.publicText : AppTheme.publicMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({required this.selection});

  final _PlanSelection selection;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selection.planLabel} · ${selection.tierLabel}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            selection.priceLabel,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            selection.summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 22),
          Text(
            'What stays in motion',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: selection.scope
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8F5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppTheme.publicLine),
                    ),
                    child: Text(item),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 22),
          Text(
            'Coverage',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < selection.coverage.length; i++) ...[
            _CoveragePoint(label: selection.coverage[i]),
            if (i != selection.coverage.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CoveragePoint extends StatelessWidget {
  const _CoveragePoint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Icon(
            Icons.circle,
            size: 7,
            color: AppTheme.publicAccent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.selection,
    required this.onReviewAccount,
    required this.onReviewWorkspace,
    required this.onActivate,
    required this.activating,
  });

  final _PlanSelection selection;
  final VoidCallback onReviewAccount;
  final VoidCallback onReviewWorkspace;
  final VoidCallback? onActivate;
  final bool activating;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Before you continue',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            'You can activate now, or review your account and workspace first. Both remain available without losing your selection.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 20),
          _ActionRow(
            label: 'Review account',
            onTap: onReviewAccount,
          ),
          const SizedBox(height: 10),
          _ActionRow(
            label: 'Return to workspace',
            onTap: onReviewWorkspace,
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selection.planLabel} · ${selection.tierLabel}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  selection.priceLabel,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.publicMuted,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onActivate,
              child: Text(activating ? 'Opening checkout...' : 'Activate plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.publicText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.publicLine),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ],
      ),
    );
  }
}

class _SubscribeBanner extends StatelessWidget {
  const _SubscribeBanner({
    required this.message,
    required this.error,
  });

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error ? Colors.red.shade100 : Colors.green.shade100,
        ),
      ),
      child: Text(message),
    );
  }
}

class _PlanSelection {
  const _PlanSelection({
    required this.planCode,
    required this.tierCode,
    required this.planLabel,
    required this.tierLabel,
    required this.priceLabel,
    required this.summary,
    required this.scope,
    required this.coverage,
  });

  final String planCode;
  final String tierCode;
  final String planLabel;
  final String tierLabel;
  final String priceLabel;
  final String summary;
  final List<String> scope;
  final List<String> coverage;
}

_PlanSelection _selectionFor(String planCode, String tierCode) {
  final normalizedPlan = planCode.trim().toLowerCase();
  final normalizedTier = tierCode.trim().toLowerCase();

  final isRevenue = normalizedPlan == 'revenue';

  final planLabel = isRevenue ? 'Revenue' : 'Opportunity';

  final scope = isRevenue
      ? const [
          'lead sourcing',
          'outreach execution',
          'follow-ups',
          'meeting booking',
          'invoices',
          'payment tracking',
          'agreements',
          'statements',
        ]
      : const [
          'lead sourcing',
          'outreach execution',
          'follow-ups',
          'meeting booking',
        ];

  switch (normalizedTier) {
    case 'precision':
      return _PlanSelection(
        planCode: normalizedPlan,
        tierCode: normalizedTier,
        planLabel: planLabel,
        tierLabel: 'Precision',
        priceLabel: isRevenue ? '\$1,950.00 / month' : '\$975.00 / month',
        summary: isRevenue
            ? 'Precision coverage with the full revenue operating layer, from outreach into billing accountability.'
            : 'Advanced targeting for outbound execution where exact market control matters from the beginning.',
        scope: scope,
        coverage: const [
          'multiple countries',
          'multiple regions',
          'optional city and metro targeting',
          'include and exclude geography logic',
          'priority ordering across markets',
        ],
      );
    case 'multi':
      return _PlanSelection(
        planCode: normalizedPlan,
        tierCode: normalizedTier,
        planLabel: planLabel,
        tierLabel: 'Multi-Market',
        priceLabel: isRevenue ? '\$1,290.00 / month' : '\$645.00 / month',
        summary: isRevenue
            ? 'Multi-country execution with billing support, reminders, statements, and payment tracking attached.'
            : 'Structured outreach and follow-up across multiple countries without moving into billing operations.',
        scope: scope,
        coverage: const [
          'multiple countries',
          'multiple regions',
          'broader operating reach from the start',
        ],
      );
    default:
      return _PlanSelection(
        planCode: normalizedPlan,
        tierCode: 'focused',
        planLabel: planLabel,
        tierLabel: 'Focused',
        priceLabel: isRevenue ? '\$870.00 / month' : '\$435.00 / month',
        summary: isRevenue
            ? 'Focused outbound execution plus invoices, statements, and payment continuity.'
            : 'Lead generation, outreach, follow-up, and meeting booking within one operating market.',
        scope: scope,
        coverage: const [
          'one country',
          'multiple states or regions',
          'contained market execution',
        ],
      );
  }
}
