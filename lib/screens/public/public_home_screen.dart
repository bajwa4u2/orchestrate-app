import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

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
                _SystemGlimpseSection(),
                SizedBox(height: 24),
                _TrustSection(),
                SizedBox(height: 24),
                _PricingSection(),
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
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 940;
          final headlineSize = stacked ? 60.0 : 48.0;

          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  'Generate leads, run outreach, follow up, book meetings, and carry the billing in one system.',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: headlineSize,
                        height: 1.02,
                        letterSpacing: -1.4,
                      ),
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  'Orchestrate helps businesses move from prospecting to booked meetings without losing the billing, payment, and record trail that follows the work.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.publicMuted,
                      ),
                ),
              ),
            ],
          );

          final right = const _HeroPanel();

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [left, const SizedBox(height: 24), right],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: left),
              const SizedBox(width: 28),
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
          _MetricRow(label: 'Leads sourced', value: '184'),
          SizedBox(height: 12),
          _MetricRow(label: 'Replies active', value: '37'),
          SizedBox(height: 12),
          _MetricRow(label: 'Meetings booked', value: '12'),
          SizedBox(height: 18),
          Divider(height: 1, color: AppTheme.publicLine),
          SizedBox(height: 18),
          _MetricRow(label: 'Invoices issued', value: '26'),
          SizedBox(height: 12),
          _MetricRow(label: 'Payments received', value: '18'),
          SizedBox(height: 12),
          _MetricRow(label: 'Reminders pending', value: '09'),
          SizedBox(height: 18),
          Divider(height: 1, color: AppTheme.publicLine),
          SizedBox(height: 18),
          _StatusRow(label: 'Domain posture', value: 'Verified'),
          SizedBox(height: 10),
          _StatusRow(label: 'Mailboxes', value: 'Stable'),
          SizedBox(height: 10),
          _StatusRow(label: 'Statements', value: 'Ready'),
        ],
      ),
    );
  }
}

class _SystemFlowSection extends StatelessWidget {
  const _SystemFlowSection();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Find leads', 'Build the target list around the business, market, and service.'),
      ('Launch outreach', 'Send controlled sequences instead of scattered one-off messages.'),
      ('Handle replies', 'Keep live responses visible and move qualified conversations forward.'),
      ('Book meetings', 'Turn interest into scheduled calls without losing the thread.'),
      ('Carry billing', 'Keep invoices, reminders, payments, and records attached to the work.'),
    ];

    return _SectionFrame(
      title: 'How it works',
      subtitle: 'Lead generation, outreach, follow-up, meetings, and billing move in one connected operating flow.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 980 ? 5 : constraints.maxWidth > 640 ? 2 : 1;
          return GridView.builder(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: columns == 1 ? 3.3 : 1.15,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _InfoCard(title: item.$1, body: item.$2);
            },
          );
        },
      ),
    );
  }
}

class _SystemGlimpseSection extends StatelessWidget {
  const _SystemGlimpseSection();

  @override
  Widget build(BuildContext context) {
    return _SectionFrame(
      title: 'Where outreach turns into revenue',
      subtitle: 'The same system that runs outbound work can also carry the billing, payment, and records that come after the meeting is booked.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 940;
          final left = Column(
            children: const [
              _GlimpsePanel(
                title: 'Command',
                rows: [
                  'Today in view',
                  'Priority items visible',
                  'Jobs and mailboxes in one place',
                ],
              ),
              SizedBox(height: 14),
              _GlimpsePanel(
                title: 'Execution',
                rows: [
                  'Campaigns moving',
                  'Replies being handled',
                  'Meetings scheduled',
                ],
              ),
            ],
          );
          final right = Column(
            children: const [
              _GlimpsePanel(
                title: 'Revenue',
                rows: [
                  'Invoices issued',
                  'Payments received',
                  'Reminders scheduled',
                  'Agreements active',
                  'Statements generated',
                ],
              ),
              SizedBox(height: 14),
              _GlimpsePanel(
                title: 'Deliverability',
                rows: [
                  'Domain verified',
                  'Mailboxes active',
                  'Sending posture stable',
                ],
              ),
            ],
          );

          if (stacked) {
            return Column(
              children: [left, const SizedBox(height: 14), right],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 14),
              Expanded(child: right),
            ],
          );
        },
      ),
    );
  }
}

class _TrustSection extends StatelessWidget {
  const _TrustSection();

  @override
  Widget build(BuildContext context) {
    const trustItems = [
      ('Agreements stay attached', 'Scope and service terms do not need to disappear into side emails and memory.'),
      ('Billing stays traceable', 'Invoices, reminders, payments, and statements remain reviewable.'),
      ('Communication stays visible', 'Follow-up does not drift across disconnected tools and inbox habits.'),
      ('Deliverability stays monitored', 'Domain posture and mailbox condition stay part of the operating picture.'),
    ];

    return _SectionFrame(
      title: 'Built for work that has to hold up',
      subtitle: 'This is not just a sending surface. It is built to carry the business trail around the work.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 980 ? 4 : constraints.maxWidth > 640 ? 2 : 1;
          return GridView.builder(
            itemCount: trustItems.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: columns == 1 ? 3.1 : 1.24,
            ),
            itemBuilder: (context, index) {
              final item = trustItems[index];
              return _InfoCard(title: item.$1, body: item.$2);
            },
          );
        },
      ),
    );
  }
}

class _PricingSection extends StatelessWidget {
  const _PricingSection();

  @override
  Widget build(BuildContext context) {
    return _SectionFrame(
      title: 'Pricing',
      subtitle: 'The service is structured in two clear lanes so the scope stays easy to understand.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 900;
          final cards = [
            const _PricingCard(
              title: 'Opportunity',
              subtitle: 'For businesses that want lead generation, outreach, follow-up, and meeting booking.',
              points: [
                'Lead sourcing and targeting',
                'Outbound outreach',
                'Follow-up and reply handling',
                'Meeting booking',
              ],
            ),
            const _PricingCard(
              title: 'Revenue',
              subtitle: 'For businesses that want outbound work plus billing, payment tracking, and records support.',
              points: [
                'Everything in Opportunity',
                'Invoices and payment tracking',
                'Agreements and reminders',
                'Statements and records',
                'Billing support tied to service delivery',
              ],
              emphasized: true,
            ),
          ];

          if (stacked) {
            return Column(
              children: [cards[0], const SizedBox(height: 14), cards[1]],
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

class _SectionFrame extends StatelessWidget {
  const _SectionFrame({
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _GlimpsePanel extends StatelessWidget {
  const _GlimpsePanel({required this.title, required this.rows});

  final String title;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          for (final row in rows) ...[
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
                    row,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.publicText,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.title,
    required this.subtitle,
    required this.points,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final List<String> points;
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
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 18),
          for (final point in points) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.circle, size: 8, color: AppTheme.publicAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(point, style: Theme.of(context).textTheme.bodyLarge),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.publicAccentSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.publicAccent,
                ),
          ),
        ),
      ],
    );
  }
}
