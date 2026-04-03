import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class OpsLoginScreen extends StatelessWidget {
  const OpsLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 920;
                    final form = const _AccessCard(
                      title: 'Operator access',
                      subtitle:
                          'Access is provisioned directly. Use your operator account to enter the working system.',
                      supporting:
                          'This path is not promoted publicly as open sign-up because the workspace carries operational, billing, and deliverability responsibilities.',
                      primaryLabel: 'Sign in',
                    );

                    final side = const _OpsContextCard();

                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BackLink(onTap: () => context.go('/')),
                          const SizedBox(height: 18),
                          form,
                          const SizedBox(height: 18),
                          side,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _BackLink(onTap: () => context.go('/')),
                              const SizedBox(height: 18),
                              form,
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(flex: 5, child: side),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.title,
    required this.subtitle,
    required this.supporting,
    required this.primaryLabel,
  });

  final String title;
  final String subtitle;
  final String supporting;
  final String primaryLabel;

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
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.publicSurfaceSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              supporting,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
          ),
          const SizedBox(height: 22),
          const TextField(decoration: InputDecoration(labelText: 'Email')),
          const SizedBox(height: 14),
          const TextField(
            obscureText: true,
            decoration: InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: AppTheme.publicText,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(primaryLabel),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.g_mobiledata),
            label: const Text('Continue with Google'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.business_center_outlined),
            label: const Text('Continue with Microsoft'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpsContextCard extends StatelessWidget {
  const _OpsContextCard();

  @override
  Widget build(BuildContext context) {
    const points = [
      'Command and execution surfaces',
      'Client billing and statements',
      'Mailboxes and sender posture',
      'Records and operational history',
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.publicAccentSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Controlled workspace entry',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.publicAccent,
                  ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'This path enters the operator workspace, not the public product layer.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Operator access is kept separate because this side of the system carries working responsibility across outreach, billing, deliverability, and records.',
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

class _BackLink extends StatelessWidget {
  const _BackLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_back),
      label: const Text('Back to public site'),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.publicMuted,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      ),
    );
  }
}
