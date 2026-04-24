import 'package:flutter/material.dart';

import 'package:orchestrate_app/data/repositories/operator_repository.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';

class OperatorDebugScreen extends StatelessWidget {
  const OperatorDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DebugViewData>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(
              child: Text('System checks could not load right now.'));
        }
        final data = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppTheme.panel,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppTheme.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System checks',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppTheme.subdued),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Context and command signal',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This view keeps operational context and command signals separate from the primary command center.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _Panel(
                  title: 'Resolved operator context', rows: data.contextRows),
              const SizedBox(height: 18),
              _Panel(title: 'Command overview markers', rows: data.commandRows),
            ],
          ),
        );
      },
    );
  }

  Future<_DebugViewData> _load() async {
    final repo = OperatorRepository();
    final context = await repo.fetchAuthContext();
    final command = await repo.fetchCommandOverview();

    return _DebugViewData(
      contextRows: context.entries
          .map((entry) => '${_label(entry.key)}: ${entry.value}')
          .toList(),
      commandRows: command.entries
          .take(12)
          .map((entry) => '${_label(entry.key)}: ${entry.value}')
          .toList(),
    );
  }
}

class _DebugViewData {
  const _DebugViewData({required this.contextRows, required this.commandRows});

  final List<String> contextRows;
  final List<String> commandRows;
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.rows});

  final String title;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Text('Nothing is visible here right now.',
                style: Theme.of(context).textTheme.bodyMedium)
          else
            for (int i = 0; i < rows.length; i++) ...[
              Text(rows[i], style: Theme.of(context).textTheme.bodyMedium),
              if (i != rows.length - 1) const Divider(height: 22),
            ],
        ],
      ),
    );
  }
}

String _label(String key) {
  return key
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAll('_', ' ')
      .toLowerCase();
}
