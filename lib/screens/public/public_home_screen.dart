import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../features/support/screens/support_drawer.dart';

Future<void> _openPublicSupportDrawer(BuildContext context) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Support',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SupportDrawer(
              publicMode: true,
              baseUrl: AppConfig.apiBaseUrl,
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

class PublicHomeScreen extends StatelessWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(onSupportTap: () => _openPublicSupportDrawer(context)),
          const SizedBox(height: 24),
          const _SystemStrip(),
          const SizedBox(height: 24),
          const _JourneySection(),
          const SizedBox(height: 24),
          const _TruthSection(),
          const SizedBox(height: 24),
          const _PlansSection(),
          const SizedBox(height: 24),
          _ClosingSection(onSupportTap: () => _openPublicSupportDrawer(context)),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onSupportTap});

  final VoidCallback onSupportTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 980;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.publicAccentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Outbound execution and revenue continuity in one operating system',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppTheme.publicAccent),
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  'Stop losing momentum between outreach, meetings, billing, and records.',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: stacked ? 38 : 52,
                        height: 1.04,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  'Orchestrate gives businesses one controlled path from targeting and message delivery to booked meetings, invoices, reminders, and payment follow-through.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.publicMuted,
                      ),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: () => context.go('/pricing?trial=15d'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.publicText,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Review pricing'),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/contact'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.publicText,
                      side: const BorderSide(color: AppTheme.publicLine),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Talk through fit'),
                  ),
                  TextButton(
                    onPressed: onSupportTap,
                    child: const Text('Get quick guidance'),
                  ),
                ],
              ),
            ],
          );

          final right = const _HeroPanel();

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
              Expanded(flex: 6, child: left),
              const SizedBox(width: 20),
              Expanded(flex: 5, child: right),
            ],
          );
        },
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _Signal(
            title: 'One record of work',
            body:
                'Targeting, replies, meetings, invoices, reminders, and records stay connected instead of drifting across separate tools.',
          ),
          SizedBox(height: 14),
          _Signal(
            title: 'Clear entry into service',
            body:
                'Plan choice, account access, setup, and activation happen in order so live work starts with the right scope.',
          ),
          SizedBox(height: 14),
          _Signal(
            title: 'Built past the first meeting',
            body:
                'The system does not stop at outreach. Billing continuity and account truth remain attached after work begins.',
          ),
        ],
      ),
    );
  }
}

class _Signal extends StatelessWidget {
  const _Signal({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _SystemStrip extends StatelessWidget {
  const _SystemStrip();

  @override
  Widget build(BuildContext context) {
    final items = const [
      _StripItem(
        'Public truth',
        'Plans, scope, and readiness are visible before sign-up.',
      ),
      _StripItem(
        'Client entry',
        'Verification, setup, and activation stay tied to real account state.',
      ),
      _StripItem(
        'Execution',
        'Outreach, follow-up, replies, and meetings stay inside one operating line.',
      ),
      _StripItem(
        'Revenue continuity',
        'Invoices, reminders, statements, and records remain attached after work begins.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;
        if (stacked) {
          return Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _StripCard(item: items[i]),
                if (i != items.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              Expanded(child: _StripCard(item: items[i])),
              if (i != items.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _StripItem {
  const _StripItem(this.title, this.body);
  final String title;
  final String body;
}

class _StripCard extends StatelessWidget {
  const _StripCard({required this.item});
  final _StripItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(item.body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _JourneySection extends StatelessWidget {
  const _JourneySection();

  @override
  Widget build(BuildContext context) {
    final stages = const [
      _JourneyStage(
        '1',
        'Choose your lane',
        'Start with Opportunity or Revenue, then choose the coverage depth you need.',
      ),
      _JourneyStage(
        '2',
        'Create access',
        'Account sign-up, verification, and recovery stay part of the real product entry.',
      ),
      _JourneyStage(
        '3',
        'Define operating scope',
        'Country, region, industry, and operating direction become execution input.',
      ),
      _JourneyStage(
        '4',
        'Activate subscription',
        'Secure checkout follows readiness instead of forcing commitment too early.',
      ),
      _JourneyStage(
        '5',
        'Operate from the system',
        'Client visibility and operator execution stay aligned to the same record of work.',
      ),
    ];

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
            'How the product moves',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'The system is structured so entry, setup, activation, and live operations happen in the right order.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 820;
              if (stacked) {
                return Column(
                  children: [
                    for (int i = 0; i < stages.length; i++) ...[
                      _JourneyCard(stage: stages[i]),
                      if (i != stages.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (int i = 0; i < stages.length; i++) ...[
                    Expanded(child: _JourneyCard(stage: stages[i])),
                    if (i != stages.length - 1) const SizedBox(width: 12),
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

class _JourneyStage {
  const _JourneyStage(this.step, this.title, this.body);
  final String step;
  final String title;
  final String body;
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.stage});
  final _JourneyStage stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stage.step,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.publicAccent,
                ),
          ),
          const SizedBox(height: 10),
          Text(stage.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(stage.body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TruthSection extends StatelessWidget {
  const _TruthSection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;
        final left = _TruthCard(
          title: 'What this product is',
          body:
              'A managed operating system for outbound execution and revenue continuity, built to carry the work forward after the first message.',
        );
        final right = _TruthCard(
          title: 'What this product is not',
          body:
              'Not a generic CRM, not a loose AI wrapper, and not a dashboard that leaves the real work scattered across other tools.',
        );
        if (stacked) {
          return Column(
            children: [
              left,
              const SizedBox(height: 12),
              right,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _TruthCard extends StatelessWidget {
  const _TruthCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _PlansSection extends StatelessWidget {
  const _PlansSection();

  @override
  Widget build(BuildContext context) {
    final cards = const [
      _PlanPeek(
        title: 'Opportunity',
        body:
            'Lead generation, outreach, follow-up, replies, and meetings handled inside one system.',
        route: '/pricing?plan=opportunity&trial=15d',
      ),
      _PlanPeek(
        title: 'Revenue',
        body:
            'Everything in Opportunity plus billing continuity, statements, reminders, and customer-facing financial movement.',
        route: '/pricing?plan=revenue&trial=15d',
      ),
    ];

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
            'Choose the operating lane',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Each lane can begin with a 15-day start period before monthly billing begins.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 860;
              if (stacked) {
                return Column(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      _PlanPeekCard(plan: cards[i]),
                      if (i != cards.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    Expanded(child: _PlanPeekCard(plan: cards[i])),
                    if (i != cards.length - 1) const SizedBox(width: 12),
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

class _PlanPeek {
  const _PlanPeek({
    required this.title,
    required this.body,
    required this.route,
  });
  final String title;
  final String body;
  final String route;
}

class _PlanPeekCard extends StatelessWidget {
  const _PlanPeekCard({required this.plan});
  final _PlanPeek plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(plan.body, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go(plan.route),
            child: const Text('Open pricing'),
          ),
        ],
      ),
    );
  }
}

class _ClosingSection extends StatelessWidget {
  const _ClosingSection({required this.onSupportTap});

  final VoidCallback onSupportTap;

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 860;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to define scope properly?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Start with pricing. If the fit is not obvious yet, use contact or quick guidance before you move into account setup.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.publicMuted,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Secure billing powered by Stripe',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.publicMuted,
                    ),
              ),
            ],
          );

          final right = Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: () => context.go('/pricing?trial=15d'),
                child: const Text('Review pricing'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/contact'),
                child: const Text('Open contact'),
              ),
              TextButton(
                onPressed: onSupportTap,
                child: const Text('Get quick guidance'),
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                left,
                const SizedBox(height: 16),
                right,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              right,
            ],
          );
        },
      ),
    );
  }
}