import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class ClientLoginScreen extends StatelessWidget {
  const ClientLoginScreen({super.key, this.createMode = false});

  final bool createMode;

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
                    final form = _ClientAccessCard(createMode: createMode);
                    final side = _ClientContextCard(createMode: createMode);

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

class _ClientAccessCard extends StatelessWidget {
  const _ClientAccessCard({required this.createMode});

  final bool createMode;

  @override
  Widget build(BuildContext context) {
    final title = createMode ? 'Create account' : 'Sign in';
    final subtitle = createMode
        ? 'Start your client account here. Registration opens your place in the system and leads into onboarding, qualification, and activation.'
        : 'Sign in to review service progress, billing, reminders, and account records in one place.';
    final supporting = createMode
        ? 'Creating an account does not turn on the full service automatically. It starts a controlled client journey that can move through review, onboarding, and activation.'
        : 'Client access stays separate from the operator workspace so clients can see what matters without inheriting operator-level complexity.';
    final primaryLabel = createMode ? 'Create account' : 'Sign in';

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
          if (createMode) ...[
            const TextField(decoration: InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 14),
            const TextField(decoration: InputDecoration(labelText: 'Company name')),
            const SizedBox(height: 14),
          ],
          const TextField(decoration: InputDecoration(labelText: 'Email')),
          const SizedBox(height: 14),
          const TextField(
            obscureText: true,
            decoration: InputDecoration(labelText: 'Password'),
          ),
          if (createMode) ...[
            const SizedBox(height: 14),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(labelText: 'Confirm password'),
            ),
          ],
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
          OutlinedButton(
            onPressed: () => context.go(createMode ? '/client/login' : '/client/create-account'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(createMode ? 'Already have an account? Sign in' : 'Need an account? Create one'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.go('/contact'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.publicMuted,
              padding: EdgeInsets.zero,
            ),
            child: const Text('Need help with onboarding or fit? Contact us'),
          ),
        ],
      ),
    );
  }
}

class _ClientContextCard extends StatelessWidget {
  const _ClientContextCard({required this.createMode});

  final bool createMode;

  @override
  Widget build(BuildContext context) {
    final badge = createMode ? 'Controlled client entry' : 'Client-facing surface';
    final heading = createMode
        ? 'Registration opens the door. Activation happens in stages.'
        : 'This path is meant for review, visibility, and account clarity.';
    final body = createMode
        ? 'After account creation, the system can move the client through verification, onboarding, qualification, and activation. This keeps entry open without turning the service into unmanaged access.'
        : 'Clients should be able to understand where the work stands, what has been billed, what is due, and what records exist without needing the operator workspace.';
    final points = createMode
        ? const [
            'Create an account',
            'Verify account details',
            'Move through onboarding',
            'Enter active client state',
          ]
        : const [
            'Campaign and meeting visibility',
            'Invoices and payment status',
            'Reminders and statements',
            'Agreements and account history',
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
              badge,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.publicAccent,
                  ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            heading,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            body,
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
