import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';

class ClientNewsletterScreen extends StatelessWidget {
  const ClientNewsletterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _HoldingSurface(
            eyebrow: 'Newsletter',
            title: 'Audience and issue controls are reserved here',
            body:
                'This surface is intentionally present now so newsletter remains part of both public and client systems. Builder-grade controls can be connected here without inventing fake campaign or mailbox logic today.',
          ),
        ],
      ),
    );
  }
}

class _HoldingSurface extends StatelessWidget {
  const _HoldingSurface({required this.eyebrow, required this.title, required this.body});

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
        borderRadius: BorderRadius.circular(28),
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
