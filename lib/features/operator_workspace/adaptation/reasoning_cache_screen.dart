import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../models/convergence_models.dart';
import '../repositories/operator_learning_repository.dart';
import '../widgets/operator_panel.dart';

/// Reasoning cache inspector. Operators can browse stored AI
/// answers, see hit counts, and invalidate stale entries when a
/// doctrine change makes a cached answer inert.
class ReasoningCacheScreen extends StatefulWidget {
  const ReasoningCacheScreen({super.key});

  @override
  State<ReasoningCacheScreen> createState() => _ReasoningCacheScreenState();
}

class _ReasoningCacheScreenState extends State<ReasoningCacheScreen> {
  final OperatorLearningRepository _repo = OperatorLearningRepository();
  Future<List<ReasoningCacheEntry>>? _future;
  String? _source;

  static const _sources = [
    'AUTHORITY_DECISION',
    'GOVERNANCE_REVIEW',
    'RECOVERY_PLAN',
    'CODE_UPGRADE',
    'DESIGN_REVIEW',
    'DIAGNOSTIC',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() =>
        _future = _repo.listReasoningCache(source: _source, limit: 100));
  }

  Future<void> _invalidate(ReasoningCacheEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: Text('Invalidate cache entry?',
            style: Theme.of(ctx).textTheme.titleLarge),
        content: Text(
          'Fingerprint ${entry.fingerprint.substring(0, 12)}… (source ${entry.source}). The next preflight for this fingerprint will escalate to AI.',
          style: Theme.of(ctx)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.muted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.rose,
              foregroundColor: AppTheme.background,
            ),
            child: const Text('Invalidate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.invalidateReasoningCacheEntry(id: entry.id);
      _refresh();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Invalidate failed: $e')));
    }
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
                  Text('Reasoning cache',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                      'Durable AI reasoning cache. Hits short-circuit AI invocation. Invalidate when doctrine changes make an answer inert.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.muted, height: 1.35)),
                ],
              ),
            ),
            DropdownButton<String?>(
              value: _source,
              dropdownColor: AppTheme.panel,
              style: const TextStyle(color: AppTheme.text),
              iconEnabledColor: AppTheme.subdued,
              underline: const SizedBox.shrink(),
              hint: const Text('All sources',
                  style: TextStyle(color: AppTheme.subdued)),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('All')),
                for (final s in _sources)
                  DropdownMenuItem<String?>(value: s, child: Text(s)),
              ],
              onChanged: (v) {
                setState(() => _source = v);
                _refresh();
              },
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, color: AppTheme.muted),
              onPressed: _refresh,
            ),
          ],
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<ReasoningCacheEntry>>(
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
                  title: 'Reasoning cache endpoint failed',
                  detail: '${snapshot.error}',
                  onRetry: _refresh);
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const OperatorEmptyState(
                title: 'No cached reasoning rows in this slice',
                body:
                    'Cache fills as AI calls land via the containment gateway. Empty either because no calls occurred yet, or TTL expired everything.',
              );
            }
            return Column(
              children: [
                for (final entry in items)
                  _CacheCard(item: entry, onInvalidate: _invalidate),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _CacheCard extends StatelessWidget {
  const _CacheCard({required this.item, required this.onInvalidate});
  final ReasoningCacheEntry item;
  final ValueChanged<ReasoningCacheEntry> onInvalidate;

  @override
  Widget build(BuildContext context) {
    final expired = item.expiresAt.isBefore(DateTime.now());
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
            color: expired ? AppTheme.subdued : AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Chip(label: item.source, color: AppTheme.accent),
              if (item.modelKey != null) ...[
                const SizedBox(width: 6),
                _Chip(label: item.modelKey!, color: AppTheme.subdued),
              ],
              const Spacer(),
              Text('hits ${item.hits}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppTheme.emerald)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Fingerprint: ${item.fingerprint.substring(0, 16)}…',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.muted,
                fontSize: 12,
              )),
          if (item.summary != null && item.summary!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.summary!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.muted, height: 1.35)),
          ],
          const SizedBox(height: 8),
          Text(
              'Tokens: prompt ${item.promptTokens} · completion ${item.completionTokens}'
              '${item.estimatedCostUsd == null ? "" : " · estimated cost \$${item.estimatedCostUsd!.toStringAsFixed(4)}"}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.subdued)),
          const SizedBox(height: 4),
          Text(
              'Last hit ${item.lastHitAt == null ? "—" : item.lastHitAt!.toIso8601String()} · '
              'expires ${item.expiresAt.toIso8601String()}${expired ? " (expired)" : ""}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.subdued)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: () => onInvalidate(item),
                child: const Text('Invalidate',
                    style: TextStyle(color: AppTheme.rose)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
