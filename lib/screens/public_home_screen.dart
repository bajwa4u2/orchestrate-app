import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/surface.dart';

class PublicHomeScreen extends StatelessWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Orchestrate', style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              _PublicAction(label: 'Operator', onTap: () => context.go('/app/command')),
              const SizedBox(width: 12),
              _PublicAction(label: 'Client portal', onTap: () => context.go('/client/overview')),
            ],
          ),
          const SizedBox(height: 36),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revenue operations, follow-through, billing, and records in one system.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 18),
                Text(
                  'Orchestrate is built for businesses that need one place to run outbound work, convert replies into meetings, and keep the revenue trail visible after the outreach work is done.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            children: const [
              _HeroCard(title: 'Command', body: 'Today, pressure, delivery, and unresolved work.'),
              _HeroCard(title: 'Execution', body: 'Leads, campaigns, replies, and meetings in motion.'),
              _HeroCard(title: 'Revenue', body: 'Invoices, agreements, statements, and reminders.'),
              _HeroCard(title: 'Client portal', body: 'Clear account visibility without operator clutter.'),
            ],
          ),
          const SizedBox(height: 28),
          Surface(
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
          ),
        ],
      ),
    );
  }
}

class _PublicAction extends StatelessWidget {
  const _PublicAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        backgroundColor: AppTheme.panel,
        foregroundColor: AppTheme.text,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.line),
        ),
      ),
      child: Text(label),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
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
        color: AppTheme.panelRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
