import 'package:flutter/material.dart';

import '../../data/models/resource_item.dart';
import '../theme/app_theme.dart';
import 'surface.dart';

class ResourceTable extends StatelessWidget {
  const ResourceTable(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.items,
      required this.emptyLabel});

  final String title;
  final String subtitle;
  final List<ResourceItem> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Text(emptyLabel,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppTheme.muted)),
            )
          else
            Column(
              children: [
                for (final item in items.take(12)) ...[
                  _Row(item: item),
                  if (item != items.take(12).last) const Divider(height: 24),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});
  final ResourceItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child:
              Text(item.title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          flex: 2,
          child: Text(item.primary,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.text)),
        ),
        Expanded(
          flex: 3,
          child: Text(item.secondary.isEmpty ? '—' : item.secondary,
              style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
