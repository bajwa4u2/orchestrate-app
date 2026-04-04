import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand/brand_assets.dart';
import '../../core/theme/app_theme.dart';

class ClientLoginScreen extends StatelessWidget {
  const ClientLoginScreen({super.key, this.createMode = false});

  final bool createMode;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.publicBackground,
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
                        const SizedBox(width: 20),
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
    final title = createMode ? 'Enter Orchestrate' : 'Access your workspace';
    final subtitle = createMode
        ? 'Start your client account here.'
        : 'Sign in to review progress, billing, and account records.';
    final primaryLabel = createMode ? 'Request access' : 'Sign in';
    final switchLabel = createMode
        ? 'Already have an account? Sign in'
        : 'Need an account? Request access';

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrandAssets.logo(context, height: 28),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  height: 1.02,
                ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
          ),
          const SizedBox(height: 28),
          if (createMode) ...[
            const _FieldLabel('Name'),
            const SizedBox(height: 8),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Your full name',
              ),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Company'),
            const SizedBox(height: 8),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Company name',
              ),
            ),
            const SizedBox(height: 16),
          ],
          const _FieldLabel('Email'),
          const SizedBox(height: 8),
          const TextField(
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'name@company.com',
            ),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Password'),
          const SizedBox(height: 8),
          const TextField(
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Enter password',
            ),
          ),
          if (createMode) ...[
            const SizedBox(height: 16),
            const _FieldLabel('Confirm password'),
            const SizedBox(height: 8),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Confirm password',
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: AppTheme.publicText,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            child: Text(primaryLabel),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go(
              createMode ? '/client/login' : '/client/create-account',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              foregroundColor: AppTheme.publicText,
              side: const BorderSide(color: AppTheme.publicLine),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            child: Text(switchLabel),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.go('/contact'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.publicMuted,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Need help first? Contact us'),
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
    final badge = createMode ? 'Client entry' : 'Client access';
    final heading = createMode
        ? 'Entry stays open. Activation stays controlled.'
        : 'A clear view without operator clutter.';
    final body = createMode
        ? 'Requesting access starts a controlled client path through review, onboarding, and activation.'
        : 'Clients should be able to review work, billing, reminders, and records without entering the operator workspace.';
    final points = createMode
        ? const [
            'Submit account request',
            'Review and onboarding',
            'Activation when ready',
          ]
        : const [
            'Service progress',
            'Invoices and payment status',
            'Reminders and statements',
            'Account history',
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
            style: Theme.of(context).textTheme.headlineSmall,
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
                  child: Icon(
                    Icons.circle,
                    size: 8,
                    color: AppTheme.publicAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    point,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            if (point != points.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.publicText,
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
