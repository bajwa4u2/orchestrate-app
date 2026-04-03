import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/section_header.dart';
import '../core/widgets/surface.dart';

class SystemScreen extends StatelessWidget {
  const SystemScreen({super.key, this.title = 'System', this.subtitle = 'Operational posture, configuration, and readiness.'});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: title, subtitle: subtitle),
            const SizedBox(height: 24),
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This surface is now part of the grouped operator architecture and ready for backend-aligned implementation.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      _Pill(label: 'Operator layer'),
                      _Pill(label: 'Backend aligned'),
                      _Pill(label: 'Ready for execution'),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.panelSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: Text(
                      'This route is intentionally held inside the new shell so it can be completed without drifting back into the older flat navigation model.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                    ),
                  ),
                ],
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.panelRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
