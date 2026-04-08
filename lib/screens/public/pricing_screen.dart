import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/public_repository.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = PublicRepository().fetchPricing();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final plans = (data?['plans'] as List? ?? const []).cast<dynamic>();

        final opportunity = _resolvePlan(plans, 'opportunity', fallbackAmountCents: 43500);
        final revenue = _resolvePlan(plans, 'revenue', fallbackAmountCents: 87000);

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Hero(),
                    const SizedBox(height: 28),
                    _PlanCards(
                      opportunity: opportunity,
                      revenue: revenue,
                      onOpportunity: () => _routePlan(context, 'opportunity'),
                      onRevenue: () => _routePlan(context, 'revenue'),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Text(
                        'You can expand coverage and capabilities anytime.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.publicMuted,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _resolvePlan(List<dynamic> plans, String code, {required int fallbackAmountCents}) {
    for (final raw in plans) {
      final plan = Map<String, dynamic>.from(raw as Map);
      if (plan['code']?.toString().toLowerCase() == code) return plan;
    }

    return {
      'code': code,
      'name': code == 'revenue' ? 'Revenue' : 'Opportunity',
      'amountCents': fallbackAmountCents,
    };
  }

  void _routePlan(BuildContext context, String plan) {
    final session = AuthSessionController.instance;

    final joinRoute = Uri(path: '/client/join', queryParameters: {'plan': plan}).toString();
    final setupRoute = Uri(path: '/client/setup', queryParameters: {'plan': plan}).toString();
    final subscribeRoute = Uri(path: '/client/subscribe', queryParameters: {'plan': plan}).toString();

    if (!session.isAuthenticated || session.surface != 'client') {
      context.go(joinRoute);
      return;
    }

    session.rememberSelectedPlan(plan);

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

class _Hero extends StatelessWidget {
  const _Hero();

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
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Start with outbound execution or extend into revenue and billing.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _PlanCards extends StatelessWidget {
  const _PlanCards({
    required this.opportunity,
    required this.revenue,
    required this.onOpportunity,
    required this.onRevenue,
  });

  final Map<String, dynamic> opportunity;
  final Map<String, dynamic> revenue;
  final VoidCallback onOpportunity;
  final VoidCallback onRevenue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 780;

        final cards = [
          _PlanCard(
            title: 'Opportunity',
            price: opportunity,
            description: 'Outbound execution from lead to meeting.',
            button: 'Start Opportunity',
            onTap: onOpportunity,
          ),
          _PlanCard(
            title: 'Revenue',
            price: revenue,
            description: 'Outbound plus billing, payments, and records.',
            button: 'Start Revenue',
            onTap: onRevenue,
            highlighted: True,
          ),
        ];

        if (stacked) {
          return Column(
            children: [
              cards[0],
              const SizedBox(height: 16),
              cards[1],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 16),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.description,
    required this.button,
    required this.onTap,
    this.highlighted = false,
  });

  final String title;
  final Map<String, dynamic> price;
  final String description;
  final String button;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final amount = ((price['amountCents'] as num?) ?? 0) / 100;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: highlighted ? AppTheme.publicSurfaceSoft : AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '\$${amount.toStringAsFixed(2)} / month',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTap,
              child: Text(button),
            ),
          ),
        ],
      ),
    );
  }
}
