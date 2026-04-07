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
        final sequence = (data?['sequence'] as List? ?? const []).cast<dynamic>();

        final opportunity = _resolvePlan(plans, 'opportunity', fallbackAmountCents: 43500);
        final revenue = _resolvePlan(plans, 'revenue', fallbackAmountCents: 87000);

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroSection(onPrimary: () => _routePlan(context, 'opportunity')),
                    const SizedBox(height: 24),
                    _PlanCardsSection(
                      opportunity: opportunity,
                      revenue: revenue,
                      onChooseOpportunity: () => _routePlan(context, 'opportunity'),
                      onChooseRevenue: () => _routePlan(context, 'revenue'),
                    ),
                    const SizedBox(height: 24),
                    _SequenceSection(sequence: sequence),
                    const SizedBox(height: 24),
                    _EngagementSection(),
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
      'summary': code == 'revenue'
          ? 'Everything in Opportunity plus billing and revenue operations.'
          : 'Lead generation, outreach, follow-up, and meeting booking.',
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

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onPrimary});

  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 940;

          final lead = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow(label: 'Pricing'),
              const SizedBox(height: 18),
              Text(
                'Choose the operating lane, then activate it properly',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 44,
                    ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  'Public pricing should do one job clearly: select the right plan, create the account, complete operating profile setup, then activate subscription and begin service.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.publicMuted,
                      ),
                ),
              ),
            ],
          );

          final aside = Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.publicSurfaceSoft,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This is not a vague pricing brochure. It is the front door into a real client flow.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.publicMuted,
                      ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onPrimary,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppTheme.publicText,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Choose a plan'),
                ),
              ],
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [lead, const SizedBox(height: 22), aside],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: lead),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: aside),
            ],
          );
        },
      ),
    );
  }
}

class _PlanCardsSection extends StatelessWidget {
  const _PlanCardsSection({
    required this.opportunity,
    required this.revenue,
    required this.onChooseOpportunity,
    required this.onChooseRevenue,
  });

  final Map<String, dynamic> opportunity;
  final Map<String, dynamic> revenue;
  final VoidCallback onChooseOpportunity;
  final VoidCallback onChooseRevenue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 900;

        final opportunityCard = _PlanCard(
          plan: opportunity,
          points: const [
            'Lead sourcing and targeting',
            'Outbound outreach execution',
            'Follow-up handling',
            'Reply management',
            'Meeting booking',
          ],
          onChoose: onChooseOpportunity,
        );

        final revenueCard = _PlanCard(
          plan: revenue,
          points: const [
            'Everything included in Opportunity',
            'Invoice generation and payment tracking',
            'Reminder scheduling and follow-through',
            'Statements and account records',
            'Agreements and billing support tied to service delivery',
          ],
          onChoose: onChooseRevenue,
        );

        if (stacked) {
          return Column(
            children: [
              opportunityCard,
              const SizedBox(height: 18),
              revenueCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: opportunityCard),
            const SizedBox(width: 18),
            Expanded(child: revenueCard),
          ],
        );
      },
    );
  }
}

class _SequenceSection extends StatelessWidget {
  const _SequenceSection({required this.sequence});

  final List<dynamic> sequence;

  @override
  Widget build(BuildContext context) {
    final steps = sequence.isEmpty
        ? const [
            'Choose plan',
            'Create account',
            'Verify email',
            'Define operating profile',
            'Activate subscription',
            'Begin service',
          ]
        : sequence.map((item) => item.toString()).toList(growable: false);

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
          Text('What happens next', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < steps.length; i++)
                Chip(label: Text('${i + 1}. ${steps[i]}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _EngagementSection extends StatelessWidget {
  const _EngagementSection();

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
          Text('How the plans differ', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Opportunity is outbound execution. Revenue extends that execution into billing, reminders, statements, and account continuity. The plan selected here becomes part of the operating profile and later AI work configuration.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.points,
    required this.onChoose,
  });

  final Map<String, dynamic> plan;
  final List<String> points;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final amount = ((plan['amountCents'] as num?) ?? 0) / 100;
    final name = plan['name']?.toString() ?? 'Plan';
    final summary = plan['summary']?.toString() ?? '';
    final code = plan['code']?.toString().toLowerCase() ?? '';

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
          Text(name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '\$${amount.toStringAsFixed(2)} / month',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          for (var i = 0; i < points.length; i++) ...[
            _BulletPoint(text: points[i]),
            if (i != points.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onChoose,
              child: Text('Choose ${code == 'revenue' ? 'Revenue' : 'Opportunity'}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Icon(
            Icons.circle,
            size: 8,
            color: AppTheme.publicAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.publicAccentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.publicAccent,
            ),
      ),
    );
  }
}
