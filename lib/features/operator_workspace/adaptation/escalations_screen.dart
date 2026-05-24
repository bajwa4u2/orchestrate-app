import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/widgets/substrate_chip.dart';
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
                : AppTheme.coSun.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SubstrateChip(
                label: item.reason,
                state: _reasonState(item.reason),
              ),
              const SizedBox(width: 6),
              SubstrateChip(
                label: item.severity,
                state: _sevState(item.severity),
              ),
              if (_isFallbackContext(item.contextJson)) ...[
                const SizedBox(width: 6),
                SubstrateChip(
                  label: _fallbackLabel(item.contextJson) ??
                      'DETERMINISTIC FALLBACK',
                  state: SubstrateChipState.teal,
                ),
              ],
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
                      ?.copyWith(color: AppTheme.coVerdant),
                )
              else
                const Text('Open',
                    style: TextStyle(
                        color: AppTheme.coSun, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  // Canonical SubstrateChipState mapping for escalation reason +
  // severity enums per `system/topology/topology-grammar.md` §6.
  SubstrateChipState _reasonState(String r) {
    if (r == 'POLICY_ESCALATION' || r == 'OPERATOR_REQUEST') {
      return SubstrateChipState.teal;
    }
    if (r == 'NOVELTY' || r == 'AMBIGUITY_THRESHOLD') {
      return SubstrateChipState.sun;
    }
    return SubstrateChipState.mist;
  }

  SubstrateChipState _sevState(String s) {
    return switch (s) {
      'CRITICAL' || 'HIGH' => SubstrateChipState.rose,
      'MEDIUM' => SubstrateChipState.sun,
      _ => SubstrateChipState.mist,
    };
  }

  static String _format(Map<String, dynamic> data) {
    final buf = StringBuffer();
    data.forEach((k, v) => buf.writeln('  $k: $v'));
    return buf.toString().trimRight();
  }

  static bool _isFallbackContext(Map<String, dynamic>? context) {
    if (context == null) return false;
    final kind = context['kind']?.toString();
    return kind == 'ai_call_failure' ||
        kind == 'governance_execution_mismatch' ||
        context['executionMode']?.toString() == 'deterministic_fallback' ||
        context['executionMode']?.toString() == 'cooldown_fallback';
  }

  static String? _fallbackLabel(Map<String, dynamic>? context) {
    if (context == null) return null;
    final kind = context['kind']?.toString();
    final mode = context['executionMode']?.toString();
    if (mode == 'cooldown_fallback') return 'COOLDOWN FALLBACK';
    if (kind == 'governance_execution_mismatch') return 'GOVERNANCE/EXEC MISMATCH';
    if (kind == 'ai_call_failure') return 'AI FAILURE FALLBACK';
    if (mode == 'deterministic_fallback') return 'DETERMINISTIC FALLBACK';
    return null;
  }

  static String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// _Chip removed — replaced by canonical SubstrateChip
// (`core/widgets/substrate_chip.dart`). The previous Container+Text
// implementation rendered the same shape but without mono uppercase
// typography. Migrating preserves substrate-substantive visual
// continuity with the public website's chip rendering.
