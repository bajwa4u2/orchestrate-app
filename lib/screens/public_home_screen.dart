import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/surface.dart';

class PublicHomeScreen extends StatelessWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _HeroSection(),
              SizedBox(height: 24),
              _CapabilityGrid(),
              SizedBox(height: 24),
              _OperationalSections(),
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
    return Surface(
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 30),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;

          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.publicAccentSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.publicLine),
                ),
                child: Text(
                  'Revenue operations carried end to end',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.publicAccent,
                      ),
                ),
              ),
              const SizedBox(height: 22),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  'Outbound execution, follow-through, billing, and records in one operating system.',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 46, height: 1.04),
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  'Orchestrate helps businesses move from lead generation to booked meetings, then carry the account, invoices, agreements, reminders, and statements without breaking continuity.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: () => context.go('/client/join'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.publicText,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Join Orchestrate'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/how-it-works'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.publicText,
                      backgroundColor: AppTheme.publicSurfaceSoft,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.publicLine),
                      ),
                    ),
                    child: const Text('See how it works'),
                  ),
                ],
              ),
            ],
          );

          final snapshot = Surface(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('System posture', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 18),
                const _MetricRow(label: 'Leads to meetings', value: 'Continuous flow'),
                const SizedBox(height: 12),
                const _MetricRow(label: 'Billing trail', value: 'Visible to client'),
                const SizedBox(height: 12),
                const _MetricRow(label: 'Records', value: 'Agreements and statements'),
                const SizedBox(height: 12),
                const _MetricRow(label: 'Access', value: 'Operator and client surfaces'),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 20), snapshot],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 8, child: summary),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: snapshot),
            ],
          );
        },
      ),
    );
  }
}

class _CapabilityGrid extends StatelessWidget {
  const _CapabilityGrid();

  @override
  Widget build(BuildContext context) {
    const cards = [
      _CapabilityCard(
        title: 'Command',
        body: 'A calm operator surface for active campaigns, replies, meetings, and revenue pressure.',
      ),
      _CapabilityCard(
        title: 'Execution',
        body: 'Lead generation, outreach, follow-up, and response handling without scattered tools.',
      ),
      _CapabilityCard(
        title: 'Revenue',
        body: 'Invoices, receipts, agreements, statements, and reminders carried as part of delivery.',
      ),
      _CapabilityCard(
        title: 'Client visibility',
        body: 'A clear client workspace that shows standing, documents, alerts, and account footing.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1160 ? 4 : width >= 820 ? 2 : 1;
        final gap = 18.0;
        final itemWidth = columns == 1 ? width : (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: itemWidth, child: card),
          ],
        );
      },
    );
  }
}

class _OperationalSections extends StatelessWidget {
  const _OperationalSections();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;

        final first = Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What stays first-class', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _Pill(label: 'Lead generation'),
                  _Pill(label: 'Outreach'),
                  _Pill(label: 'Follow-up'),
                  _Pill(label: 'Meetings'),
                  _Pill(label: 'Billing'),
                  _Pill(label: 'Agreements'),
                  _Pill(label: 'Statements'),
                  _Pill(label: 'Deliverability'),
                  _Pill(label: 'Client visibility'),
                ],
              ),
            ],
          ),
        );

        final second = Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Built for continuity', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              Text(
                'The point is not just sending outreach. It is carrying work cleanly from first contact to scheduled meeting, then keeping billing and account records close enough that nothing important drops between systems.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted),
              ),
            ],
          ),
        );

        if (compact) {
          return Column(
            children: [first, const SizedBox(height: 18), second],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: first),
            const SizedBox(width: 18),
            Expanded(flex: 5, child: second),
          ],
        );
      },
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
          ),
        ),
        const SizedBox(width: 16),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
