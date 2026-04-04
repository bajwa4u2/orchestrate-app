import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand/brand_assets.dart';
import '../../core/theme/app_theme.dart';

class OpsLoginScreen extends StatelessWidget {
  const OpsLoginScreen({super.key});

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

                    final form = const _AccessCard();
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

class _AccessCard extends StatelessWidget {
  const _AccessCard();

  @override
  Widget build(BuildContext context) {
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
            'Operator access',
            style: Theme.of(context).textTheme.headlineMedium,
          ),

          const SizedBox(height: 10),

          Text(
            'Sign in to enter the working system.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),

          const SizedBox(height: 28),

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
            child: const Text('Sign in'),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.g_mobiledata),
            label: const Text('Continue with Google'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(16),
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
              'Operator workspace',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.publicAccent,
                  ),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Access stays controlled.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),

          const SizedBox(height: 12),

          Text(
            'This path enters the operational layer of the system. It is provisioned deliberately because it carries execution, billing, deliverability, and records.',
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
            const SizedBox(height: 12),
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