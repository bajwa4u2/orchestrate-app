import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/public/widgets/commercial_execution_surface.dart';
import 'package:orchestrate_app/features/public/widgets/execution_visual_chapters.dart';
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
    // The PublicShell already provides 28px horizontal gutters. This screen
    // adds only vertical spacing. On narrow viewports the vertical gaps also
    // tighten so the page does not become an excessive scroll tower.
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final gap = compact ? 16.0 : 24.0;
        return Padding(
          padding: EdgeInsets.only(
            top: compact ? 16 : 28,
            bottom: compact ? 28 : 44,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommercialHero(onTalk: () => _openPublicSupportDrawer(context)),
              SizedBox(height: gap),
              const ExecutionObjectStage(),
              SizedBox(height: gap),
              const ExecutionGraphChapter(),
              SizedBox(height: gap),
              const RecoveryVisualChapter(),
              SizedBox(height: gap),
              const SignalsVisualChapter(),
              SizedBox(height: gap),
              const RevenueRecordsVisual(),
              SizedBox(height: gap),
              const ResponsibleAiVisualChapter(),
              SizedBox(height: gap),
              _ClosingSection(
                  onSupportTap: () => _openPublicSupportDrawer(context)),
            ],
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onSupportTap});

  final VoidCallback onSupportTap;

  @override
  Widget build(BuildContext context) {
    // Single outer LayoutBuilder so container padding, headline size, and
    // layout all respond to the same width signal. The inner content width
    // (used to trigger stacked vs desktop layout) is derived from the outer
    // width minus the dynamic padding, so the switch point stays consistent.
    return LayoutBuilder(
      builder: (context, constraints) {
        final outerWidth = constraints.maxWidth;
        final phone = outerWidth < 480;
        final stacked = outerWidth < 980;
        // Phone: compact headline so the first screen-worth is readable.
        // Tablet/stacked: 34 balances density vs presence.
        // Desktop: 42 with the full-width headline treatment.
        final double headlineSize = phone
            ? 26
            : stacked
                ? 34
                : 42;
        final double pad = phone
            ? 18
            : stacked
                ? 24
                : 34;

        final badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.publicAccentSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Governed Revenue Automation',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.publicAccent),
          ),
        );

        final headline = Text(
          'Get qualified B2B opportunities and governed outreach without building a revenue operations team.',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: headlineSize,
                height: 1.12,
              ),
        );

        final subtitle = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: stacked ? 640 : 560),
          child: Text(
            'For B2B firms in regulated and reputation-sensitive sectors, outbound is a liability: outsource it and your sending identity gets burned; skip it and the pipeline stays quiet. Orchestrate runs governed outbound under your verified identity. Sends that would damage your reputation are refused. Refusal is a first-class outcome.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        );

        final actions = Wrap(
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
              child: const Text('Start 15-Day Trial'),
            ),
            OutlinedButton(
              onPressed: () => context.go('/diagnostics'),
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
              child: const Text('Run the Free Diagnostic'),
            ),
            TextButton(
              onPressed: onSupportTap,
              child: const Text('Talk to Orchestrate'),
            ),
          ],
        );

        const right = _HeroPanel();

        final containerDecoration = BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.publicLine),
        );

        if (stacked) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 2),
            decoration: containerDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badge,
                SizedBox(height: phone ? 14 : 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: headline,
                ),
                SizedBox(height: phone ? 12 : 16),
                subtitle,
                SizedBox(height: phone ? 18 : 24),
                actions,
                SizedBox(height: phone ? 14 : 18),
                right,
              ],
            ),
          );
        }

        // Desktop: headline spans the full hero width, then supporting copy
        // and actions sit in a two-column grid beside the signal panel.
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 2),
          decoration: containerDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              badge,
              const SizedBox(height: 22),
              headline,
              const SizedBox(height: 26),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        subtitle,
                        const SizedBox(height: 26),
                        actions,
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  const Expanded(flex: 5, child: right),
                ],
              ),
            ],
          ),
        );
      },
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
                'Orchestrate watches your defined market for commercial signals and turns them into qualified, contactable opportunities. Not a static contact list.',
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
        'Signal discovery, qualification, governed dispatch, follow-up continuity, and automatic recovery. No manual lifecycle controls.',
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
          // 2×2 grid halves the vertical height versus a single full-width
          // column of four cards, which is too tall on mobile.
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _StripCard(item: items[0])),
                  const SizedBox(width: 12),
                  Expanded(child: _StripCard(item: items[1])),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _StripCard(item: items[2])),
                  const SizedBox(width: 12),
                  Expanded(child: _StripCard(item: items[3])),
                ],
              ),
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
        'Connect your mailbox transport',
        'Three first-class transports: Google Workspace OAuth, Microsoft 365 OAuth, or custom SMTP + IMAP (SES, Mailgun, SendGrid, regional providers, your own server). Credentials are sealed in an encrypted vault.',
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
        'Discovery, qualification, dispatch governance, follow-up continuity, recovery, and reply handling run as managed infrastructure. You watch outcomes.',
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
            'You provide identity, mailbox, and sending-domain verification. Orchestrate takes over readiness orchestration and managed execution. The handoff is the product.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 820;
              if (stacked) {
                // 2-column arrangement on narrow screens: 5 cards become
                // 3 rows (2+2+1) instead of a 5-card single column.
                final rows = <Widget>[];
                for (int i = 0; i < stages.length; i += 2) {
                  if (i > 0) rows.add(const SizedBox(height: 12));
                  rows.add(Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _JourneyCard(stage: stages[i])),
                      if (i + 1 < stages.length) ...[
                        const SizedBox(width: 12),
                        Expanded(child: _JourneyCard(stage: stages[i + 1])),
                      ] else
                        const Expanded(child: SizedBox()),
                    ],
                  ));
                }
                return Column(children: rows);
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
              // Minimum 2 columns at all widths so 6 cards never stack
              // into a single tall column on mobile.
              final columns = constraints.maxWidth >= 980 ? 4 : 2;
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
              'Not a CRM. Not an AI SDR. Not sequence software. Not a dashboard you operate manually. Orchestrate is infrastructure your business activates.',
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
            'Both scopes begin with a 15-day trial. Stripe sets up the subscription first, the trial runs immediately, and monthly billing begins after the trial. The infrastructure is the same across both.',
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
            child: const Text('View Plans'),
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
                'Pick your managed-execution scope on the pricing page. Contact or quick guidance works if you want to walk through fit first.',
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
                child: const Text('Start 15-Day Trial'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/contact'),
                child: const Text('Talk to Orchestrate'),
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

/// Operational burden → managed-execution transformation narrative.
///
/// Two columns side-by-side: the burden businesses carry today vs the
/// operational layer Orchestrate absorbs. Reinforces that the platform
/// is managed infrastructure, not a campaign-SaaS tool.
class _BurdenTransformSection extends StatelessWidget {
  const _BurdenTransformSection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 900;
        final left = _BurdenColumn(
          tone: _BurdenTone.problem,
          eyebrow: 'Operational burden today',
          title: 'Outbound tooling makes operators do infrastructure work.',
          items: const [
            'SPF / DKIM / DMARC at the registrar, then chase propagation',
            'Mailbox tokens, reconnects, warmups, throttles',
            'Sequence builders that drift into spam folders',
            'Reply triage between inbox and CRM, by hand',
            'Suppression entries kept up by memory',
            'AI prompts re-engineered every time the tone drifts',
            'Transport failures with no clear next action',
            'Dashboards that show numbers but not operational state',
          ],
        );
        final right = _BurdenColumn(
          tone: _BurdenTone.solution,
          eyebrow: 'What Orchestrate absorbs',
          title: 'Identity is yours. Operation belongs to the platform.',
          items: const [
            'DNS verification runs continuously, no registrar trips',
            'Encrypted vault, OAuth + custom SMTP/IMAP, no token drift',
            'Governed dispatch under per-mailbox pacing. No manual cadence.',
            'Operation-scoped IMAP reply ingestion, follow-ups auto-cancelled',
            'Suppression enforced before every send. No bypass path.',
            'AI bounded by attribution, every invocation auditable',
            'Recovery branches re-converge readiness, ownership clear',
            'One readiness authority across Operations / Infrastructure / Home',
          ],
          actions: [
            _BurdenAction(
              label: 'Read why Orchestrate exists',
              onTap: () => context.go('/why-orchestrate'),
              filled: true,
            ),
            _BurdenAction(
              label: 'See how it operates',
              onTap: () => context.go('/how-orchestrate-operates'),
            ),
          ],
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
        // IntrinsicHeight is required so CrossAxisAlignment.stretch has
        // a bounded vertical extent — the public shell wraps the home
        // body in a SingleChildScrollView (unbounded height), and a
        // stretching Row inside an unbounded height fails layout and
        // blanks the body subtree on release builds.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              const SizedBox(width: 18),
              Expanded(child: right),
            ],
          ),
        );
      },
    );
  }
}

enum _BurdenTone { problem, solution }

class _BurdenAction {
  const _BurdenAction({
    required this.label,
    required this.onTap,
    this.filled = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool filled;
}

class _BurdenColumn extends StatelessWidget {
  const _BurdenColumn({
    required this.tone,
    required this.eyebrow,
    required this.title,
    required this.items,
    this.actions = const [],
  });

  final _BurdenTone tone;
  final String eyebrow;
  final String title;
  final List<String> items;
  final List<_BurdenAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isProblem = tone == _BurdenTone.problem;
    final background =
        isProblem ? AppTheme.publicSurfaceSoft : AppTheme.publicSurface;
    final accent =
        isProblem ? theme.colorScheme.outline : AppTheme.publicAccent;
    final eyebrowColor =
        isProblem ? theme.colorScheme.outline : AppTheme.publicAccent;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: theme.textTheme.labelLarge?.copyWith(
              color: eyebrowColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7, right: 12),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.publicText,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final action in actions)
                  if (action.filled)
                    FilledButton(
                      onPressed: action.onTap,
                      child: Text(action.label),
                    )
                  else
                    OutlinedButton(
                      onPressed: action.onTap,
                      child: Text(action.label),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
