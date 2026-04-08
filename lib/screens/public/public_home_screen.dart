import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/public_overview_widget.dart';

class PublicHomeScreen extends StatelessWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _HeroSection(),
                SizedBox(height: 24),
                _SystemFlowSection(),
                SizedBox(height: 24),
                _LiveSystemSection(),
                SizedBox(height: 24),
                _OperatingLanesSection(),
                SizedBox(height: 24),
                _TrustSection(),
                SizedBox(height: 24),
                _ClosingSection(),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 1040;

          final lead = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.publicAccentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Outbound execution and revenue continuity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.publicAccent,
                      ),
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(
                  'Outbound execution and revenue, carried in one system.',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: stacked ? 36 : 44,
                        height: 1.04,
                        letterSpacing: -1.15,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(
                  'Orchestrate keeps sourcing, outreach, follow-up, meetings, invoices, payments, and records attached to the same operating line instead of splitting the work across disconnected tools.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.publicMuted,
                        height: 1.55,
                      ),
                ),
              ),
              const SizedBox(height: 22),
              const _SignalStrip(),
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
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Create account'),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/pricing'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.publicText,
                      side: const BorderSide(color: AppTheme.publicLine),
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('View pricing'),
                  ),
                ],
              ),
            ],
          );

          final right = const _HeroSystemSurface();

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                lead,
                const SizedBox(height: 26),
                right,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: lead),
              const SizedBox(width: 28),
              Expanded(flex: 6, child: right),
            ],
          );
        },
      ),
    );
  }
}

class _SignalStrip extends StatelessWidget {
  const _SignalStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      _SignalItem(label: 'Leads', value: 'Qualified'),
      _SignalItem(label: 'Replies', value: 'Handled'),
      _SignalItem(label: 'Meetings', value: 'Booked'),
      _SignalItem(label: 'Revenue', value: 'Carried through'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 14,
        children: items,
      ),
    );
  }
}

class _SignalItem extends StatelessWidget {
  const _SignalItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.publicText,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _HeroSystemSurface extends StatelessWidget {
  const _HeroSystemSurface();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _TimelineSurface(),
        SizedBox(height: 14),
        PublicOverviewWidget(),
      ],
    );
  }
}

class _TimelineSurface extends StatelessWidget {
  const _TimelineSurface();

  @override
  Widget build(BuildContext context) {
    const stages = [
      _TimelineStage(title: 'Lead', detail: 'target list ready'),
      _TimelineStage(title: 'Outreach', detail: 'sequence active'),
      _TimelineStage(title: 'Reply', detail: 'interest detected'),
      _TimelineStage(title: 'Meeting', detail: 'scheduled'),
      _TimelineStage(title: 'Revenue', detail: 'invoice and payment trail'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System in motion',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 620;

              if (stacked) {
                return Column(
                  children: [
                    for (int i = 0; i < stages.length; i++) ...[
                      _TimelineStageCard(stage: stages[i], compact: true),
                      if (i != stages.length - 1)
                        Container(
                          margin: const EdgeInsets.only(left: 11),
                          width: 2,
                          height: 16,
                          color: AppTheme.publicLine,
                        ),
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < stages.length; i++) ...[
                    Expanded(
                      child: _TimelineStageCard(stage: stages[i]),
                    ),
                    if (i != stages.length - 1)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            height: 2,
                            color: AppTheme.publicLine,
                          ),
                        ),
                      ),
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

class _TimelineStage {
  const _TimelineStage({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;
}

class _TimelineStageCard extends StatelessWidget {
  const _TimelineStageCard({
    required this.stage,
    this.compact = false,
  });

  final _TimelineStage stage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.publicAccentSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.publicAccent),
            ),
            child: const Center(
              child: SizedBox(
                width: 6,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.publicAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stage.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    stage.detail,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.publicMuted,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppTheme.publicAccentSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.publicAccent),
          ),
          child: const Center(
            child: SizedBox(
              width: 6,
              height: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.publicAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(stage.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          stage.detail,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.publicMuted,
              ),
        ),
      ],
    );
  }
}

class _SystemFlowSection extends StatelessWidget {
  const _SystemFlowSection();

  @override
  Widget build(BuildContext context) {
    const steps = [
      _FlowStep(
        title: 'Define your market',
        body: 'Set target geography, business scope, and who you need to reach before work starts.',
      ),
      _FlowStep(
        title: 'Run outreach',
        body: 'Move sequences, follow-ups, and qualification as one operating line instead of one-off sending.',
      ),
      _FlowStep(
        title: 'Carry replies forward',
        body: 'Keep live responses visible and move serious conversations toward booked meetings.',
      ),
      _FlowStep(
        title: 'Close the revenue trail',
        body: 'Attach invoices, reminders, payments, and records to the same client relationship.',
      ),
    ];

    return _SectionSurface(
      title: 'One operating flow, not stacked tools',
      subtitle:
          'The point is not simply sending more messages. The point is carrying work through the full sequence without losing continuity.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 920;

          if (stacked) {
            return Column(
              children: [
                for (int i = 0; i < steps.length; i++) ...[
                  _FlowRailItem(step: steps[i], index: i + 1, stacked: true),
                  if (i != steps.length - 1)
                    Container(
                      margin: const EdgeInsets.only(left: 16),
                      width: 2,
                      height: 18,
                      color: AppTheme.publicLine,
                    ),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: _FlowRailItem(step: steps[i], index: i + 1),
                ),
                if (i != steps.length - 1)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Container(
                        height: 2,
                        color: AppTheme.publicLine,
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FlowStep {
  const _FlowStep({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class _FlowRailItem extends StatelessWidget {
  const _FlowRailItem({
    required this.step,
    required this.index,
    this.stacked = false,
  });

  final _FlowStep step;
  final int index;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final marker = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppTheme.publicText,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: Text(
          '$index',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );

    if (stacked) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          marker,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  step.body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.publicMuted,
                      ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        marker,
        const SizedBox(height: 14),
        Text(step.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          step.body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.publicMuted,
              ),
        ),
      ],
    );
  }
}

class _LiveSystemSection extends StatelessWidget {
  const _LiveSystemSection();

  @override
  Widget build(BuildContext context) {
    return _SectionSurface(
      title: 'What the system carries',
      subtitle:
          'Orchestrate should feel like work is already moving, not like a brochure explaining what work might happen later.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 980;

          final left = Column(
            children: const [
              _MessageSurface(
                eyebrow: 'Outreach',
                subject: 'Subject: Steady outbound for regional service teams',
                body:
                    'We help teams carry lead sourcing, outbound follow-up, and booked meetings in one operating line instead of splitting execution across separate tools and inbox habits.',
                footer: 'Sequence ready · follow-up logic active',
              ),
              SizedBox(height: 14),
              _MessageSurface(
                eyebrow: 'Reply handling',
                subject: 'Reply: This looks relevant. Can we talk next week?',
                body:
                    'The point is not just sending. Serious replies remain visible, are qualified quickly, and move toward scheduled meetings without losing continuity.',
                footer: 'Reply visible · meeting path open',
              ),
            ],
          );

          final right = Column(
            children: const [
              _CapabilitySurface(
                title: 'Revenue continuity',
                items: [
                  'Invoices stay attached to the account',
                  'Payment reminders remain visible',
                  'Statements and records stay reviewable',
                ],
              ),
              SizedBox(height: 14),
              _CapabilitySurface(
                title: 'Deliverability posture',
                items: [
                  'Mailboxes remain part of the operating picture',
                  'Domain condition stays visible',
                  'Sending posture is treated as a responsibility',
                ],
              ),
            ],
          );

          if (stacked) {
            return Column(
              children: [
                left,
                const SizedBox(height: 14),
                right,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: left),
              const SizedBox(width: 14),
              Expanded(flex: 5, child: right),
            ],
          );
        },
      ),
    );
  }
}

class _MessageSurface extends StatelessWidget {
  const _MessageSurface({
    required this.eyebrow,
    required this.subject,
    required this.body,
    required this.footer,
  });

  final String eyebrow;
  final String subject;
  final String body;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            eyebrow,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            subject,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Text(
              footer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilitySurface extends StatelessWidget {
  const _CapabilitySurface({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          for (int i = 0; i < items.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    color: AppTheme.publicAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    items[i],
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            if (i != items.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _OperatingLanesSection extends StatelessWidget {
  const _OperatingLanesSection();

  @override
  Widget build(BuildContext context) {
    return _SectionSurface(
      title: 'Operating lanes',
      subtitle:
          'Choose the lane that fits the work now. Both can expand through Focused, Multi-Market, and Precision coverage.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 900;

          final cards = [
            _LaneCard(
              title: 'Opportunity',
              subtitle: 'Outbound execution from lead to meeting.',
              points: const [
                'Lead sourcing and targeting',
                'Outbound execution',
                'Follow-up and reply handling',
                'Meeting booking',
              ],
              ctaLabel: 'View Opportunity pricing',
              onTap: () => context.go('/pricing'),
            ),
            _LaneCard(
              title: 'Revenue',
              subtitle: 'Outbound plus billing, reminders, payments, and records.',
              points: const [
                'Everything in Opportunity',
                'Invoices and payment tracking',
                'Agreements and reminders',
                'Statements and records',
              ],
              emphasized: true,
              ctaLabel: 'View Revenue pricing',
              onTap: () => context.go('/pricing'),
            ),
          ];

          if (stacked) {
            return Column(
              children: [
                cards[0],
                const SizedBox(height: 14),
                cards[1],
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 14),
              Expanded(child: cards[1]),
            ],
          );
        },
      ),
    );
  }
}

class _LaneCard extends StatelessWidget {
  const _LaneCard({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.ctaLabel,
    required this.onTap,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final List<String> points;
  final String ctaLabel;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: emphasized ? AppTheme.publicSurfaceSoft : AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 18),
          for (int i = 0; i < points.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.circle, size: 8, color: AppTheme.publicAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    points[i],
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            if (i != points.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.publicText,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(ctaLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustSection extends StatelessWidget {
  const _TrustSection();

  @override
  Widget build(BuildContext context) {
    const items = [
      _TrustItem(
        title: 'Agreements stay attached',
        body: 'Scope and service terms do not disappear into side emails and memory.',
      ),
      _TrustItem(
        title: 'Billing stays traceable',
        body: 'Invoices, reminders, payments, and statements remain reviewable.',
      ),
      _TrustItem(
        title: 'Communication stays visible',
        body: 'Follow-up does not drift across disconnected tools and inbox habits.',
      ),
      _TrustItem(
        title: 'Deliverability stays monitored',
        body: 'Mailbox and domain posture remain part of the operating picture.',
      ),
    ];

    return _SectionSurface(
      title: 'Built for work that has to hold up',
      subtitle:
          'This is not just a sending surface. It is designed to carry the business trail around the work.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 980 ? 4 : constraints.maxWidth > 640 ? 2 : 1;

          return GridView.builder(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: columns == 1 ? 3.0 : 1.15,
            ),
            itemBuilder: (context, index) => _TrustCard(item: items[index]),
          );
        },
      ),
    );
  }
}

class _TrustItem {
  const _TrustItem({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.item});

  final _TrustItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            item.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _ClosingSection extends StatelessWidget {
  const _ClosingSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 30),
      decoration: BoxDecoration(
        color: AppTheme.publicText,
        borderRadius: BorderRadius.circular(28),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 860;

          final lead = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start with the lane that fits now.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(
                  'Move into Opportunity or Revenue, then expand across Focused, Multi-Market, or Precision coverage as the work grows.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withOpacity(0.82),
                        height: 1.5,
                      ),
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: () => context.go('/pricing'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.publicText,
                  minimumSize: const Size(0, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('View pricing'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/contact'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.28)),
                  minimumSize: const Size(0, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Talk through fit'),
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                lead,
                const SizedBox(height: 20),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: lead),
              const SizedBox(width: 24),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.publicMuted,
                    height: 1.5,
                  ),
            ),
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}
