import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../widgets/public_overview_widget.dart';

class PublicHomeScreen extends StatelessWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _HeroSection(),
              SizedBox(height: 24),
              PublicOverviewWidget(),
              SizedBox(height: 24),
              _ProcessSection(),
              SizedBox(height: 24),
              _WhyItHoldsSection(),
              SizedBox(height: 24),
              _TrustStrip(),
            ],
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
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;

          final lead = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.publicAccentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Outbound revenue operations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.publicAccent,
                      ),
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  'From outreach to revenue, carried in one system.',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: compact ? 44 : 52,
                        height: 1.02,
                        letterSpacing: -1.2,
                      ),
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  'Orchestrate runs outbound work as one connected operating flow, from market coverage and outreach through meetings, billing, reminders, and records.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppTheme.publicMuted, height: 1.45),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: () => context.go('/join'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.publicText,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Create account'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/pricing'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.publicText,
                      backgroundColor: AppTheme.publicSurfaceSoft,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.publicLine),
                      ),
                    ),
                    child: const Text('View pricing'),
                  ),
                ],
              ),
            ],
          );

          final side = Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.publicSurfaceSoft,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What stays connected', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 18),
                const _SideMetric(
                  label: 'Pipeline',
                  value: 'Leads, replies, and meetings stay visible',
                ),
                const SizedBox(height: 14),
                const _SideMetric(
                  label: 'Revenue',
                  value: 'Invoices, reminders, and statements stay attached',
                ),
                const SizedBox(height: 14),
                const _SideMetric(
                  label: 'Continuity',
                  value: 'Nothing important gets pushed into a separate trail',
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [lead, const SizedBox(height: 20), side],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 8, child: lead),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: side),
            ],
          );
        },
      ),
    );
  }
}

class _ProcessSection extends StatelessWidget {
  const _ProcessSection();

  @override
  Widget build(BuildContext context) {
    const steps = [
      _ProcessCard(
        number: '01',
        title: 'Set the market',
        body:
            'Choose where the work should begin so coverage, pace, and priorities are clear from the start.',
      ),
      _ProcessCard(
        number: '02',
        title: 'Run outreach',
        body:
            'Lead generation, contact sequencing, replies, and follow-through stay inside the same operating rhythm.',
      ),
      _ProcessCard(
        number: '03',
        title: 'Carry the account',
        body:
            'Meetings, billing, reminders, agreements, and records continue in the same system instead of scattering later.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How Orchestrate works', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'The work moves in one direction and stays accountable as it does.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 980;
              if (compact) {
                return Column(
                  children: [
                    for (int i = 0; i < steps.length; i++) ...[
                      steps[i],
                      if (i != steps.length - 1) const SizedBox(height: 14),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < steps.length; i++) ...[
                    Expanded(child: steps[i]),
                    if (i != steps.length - 1) const SizedBox(width: 14),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WhyItHoldsSection extends StatelessWidget {
  const _WhyItHoldsSection();

  @override
  Widget build(BuildContext context) {
    const items = [
      _PointCard(
        title: 'Built for continuity',
        body:
            'The work that begins the relationship should not vanish when billing, follow-up, or records begin.',
      ),
      _PointCard(
        title: 'Clear client visibility',
        body:
            'Clients can see standing, documents, account detail, and operating status without stepping into operator space.',
      ),
      _PointCard(
        title: 'Structured expansion',
        body:
            'Market coverage can widen over time without forcing teams to rebuild how the system is used.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1040;
        if (compact) {
          return Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i != items.length - 1) const SizedBox(height: 16),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              Expanded(child: items[i]),
              if (i != items.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(
        'Built for teams running outbound work across markets with continuity, visibility, and billing discipline.',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.publicText,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SideMetric extends StatelessWidget {
  const _SideMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.publicMuted,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.publicText,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
        ),
      ],
    );
  }
}

class _ProcessCard extends StatelessWidget {
  const _ProcessCard({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            number,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.publicAccent,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            body,
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

class _PointCard extends StatelessWidget {
  const _PointCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            body,
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
