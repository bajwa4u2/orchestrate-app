import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';

class ClientBrandingScreen extends StatelessWidget {
  const ClientBrandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _HoldingSurface(
            eyebrow: 'Branding',
            title: 'Brand controls are not enabled yet',
            body:
                'Identity, templates, and signatures will appear here when they are available for this account. Your campaign and account settings remain separate.',
          ),
        ],
      ),
    );
  }
}

class _HoldingSurface extends StatelessWidget {
  const _HoldingSurface(
      {required this.eyebrow, required this.title, required this.body});

  final String eyebrow;
  final String title;
  final String body;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
