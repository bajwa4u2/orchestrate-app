import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../models/convergence_models.dart';
import '../repositories/operator_learning_repository.dart';
import '../widgets/operator_panel.dart';

/// Escalations: why the containment pipeline missed and the system
/// had to invoke AI. Operator can filter by reason / severity and
/// see open vs resolved.
class EscalationsScreen extends StatefulWidget {
  const EscalationsScreen({super.key});

  @override
  State<EscalationsScreen> createState() => _EscalationsScreenState();
}

class _EscalationsScreenState extends State<EscalationsScreen> {
  final OperatorLearningRepository _repo = OperatorLearningRepository();
  Future<List<EscalationEntry>>? _future;
  String? _reason;
  String? _severity;
  bool _onlyOpen = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _future = _repo.listEscalations(
          reason: _reason,
          severity: _severity,
          onlyOpen: _onlyOpen,
          limit: 200,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _Header(
          reason: _reason,
          severity: _severity,
          onlyOpen: _onlyOpen,
          onReason: (v) {
            setState(() => _reason = v);
            _refresh();
          },
          onSeverity: (v) {
            setState(() => _severity = v);
            _refresh();
          },
          onOnlyOpen: (v) {
            setState(() => _onlyOpen = v);
            _refresh();
          },
          onRefresh: _refresh,
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<EscalationEntry>>(
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
                  title: 'Escalations endpoint failed',
                  detail: '${snapshot.error}',
                  onRetry: _refresh);
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const OperatorEmptyState(
                title: 'No escalations match this filter',
                body:
                    'Either the containment pipeline absorbed everything, or the filter excludes the open rows.',
              );
            }
            return Column(
              children: [for (final e in items) _EscalationCard(item: e)],
            );
          },
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.reason,
    required this.severity,
    required this.onlyOpen,
    required this.onReason,
    required this.onSeverity,
    required this.onOnlyOpen,
    required this.onRefresh,
  });

  final String? reason;
  final String? severity;
  final bool onlyOpen;
  final ValueChanged<String?> onReason;
  final ValueChanged<String?> onSeverity;
  final ValueChanged<bool> onOnlyOpen;
  final VoidCallback onRefresh;

  static const _reasons = [
    'NOVELTY',
    'CONFIDENCE_COLLAPSE',
    'AMBIGUITY_THRESHOLD',
    'POLICY_ESCALATION',
    'NO_PLAYBOOK_MATCH',
    'NO_MEMORY_MATCH',
    'NO_CACHED_GOVERNANCE',
    'NO_PRIOR_RECOVERY',
    'UNKNOWN_PROVIDER_BEHAVIOR',
    'OPERATOR_REQUEST',
  ];
  static const _severities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Adaptation',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.subdued)),
        const SizedBox(height: 4),
        Text('Escalation triggers',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
            'Append-only record of why the AI containment layer had to invoke AI. Each open row is a residual cognition surface.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.muted, height: 1.35)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String?>(
              value: reason,
              dropdownColor: AppTheme.panel,
              style: const TextStyle(color: AppTheme.text),
              iconEnabledColor: AppTheme.subdued,
              underline: const SizedBox.shrink(),
              hint: const Text('All reasons',
                  style: TextStyle(color: AppTheme.subdued)),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('All reasons')),
                for (final r in _reasons)
                  DropdownMenuItem<String?>(value: r, child: Text(r)),
              ],
              onChanged: onReason,
            ),
            DropdownButton<String?>(
              value: severity,
              dropdownColor: AppTheme.panel,
              style: const TextStyle(color: AppTheme.text),
              iconEnabledColor: AppTheme.subdued,
              underline: const SizedBox.shrink(),
              hint: const Text('All severities',
                  style: TextStyle(color: AppTheme.subdued)),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('All severities')),
                for (final s in _severities)
                  DropdownMenuItem<String?>(value: s, child: Text(s)),
              ],
              onChanged: onSeverity,
            ),
            FilterChip(
              label: const Text('Only open'),
              selected: onlyOpen,
              backgroundColor: AppTheme.panel,
              selectedColor: AppTheme.accentSoft,
              labelStyle: const TextStyle(color: AppTheme.text),
              onSelected: onOnlyOpen,
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, color: AppTheme.muted),
              onPressed: onRefresh,
            ),
          ],
        ),
      ],
    );
  }
}

class _EscalationCard extends StatelessWidget {
  const _EscalationCard({required this.item});
  final EscalationEntry item;

  @override
  Widget build(BuildContext context) {
    final resolved = item.resolvedAt != null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
            color: resolved
                ? AppTheme.line
                : AppTheme.amber.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Chip(label: item.reason, color: _reasonColor(item.reason)),
              const SizedBox(width: 6),
              _Chip(label: item.severity, color: _sevColor(item.severity)),
              const Spacer(),
              Text(_ago(item.triggeredAt),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.subdued)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Fingerprint: ${item.fingerprint.substring(0, 16)}…',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.muted,
                fontSize: 12,
              )),
          if (item.contextJson != null && item.contextJson!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: AppTheme.panelSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.line),
              ),
              child: SelectableText(
                _format(item.contextJson!),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppTheme.muted,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (resolved)
                Text(
                  'Resolved ${_ago(item.resolvedAt!)} via ${item.resolutionRefType ?? "n/a"}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.emerald),
                )
              else
                const Text('Open',
                    style: TextStyle(
                        color: AppTheme.amber, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Color _reasonColor(String r) {
    if (r == 'POLICY_ESCALATION' || r == 'OPERATOR_REQUEST') {
      return AppTheme.accent;
    }
    if (r == 'NOVELTY' || r == 'AMBIGUITY_THRESHOLD') {
      return AppTheme.amber;
    }
    return AppTheme.subdued;
  }

  Color _sevColor(String s) {
    return switch (s) {
      'CRITICAL' => AppTheme.rose,
      'HIGH' => AppTheme.rose,
      'MEDIUM' => AppTheme.amber,
      _ => AppTheme.subdued,
    };
  }

  static String _format(Map<String, dynamic> data) {
    final buf = StringBuffer();
    data.forEach((k, v) => buf.writeln('  $k: $v'));
    return buf.toString().trimRight();
  }

  static String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
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
