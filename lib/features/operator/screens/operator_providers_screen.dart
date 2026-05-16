import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';

class OperatorProvidersScreen extends StatelessWidget {
  const OperatorProvidersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Text(
              'Providers could not load at the moment.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }
        final items = (snapshot.data!['items'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: _operatorCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Providers',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppTheme.subdued),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Availability and fallback posture',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Provider governance lives here so vendor truth stays separate from campaign or client views.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: _operatorCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current registry status',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    if (items.isEmpty)
                      Text(
                        'No provider status is visible at the moment.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      for (int i = 0; i < items.length; i++) ...[
                        _Item(item: items[i]),
                        if (i != items.length - 1)
                          const Divider(height: 22, color: AppTheme.line),
                      ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _load() async {
    final json = await ApiClient()
        .getJson('/providers/status', surface: ApiSurface.operator);
    return Map<String, dynamic>.from(json as Map);
  }
}

BoxDecoration _operatorCardDecoration() {
  return BoxDecoration(
    color: AppTheme.panel,
    borderRadius: BorderRadius.circular(AppTheme.radius),
    border: Border.all(color: AppTheme.line),
  );
}

class _Item extends StatelessWidget {
  const _Item({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final name = (item['key'] ?? item['name'] ?? 'Provider').toString();
    final available = item['available'] == true;
    final kind = (item['kind'] ?? '').toString().trim();
    final reason = (item['reason'] ?? '').toString().trim();
    final configured = (item['configured'] ?? '').toString().trim();

    final statusColor = available ? AppTheme.emerald : AppTheme.rose;
    final secondary = [
      if (reason.isNotEmpty) reason,
      if (configured.isNotEmpty) 'configured: $configured',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 8, right: 10),
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    [
                      available ? 'Available' : 'Unavailable',
                      if (kind.isNotEmpty) kind,
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (secondary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      secondary,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.subdued),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
