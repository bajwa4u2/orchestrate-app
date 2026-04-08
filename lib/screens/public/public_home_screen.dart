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
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 1080;

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
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(
                  'From outreach to revenue, carried in one system.',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: stacked ? 34 : 40,
                        height: 1.08,
                        letterSpacing: -0.6,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(
                  'Orchestrate runs outbound work as one continuous system, from first contact to collected revenue.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.publicMuted,
                        height: 1.5,
                      ),
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
                      minimumSize: const Size(0, 50),
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
                      minimumSize: const Size(0, 50),
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

          final right = const _HeroRightColumn();

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                left,
                const SizedBox(height: 28),
                right,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: left),
              const SizedBox(width: 40),
              Expanded(flex: 6, child: right),
            ],
          );
        },
      ),
    );
  }
}

class _HeroRightColumn extends StatelessWidget {
  const _HeroRightColumn();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroSignalPanel(),
        SizedBox(height: 14),
        PublicOverviewWidget(),
      ],
    );
  }
}

class _HeroSignalPanel extends StatelessWidget {
  const _HeroSignalPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 16,
        children: const [
          _HeroSignalItem(
            label: 'Leads',
            value: 'In motion',
          ),
          _HeroSignalItem(
            label: 'Meetings',
            value: 'Booked',
          ),
          _HeroSignalItem(
            label: 'Revenue',
            value: 'Carried through',
          ),
        ],
      ),
    );
  }
}

class _HeroSignalItem extends StatelessWidget {
  const _HeroSignalItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 130, maxWidth: 180),
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
                  fontWeight: FontWeight.w600,
                ),
          ),
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
      ('Define your market', 'Set the business, market, and service scope before work begins.'),
      ('Run outreach', 'Launch controlled sequences instead of scattered one-off sending.'),
      ('Move replies forward', 'Keep live responses visible and qualify serious conversations.'),
      ('Book meetings', 'Turn interest into scheduled calls without losing continuity.'),
      ('Carry revenue through', 'Keep invoices, reminders, payments, and records attached to the work.'),
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
      ('Agreements stay attached', 'Scope and service terms do not disappear into side emails and memory.'),
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
      subtitle: 'Choose the operating lane that fits the work now, then expand later if needed.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 900;
          final cards = [
            _PricingCard(
              title: 'Opportunity',
              subtitle: 'Outbound execution from lead to meeting.',
              points: const [
                'Lead sourcing and targeting',
                'Outbound outreach',
                'Follow-up and reply handling',
                'Meeting booking',
              ],
              ctaLabel: 'Start Opportunity',
              onTap: () => context.go('/pricing'),
            ),
            _PricingCard(
              title: 'Revenue',
              subtitle: 'Outbound plus billing, payment tracking, and records.',
              points: const [
                'Everything in Opportunity',
                'Invoices and payment tracking',
                'Agreements and reminders',
                'Statements and records',
                'Billing support tied to service delivery',
              ],
              emphasized: true,
              ctaLabel: 'Start Revenue',
              onTap: () => context.go('/pricing'),
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
          for (var i = 0; i < rows.length; i++) ...[
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
                    rows[i],
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.publicText,
                        ),
                  ),
                ),
              ],
            ),
            if (i != rows.length - 1) const SizedBox(height: 10),
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
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < points.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.circle, size: 8, color: AppTheme.publicAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(points[i], style: Theme.of(context).textTheme.bodyLarge),
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
