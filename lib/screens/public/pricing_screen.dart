// Full replacement: pricing_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/theme/app_theme.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  String _selectedPlan = 'opportunity';

  @override
  Widget build(BuildContext context) {
    const tiers = _pricingTiers;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PricingHero(),
                const SizedBox(height: 22),
                _PlanSwitch(
                  selectedPlan: _selectedPlan,
                  onChanged: (value) => setState(() => _selectedPlan = value),
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 980;
                    if (stacked) {
                      return Column(
                        children: [
                          for (int i = 0; i < tiers.length; i++) ...[
                            _TierCard(
                              tier: tiers[i],
                              selectedPlan: _selectedPlan,
                              onSelect: (tierCode) => _routeSelection(
                                context,
                                plan: _selectedPlan,
                                tier: tierCode,
                              ),
                            ),
                            if (i != tiers.length - 1) const SizedBox(height: 16),
                          ],
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < tiers.length; i++) ...[
                          Expanded(
                            child: _TierCard(
                              tier: tiers[i],
                              selectedPlan: _selectedPlan,
                              onSelect: (tierCode) => _routeSelection(
                                context,
                                plan: _selectedPlan,
                                tier: tierCode,
                              ),
                            ),
                          ),
                          if (i != tiers.length - 1) const SizedBox(width: 16),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                const _PricingFootnote(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _routeSelection(
    BuildContext context, {
    required String plan,
    required String tier,
  }) async {
    final session = AuthSessionController.instance;

    await session.rememberSelection(plan: plan, tier: tier);

    final joinRoute = Uri(
      path: '/client/join',
      queryParameters: {'plan': plan, 'tier': tier},
    ).toString();
    final setupRoute = Uri(
      path: '/client/setup',
      queryParameters: {'plan': plan, 'tier': tier},
    ).toString();
    final subscribeRoute = Uri(
      path: '/client/subscribe',
      queryParameters: {'plan': plan, 'tier': tier},
    ).toString();

    if (!mounted) return;

    if (!session.isAuthenticated || session.surface != 'client') {
      context.go(joinRoute);
      return;
    }

    if (!session.emailVerified) {
      context.go('/client/verify-email');
      return;
    }
    if (!session.hasSetupCompleted) {
      context.go(setupRoute);
      return;
    }
    if (session.normalizedSubscriptionStatus != 'active') {
      context.go(subscribeRoute);
      return;
    }

    context.go('/client/workspace');
  }
}

class _PricingHero extends StatelessWidget {
  const _PricingHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose how you want to operate',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select the service model first, then choose the market coverage that matches how broadly you need to work.',
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

class _PlanSwitch extends StatelessWidget {
  const _PlanSwitch({
    required this.selectedPlan,
    required this.onChanged,
  });

  final String selectedPlan;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PlanSwitchButton(
              title: 'Opportunity',
              subtitle: 'Lead generation to meetings',
              selected: selectedPlan == 'opportunity',
              onTap: () => onChanged('opportunity'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PlanSwitchButton(
              title: 'Revenue',
              subtitle: 'Execution plus billing continuity',
              selected: selectedPlan == 'revenue',
              onTap: () => onChanged('revenue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSwitchButton extends StatelessWidget {
  const _PlanSwitchButton({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.publicText : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.selectedPlan,
    required this.onSelect,
  });

  final _TierDefinition tier;
  final String selectedPlan;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final option = tier.options[selectedPlan]!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tier.highlighted ? AppTheme.publicSurfaceSoft : AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: tier.highlighted
              ? AppTheme.publicText.withOpacity(0.18)
              : AppTheme.publicLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tier.label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            tier.scopeLine,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          Text(
            option.priceLabel,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            option.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          for (int i = 0; i < tier.points.length; i++) ...[
            _TierPoint(label: tier.points[i]),
            if (i != tier.points.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => onSelect(tier.code),
              child: Text(option.ctaLabel),
            ),
          ),
          if (tier.note != null) ...[
            const SizedBox(height: 12),
            Text(
              tier.note!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TierPoint extends StatelessWidget {
  const _TierPoint({required this.label});

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

class _PricingFootnote extends StatelessWidget {
  const _PricingFootnote();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'You can begin with a narrower operating scope and move into broader coverage later without changing the service model.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.publicMuted,
            ),
      ),
    );
  }
}

class _TierDefinition {
  const _TierDefinition({
    required this.code,
    required this.label,
    required this.scopeLine,
    required this.points,
    required this.options,
    this.note,
    this.highlighted = false,
  });

  final String code;
  final String label;
  final String scopeLine;
  final List<String> points;
  final Map<String, _PlanOption> options;
  final String? note;
  final bool highlighted;
}

class _PlanOption {
  const _PlanOption({
    required this.priceLabel,
    required this.summary,
    required this.ctaLabel,
  });

  final String priceLabel;
  final String summary;
  final String ctaLabel;
}

const List<_TierDefinition> _pricingTiers = [
  _TierDefinition(
    code: 'focused',
    label: 'Focused',
    scopeLine: 'One country with multiple regions and a clean operating start.',
    points: [
      'Single-country coverage',
      'Multiple states or regions',
      'Best for contained market execution',
    ],
    options: {
      'opportunity': _PlanOption(
        priceLabel: '\$435.00 / month',
        summary: 'Lead generation, outreach, follow-up, and meeting booking within one operating market.',
        ctaLabel: 'Start Focused Opportunity',
      ),
      'revenue': _PlanOption(
        priceLabel: '\$870.00 / month',
        summary: 'Focused outbound execution plus invoices, statements, and payment continuity.',
        ctaLabel: 'Start Focused Revenue',
      ),
    },
  ),
  _TierDefinition(
    code: 'multi',
    label: 'Multi-Market',
    scopeLine: 'Multiple countries with broader regional coverage from the start.',
    points: [
      'Multi-country coverage',
      'Multiple regions across markets',
      'Built for broader operating reach',
    ],
    options: {
      'opportunity': _PlanOption(
        priceLabel: '\$645.00 / month',
        summary: 'Structured outreach and follow-up across multiple countries without moving into billing operations.',
        ctaLabel: 'Start Multi-Market Opportunity',
      ),
      'revenue': _PlanOption(
        priceLabel: '\$1,290.00 / month',
        summary: 'Multi-country execution with billing support, reminders, statements, and payment tracking attached.',
        ctaLabel: 'Start Multi-Market Revenue',
      ),
    },
    highlighted: true,
    note: 'Most balanced for teams running across more than one market.',
  ),
  _TierDefinition(
    code: 'precision',
    label: 'Precision',
    scopeLine: 'Advanced market control with city-level targeting and priority order.',
    points: [
      'Optional city and metro targeting',
      'Include and exclude geography logic',
      'Priority ordering across markets',
    ],
    options: {
      'opportunity': _PlanOption(
        priceLabel: '\$975.00 / month',
        summary: 'Advanced targeting for outbound execution where exact market control matters from the beginning.',
        ctaLabel: 'Start Precision Opportunity',
      ),
      'revenue': _PlanOption(
        priceLabel: '\$1,950.00 / month',
        summary: 'Precision coverage with the full revenue operating layer, from outreach into billing accountability.',
        ctaLabel: 'Start Precision Revenue',
      ),
    },
  ),
];
