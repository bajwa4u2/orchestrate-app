import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/public/widgets/public_overview_widget.dart';
import 'package:orchestrate_app/features/support/screens/support_drawer.dart';

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(onSupportTap: () => _openPublicSupportDrawer(context)),
          const SizedBox(height: 24),
          const _SystemStrip(),
          const SizedBox(height: 24),
          const PublicOverviewWidget(),
          const SizedBox(height: 24),
          const _CapabilitySection(),
          const SizedBox(height: 24),
          const _JourneySection(),
          const SizedBox(height: 24),
          const _TruthSection(),
          const SizedBox(height: 24),
          const _PlansSection(),
          const SizedBox(height: 24),
          _ClosingSection(
              onSupportTap: () => _openPublicSupportDrawer(context)),
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
        borderRadius: BorderRadius.circular(AppTheme.radius),
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
                  'Commercial intelligence + execution infrastructure',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppTheme.publicAccent),
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  'Managed revenue automation infrastructure that detects opportunity, verifies readiness, and runs execution for you.',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: stacked ? 38 : 52,
                        height: 1.04,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  'You connect your business identity and sending identity. Orchestrate detects commercial opportunity from market signals, qualifies it, verifies readiness, and runs governed execution end to end — with operational continuity built in.',
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
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                    ),
                    child: const Text('Activate infrastructure'),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/how-it-works'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.publicText,
                      side: const BorderSide(color: AppTheme.publicLine),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                    ),
                    child: const Text('See how it operates'),
                  ),
                  TextButton(
                    onPressed: onSupportTap,
                    child: const Text('Talk through fit'),
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
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _Signal(
            title: 'Signal-driven opportunity detection',
            body:
                'Orchestrate watches your defined market for commercial signals — not a static contact list — and turns them into qualified, contactable opportunities.',
          ),
          SizedBox(height: 14),
          _Signal(
            title: 'Readiness orchestration',
            body:
                'Subscription, representation, mailbox connection, and verified sending identity (SPF / DKIM / DMARC) are continuously verified before execution begins.',
          ),
          SizedBox(height: 14),
          _Signal(
            title: 'Managed execution + continuity',
            body:
                'Governed dispatch, follow-up continuity, automatic recovery, deliverability posture, and operational visibility remain Orchestrate-owned once readiness is met.',
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
        'Client provides',
        'Business identity, mailbox connection, mailbox ownership, and sending-domain verification. That is the full client surface.',
      ),
      _StripItem(
        'Orchestrate verifies',
        'Real DNS-based SPF / DKIM / DMARC verification, mailbox OAuth handshake, and continuous readiness checks before any send happens.',
      ),
      _StripItem(
        'Orchestrate executes',
        'Signal discovery, qualification, governed dispatch, follow-up continuity, and automatic recovery — without manual lifecycle controls.',
      ),
      _StripItem(
        'Operational continuity',
        'Audit trail, readiness transitions, deliverability posture, and revenue records remain visible and explainable end to end.',
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
        borderRadius: BorderRadius.circular(AppTheme.radius),
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
        'Connect your business identity',
        'Market, offer, target segments, and representation authorization. The inputs Orchestrate needs to discover the right opportunities for you.',
      ),
      _JourneyStage(
        '2',
        'Connect your mailbox',
        'OAuth handshake with Gmail or Microsoft 365 happens entirely backend-side. Tokens are sealed in an external vault — never your browser, never the database.',
      ),
      _JourneyStage(
        '3',
        'Verify sending identity',
        'Publish SPF, DKIM, and DMARC records for your domain. Orchestrate verifies them with live DNS and re-checks automatically as they propagate.',
      ),
      _JourneyStage(
        '4',
        'Readiness orchestration',
        'Subscription, authorization, mailbox, and sending identity are continuously checked. When everything is green, Orchestrate activates execution on its own.',
      ),
      _JourneyStage(
        '5',
        'Managed execution begins',
        'Discovery, qualification, dispatch governance, follow-up continuity, recovery, and reply handling run as managed infrastructure. You watch the outcomes — never the buttons.',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How activation works',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Client identity, mailbox, and sending-domain verification on your side — then Orchestrate takes over readiness orchestration and managed execution. The handoff is the product.',
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

class _CapabilitySection extends StatelessWidget {
  const _CapabilitySection();

  @override
  Widget build(BuildContext context) {
    final items = const [
      _Capability(
        title: 'Signal-driven discovery',
        body:
            'Provider-agnostic discovery monitors market signals tied to your target segments, not a static list rented from one vendor.',
      ),
      _Capability(
        title: 'Verified sending identity',
        body:
            'Real DNS-based SPF, DKIM, and DMARC verification with continuous re-checks. Sending never starts on an unverified domain.',
      ),
      _Capability(
        title: 'Vault-backed credentials',
        body:
            'OAuth tokens for connected mailboxes are sealed in an external secrets vault. Never stored in the database. Never exposed to the browser.',
      ),
      _Capability(
        title: 'Governed dispatch + recovery',
        body:
            'Every send passes a governance check. Pauses, errors, and provider hiccups are recovered automatically without client lifecycle controls.',
      ),
      _Capability(
        title: 'Operational continuity',
        body:
            'Readiness transitions, deliverability posture, follow-up cadence, and revenue records are audited and explainable end to end.',
      ),
      _Capability(
        title: 'Explainable execution',
        body:
            'Every readiness state, every recovery, every dispatch decision can be traced back to a single source-of-truth readiness engine.',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The infrastructure underneath',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Six infrastructure surfaces a buyer should be able to verify before activating revenue automation.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980
                  ? 4
                  : constraints.maxWidth >= 640
                      ? 2
                      : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 12)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in items)
                    SizedBox(width: width, child: _CapabilityCard(item: item)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Capability {
  const _Capability({required this.title, required this.body});

  final String title;
  final String body;
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.item});

  final _Capability item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 168),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(item.body, style: Theme.of(context).textTheme.bodyMedium),
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
        borderRadius: BorderRadius.circular(AppTheme.radius),
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
          title: 'What Orchestrate is',
          body:
              'Commercial intelligence + execution infrastructure. Managed revenue automation that operates governed dispatch, qualification, recovery, and continuity once your business identity is verified.',
        );
        final right = _TruthCard(
          title: 'What Orchestrate is not',
          body:
              'Not a CRM. Not an AI SDR. Not sequence software. Not a dashboard you operate manually. Orchestrate is infrastructure your business activates — not a tool you configure and run.',
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
        borderRadius: BorderRadius.circular(AppTheme.radius),
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
            'Managed execution scope: signal discovery, qualification, governed dispatch, follow-up continuity, and reply handling.',
        route: '/pricing?plan=opportunity&trial=15d',
      ),
      _PlanPeek(
        title: 'Revenue',
        body:
            'Opportunity scope plus revenue continuity: agreements, invoices, statements, reminders, and customer-facing financial records governed alongside execution.',
        route: '/pricing?plan=revenue&trial=15d',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pick the scope of managed execution',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Both scopes can begin with a 15-day start period before monthly billing. The infrastructure is the same — the difference is how far Orchestrate carries revenue continuity for you.',
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
        borderRadius: BorderRadius.circular(AppTheme.radius),
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
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 860;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to activate revenue automation infrastructure?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Pick your managed-execution scope on the pricing page. If you want to walk through fit first, contact and quick guidance both work — no commitment until your business identity is in place.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.publicMuted,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Secure billing powered by Stripe.',
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
                child: const Text('View pricing'),
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
