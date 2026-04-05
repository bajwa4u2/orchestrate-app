import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroSection(),
                SizedBox(height: 24),
                _PlanCardsSection(),
                SizedBox(height: 24),
                _PricingDriversSection(),
                SizedBox(height: 24),
                _EngagementSection(),
                SizedBox(height: 24),
                _NextStepSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final lead = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow(label: 'Pricing'),
        const SizedBox(height: 18),
        Text(
          'Two ways to work together',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 46,
              ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            'Orchestrate is structured around two engagement models depending on whether you need outbound execution only or outbound execution with billing support.',
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
            'This is a commercial framing page, not a fake self-serve checkout. Cost depends on scope, volume, and the amount of execution carried by the system.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => context.go('/client/join'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppTheme.publicText,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Create account'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go('/contact'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: AppTheme.publicText,
              side: const BorderSide(color: AppTheme.publicLine),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Contact'),
          ),
        ],
      ),
    );

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

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                lead,
                const SizedBox(height: 22),
                aside,
              ],
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
  const _PlanCardsSection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 900;

        final opportunity = _PlanCard(
          title: 'Opportunity',
          body: 'For businesses that want lead generation, outreach, follow-up, and meetings handled with structure.',
          points: const [
            'Lead sourcing and targeting',
            'Outbound outreach execution',
            'Follow-up handling',
            'Reply management',
            'Meeting booking',
          ],
        );

        final revenue = _PlanCard(
          title: 'Revenue',
          body:
              'For businesses that want the outbound work plus the billing, reminder, payment, and record layer that follows service delivery.',
          points: const [
            'Everything included in Opportunity',
            'Invoice generation and payment tracking',
            'Reminder scheduling and follow-through',
            'Statements and account records',
            'Agreements and billing support tied to service delivery',
          ],
          highlight:
              'Revenue is the fuller operating model because it carries the work from outreach into actual money movement and accountability.',
        );

        if (stacked) {
          return Column(
            children: [
              opportunity,
              const SizedBox(height: 18),
              revenue,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: opportunity),
            const SizedBox(width: 18),
            Expanded(child: revenue),
          ],
        );
      },
    );
  }
}

class _PricingDriversSection extends StatelessWidget {
  const _PricingDriversSection();

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
            'What determines pricing',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Pricing depends on volume, scope, and execution depth. The model tells you how the work is carried. The commercial structure is then set by the actual operating load.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          const _BulletPoint(text: 'How much outreach volume needs to be carried each month.'),
          const SizedBox(height: 12),
          const _BulletPoint(text: 'How targeted or complex the market and lead criteria are.'),
          const SizedBox(height: 12),
          const _BulletPoint(text: 'Whether reply handling and meeting coordination stay light or become ongoing.'),
          const SizedBox(height: 12),
          const _BulletPoint(text: 'Whether billing support, reminders, statements, and records are part of the engagement.'),
          const SizedBox(height: 12),
          const _BulletPoint(text: 'Whether the work is campaign-based, ongoing, or operationally embedded.'),
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
          Text(
            'How engagement is defined',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'The model tells you how the system works. Scope is shaped based on your stage, target market, and volume of work, then finalized during onboarding.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          const _BulletPoint(text: 'Opportunity is for outbound execution only.'),
          const SizedBox(height: 12),
          const _BulletPoint(text: 'Revenue includes outbound execution plus billing support.'),
          const SizedBox(height: 12),
          const _BulletPoint(text: 'Scope is confirmed during onboarding, not assumed from a public page.'),
        ],
      ),
    );
  }
}

class _NextStepSection extends StatelessWidget {
  const _NextStepSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 900;
          final textBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next step',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'If you already know you want to move forward, create an account. If you need to clarify fit, workload, or commercial structure first, use the contact page.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.publicMuted,
                    ),
              ),
            ],
          );

          final actions = Column(
            children: [
              FilledButton(
                onPressed: () => context.go('/client/join'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppTheme.publicText,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Create account'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/contact'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppTheme.publicText,
                  side: const BorderSide(color: AppTheme.publicLine),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Contact'),
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [textBlock, const SizedBox(height: 20), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: textBlock),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.body,
    required this.points,
    this.highlight,
  });

  final String title;
  final String body;
  final List<String> points;
  final String? highlight;

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
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          for (var i = 0; i < points.length; i++) ...[
            _BulletPoint(text: points[i]),
            if (i != points.length - 1) const SizedBox(height: 12),
          ],
          if (highlight != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.publicAccentSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                highlight!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.publicText,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
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
