import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../models/learning_models.dart';
import '../repositories/operator_learning_repository.dart';
import '../widgets/operator_panel.dart';

class OperationalMemoryScreen extends StatefulWidget {
  const OperationalMemoryScreen({super.key});

  @override
  State<OperationalMemoryScreen> createState() =>
      _OperationalMemoryScreenState();
}

class _OperationalMemoryScreenState extends State<OperationalMemoryScreen> {
  final OperatorLearningRepository _repo = OperatorLearningRepository();
  Future<List<OperationalMemoryEntry>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _future = _repo.listMemory(limit: 100));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adaptation',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppTheme.subdued)),
                  const SizedBox(height: 4),
                  Text('Operational memory',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                      'Key/value rollups derived deterministically from the learning journal. Read-only.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.muted, height: 1.35)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, color: AppTheme.muted),
              onPressed: _refresh,
            ),
          ],
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<OperationalMemoryEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))));
            }
            if (snapshot.hasError) {
              return OperatorErrorState(
                  title: 'Operational memory endpoint failed',
                  detail: '${snapshot.error}',
                  onRetry: _refresh);
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const OperatorEmptyState(
                title: 'No memory entries',
                body: 'The rollup table is empty for this scope.',
              );
            }
            return Column(
              children: [
                for (final m in items)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: AppTheme.panelSoft,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('${m.scope} · ${m.key}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                            ),
                            Text(
                                _ago(m.lastObservedAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.subdued)),
                          ],
                        ),
                        if (m.valueJson != null &&
                            m.valueJson!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.fromLTRB(
                                10, 8, 10, 8),
                            decoration: BoxDecoration(
                              color: AppTheme.panel,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.line),
                            ),
                            child: SelectableText(
                              _format(m.valueJson!),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: AppTheme.muted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  static String _format(Map<String, dynamic> data) {
    final buf = StringBuffer();
    data.forEach((k, v) => buf.writeln('  $k: $v'));
    return buf.toString().trimRight();
  }

  static String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
