import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../models/learning_models.dart';
import '../repositories/operator_learning_repository.dart';
import '../widgets/operator_panel.dart';

/// Cost guardrails screen. Read existing rows; create / update via
/// upsert; show breach status.
class GuardrailsScreen extends StatefulWidget {
  const GuardrailsScreen({super.key});

  @override
  State<GuardrailsScreen> createState() => _GuardrailsScreenState();
}

class _GuardrailsScreenState extends State<GuardrailsScreen> {
  final OperatorLearningRepository _repo = OperatorLearningRepository();
  Future<List<CostGuardrailEntry>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _future = _repo.listGuardrails());
  }

  Future<void> _new() async {
    final res = await showDialog<_GuardrailDraft>(
      context: context,
      builder: (ctx) => const _GuardrailEditor(),
    );
    if (res == null) return;
    try {
      await _repo.upsertGuardrail(
        scope: res.scope,
        scopeId: res.scopeId,
        kind: res.kind,
        threshold: res.threshold,
        windowSeconds: res.windowSeconds,
        warningRatio: res.warningRatio,
        isActive: res.isActive,
      );
      _refresh();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upsert failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _Header(onRefresh: _refresh, onNew: _new),
        const SizedBox(height: 18),
        FutureBuilder<List<CostGuardrailEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }
            if (snapshot.hasError) {
              return OperatorErrorState(
                  title: 'Guardrails endpoint failed',
                  detail: '${snapshot.error}',
                  onRetry: _refresh);
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const OperatorEmptyState(
                title: 'No guardrails configured',
                body:
                    'Create one to enforce token / USD / decision / retry ceilings deterministically.',
              );
            }
            return Column(children: [
              for (final g in items) _GuardrailCard(item: g)
            ]);
          },
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh, required this.onNew});
  final VoidCallback onRefresh;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Row(
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
              Text('Cost guardrails',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                  'Deterministic enforcement of token / USD / decision / retry ceilings. Breaches write a LearningEvent; responding self-healing is reversible.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.muted, height: 1.35)),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: onNew,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New guardrail'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: AppTheme.background,
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh, color: AppTheme.muted),
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

class _GuardrailCard extends StatelessWidget {
  const _GuardrailCard({required this.item});
  final CostGuardrailEntry item;

  @override
  Widget build(BuildContext context) {
    final breached = item.breachCount > 0;
    final color = breached
        ? AppTheme.coRose
        : item.isActive
            ? AppTheme.coVerdant
            : AppTheme.subdued;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.kind,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              Text(item.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              'Scope: ${item.scope}${item.scopeId == null ? '' : ' · ${item.scopeId!}'}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.subdued)),
          const SizedBox(height: 4),
          Text(
              'Threshold: ${item.threshold.toStringAsFixed(2)} per ${item.windowSeconds}s (warning at ${(item.warningRatio * 100).toStringAsFixed(0)}%)',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.muted)),
          if (breached) ...[
            const SizedBox(height: 8),
            Text(
                'Breached ${item.breachCount}× · last at ${item.lastBreachAt?.toIso8601String() ?? "unknown"}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.coRose)),
          ],
        ],
      ),
    );
  }
}

class _GuardrailDraft {
  _GuardrailDraft({
    required this.scope,
    this.scopeId,
    required this.kind,
    required this.threshold,
    required this.windowSeconds,
    required this.warningRatio,
    required this.isActive,
  });

  final String scope;
  final String? scopeId;
  final String kind;
  final double threshold;
  final int windowSeconds;
  final double warningRatio;
  final bool isActive;
}

class _GuardrailEditor extends StatefulWidget {
  const _GuardrailEditor();

  @override
  State<_GuardrailEditor> createState() => _GuardrailEditorState();
}

class _GuardrailEditorState extends State<_GuardrailEditor> {
  String _scope = 'ORGANIZATION';
  String _kind = 'TOKENS_PER_HOUR';
  final _scopeIdCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController(text: '1000');
  final _windowCtrl = TextEditingController(text: '3600');
  final _warningCtrl = TextEditingController(text: '0.8');
  bool _active = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.panel,
      title: const Text('New cost guardrail',
          style: TextStyle(color: AppTheme.text)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Scope'),
              DropdownButton<String>(
                value: _scope,
                dropdownColor: AppTheme.panel,
                style: const TextStyle(color: AppTheme.text),
                items: const [
                  DropdownMenuItem(
                      value: 'ORGANIZATION', child: Text('ORGANIZATION')),
                  DropdownMenuItem(value: 'CLIENT', child: Text('CLIENT')),
                  DropdownMenuItem(
                      value: 'CAMPAIGN', child: Text('CAMPAIGN')),
                  DropdownMenuItem(value: 'GLOBAL', child: Text('GLOBAL')),
                ],
                onChanged: (v) => setState(() => _scope = v ?? _scope),
              ),
              _label('Scope id (optional)'),
              TextField(
                controller: _scopeIdCtrl,
                style: const TextStyle(color: AppTheme.text),
              ),
              _label('Kind'),
              DropdownButton<String>(
                value: _kind,
                dropdownColor: AppTheme.panel,
                style: const TextStyle(color: AppTheme.text),
                items: const [
                  DropdownMenuItem(
                      value: 'TOKENS_PER_HOUR',
                      child: Text('TOKENS_PER_HOUR')),
                  DropdownMenuItem(
                      value: 'TOKENS_PER_DAY', child: Text('TOKENS_PER_DAY')),
                  DropdownMenuItem(
                      value: 'USD_PER_HOUR', child: Text('USD_PER_HOUR')),
                  DropdownMenuItem(
                      value: 'USD_PER_DAY', child: Text('USD_PER_DAY')),
                  DropdownMenuItem(
                      value: 'AUTHORITY_DECISIONS_PER_HOUR',
                      child: Text('AUTHORITY_DECISIONS_PER_HOUR')),
                  DropdownMenuItem(
                      value: 'DISPATCH_RETRIES_PER_HOUR',
                      child: Text('DISPATCH_RETRIES_PER_HOUR')),
                ],
                onChanged: (v) => setState(() => _kind = v ?? _kind),
              ),
              _label('Threshold'),
              TextField(
                controller: _thresholdCtrl,
                style: const TextStyle(color: AppTheme.text),
                keyboardType: TextInputType.number,
              ),
              _label('Window (seconds)'),
              TextField(
                controller: _windowCtrl,
                style: const TextStyle(color: AppTheme.text),
                keyboardType: TextInputType.number,
              ),
              _label('Warning ratio (0–1)'),
              TextField(
                controller: _warningCtrl,
                style: const TextStyle(color: AppTheme.text),
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                value: _active,
                activeColor: AppTheme.accent,
                title:
                    const Text('Active', style: TextStyle(color: AppTheme.text)),
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final threshold = double.tryParse(_thresholdCtrl.text.trim());
            final window = int.tryParse(_windowCtrl.text.trim());
            final warning =
                double.tryParse(_warningCtrl.text.trim()) ?? 0.8;
            if (threshold == null || threshold <= 0 || window == null || window <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Threshold and window must be positive numbers.')));
              return;
            }
            Navigator.of(context).pop(_GuardrailDraft(
              scope: _scope,
              scopeId: _scopeIdCtrl.text.trim().isEmpty
                  ? null
                  : _scopeIdCtrl.text.trim(),
              kind: _kind,
              threshold: threshold,
              windowSeconds: window,
              warningRatio: warning,
              isActive: _active,
            ));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: AppTheme.background,
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.subdued, fontWeight: FontWeight.w700)),
      );
}
