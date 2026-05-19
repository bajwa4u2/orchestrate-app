import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../models/learning_models.dart';
import '../repositories/operator_learning_repository.dart';
import '../widgets/operator_panel.dart';

/// Playbooks lifecycle screen.
///   - List: CANDIDATE / ACTIVE / DISABLED / ARCHIVED, sorted by status
///     then confidence.
///   - Actions: activate (requires automation level + notes; LEVEL_3
///     blocked), disable (notes), archive, rollback execution.
class PlaybooksScreen extends StatefulWidget {
  const PlaybooksScreen({super.key});

  @override
  State<PlaybooksScreen> createState() => _PlaybooksScreenState();
}

class _PlaybooksScreenState extends State<PlaybooksScreen> {
  final OperatorLearningRepository _repo = OperatorLearningRepository();
  Future<List<PlaybookEntry>>? _future;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _future =
        _repo.listPlaybooks(status: _statusFilter, limit: 100));
  }

  Future<void> _activate(PlaybookEntry p) async {
    final res = await showDialog<_ActivationResult>(
      context: context,
      builder: (ctx) => _ActivateDialog(playbook: p),
    );
    if (res == null) return;
    try {
      await _repo.activatePlaybook(
        id: p.id,
        automationLevel: res.level,
        notes: res.notes.isEmpty ? null : res.notes,
      );
      _refresh();
    } catch (e) {
      _err('Activate failed: $e');
    }
  }

  Future<void> _disable(PlaybookEntry p) async {
    final note = await _promptNote(context, title: 'Disable "${p.name}"?');
    if (note == null) return;
    try {
      await _repo.disablePlaybook(id: p.id, notes: note.isEmpty ? null : note);
      _refresh();
    } catch (e) {
      _err('Disable failed: $e');
    }
  }

  Future<void> _archive(PlaybookEntry p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: Text('Archive "${p.name}"?',
            style: Theme.of(ctx).textTheme.titleLarge),
        content: Text(
            'Archived playbooks remain readable for audit but never fire again.',
            style: Theme.of(ctx)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.muted)),
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
              child: const Text('Archive')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.archivePlaybook(id: p.id);
      _refresh();
    } catch (e) {
      _err('Archive failed: $e');
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _Header(
          statusFilter: _statusFilter,
          onStatusChanged: (s) {
            setState(() => _statusFilter = s);
            _refresh();
          },
          onRefresh: _refresh,
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<PlaybookEntry>>(
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
                  title: 'Playbooks endpoint failed',
                  detail: '${snapshot.error}',
                  onRetry: _refresh);
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const OperatorEmptyState(
                title: 'No playbooks in this status',
                body:
                    'The playbook catalog has not produced rows for this filter. The boot-time GLOBAL seed handles 10 templates; pattern-derived candidates appear here over time.',
              );
            }
            return Column(
              children: [
                for (final p in items)
                  _PlaybookCard(
                    item: p,
                    onActivate: _activate,
                    onDisable: _disable,
                    onArchive: _archive,
                  ),
              ],
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
    required this.statusFilter,
    required this.onStatusChanged,
    required this.onRefresh,
  });
  final String? statusFilter;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onRefresh;

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
              Text('Playbooks', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                  'CANDIDATE → ACTIVE is an explicit operator transition. LEVEL_3 is permanently disabled. Disable/archive are reversible vs irreversible respectively.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.muted, height: 1.35)),
            ],
          ),
        ),
        DropdownButton<String?>(
          value: statusFilter,
          dropdownColor: AppTheme.panel,
          style: const TextStyle(color: AppTheme.text),
          iconEnabledColor: AppTheme.subdued,
          underline: const SizedBox.shrink(),
          hint: const Text('All statuses',
              style: TextStyle(color: AppTheme.subdued)),
          items: const [
            DropdownMenuItem<String?>(value: null, child: Text('All')),
            DropdownMenuItem<String?>(
                value: 'CANDIDATE', child: Text('CANDIDATE')),
            DropdownMenuItem<String?>(value: 'ACTIVE', child: Text('ACTIVE')),
            DropdownMenuItem<String?>(
                value: 'DISABLED', child: Text('DISABLED')),
            DropdownMenuItem<String?>(
                value: 'ARCHIVED', child: Text('ARCHIVED')),
          ],
          onChanged: onStatusChanged,
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

class _PlaybookCard extends StatelessWidget {
  const _PlaybookCard({
    required this.item,
    required this.onActivate,
    required this.onDisable,
    required this.onArchive,
  });

  final PlaybookEntry item;
  final ValueChanged<PlaybookEntry> onActivate;
  final ValueChanged<PlaybookEntry> onDisable;
  final ValueChanged<PlaybookEntry> onArchive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.name,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              _Chip(
                  label: item.status, color: _statusColor(item.status)),
              const SizedBox(width: 6),
              _Chip(label: item.automationLevel, color: AppTheme.subdued),
              const SizedBox(width: 6),
              _Chip(label: item.scopeType, color: AppTheme.subdued),
            ],
          ),
          const SizedBox(height: 6),
          Text(
              'Key: ${item.playbookKey} · Confidence ${(item.confidenceScore * 100).toStringAsFixed(0)}%',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.subdued)),
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.description!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.muted, height: 1.4)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Updated ${_ago(item.updatedAt)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.subdued)),
              const Spacer(),
              if (item.status == 'CANDIDATE')
                ElevatedButton(
                  onPressed: () => onActivate(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.background,
                  ),
                  child: const Text('Activate'),
                ),
              if (item.status == 'ACTIVE') ...[
                OutlinedButton(
                  onPressed: () => onDisable(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.muted,
                    side: const BorderSide(color: AppTheme.lineSoft),
                  ),
                  child: const Text('Disable'),
                ),
              ],
              if (item.status == 'DISABLED' ||
                  item.status == 'CANDIDATE') ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => onArchive(item),
                  child: const Text('Archive',
                      style: TextStyle(color: AppTheme.rose)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return AppTheme.emerald;
      case 'CANDIDATE':
        return AppTheme.amber;
      case 'DISABLED':
        return AppTheme.subdued;
      case 'ARCHIVED':
        return AppTheme.rose;
      default:
        return AppTheme.subdued;
    }
  }

  static String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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

class _ActivationResult {
  _ActivationResult({required this.level, required this.notes});
  final String level;
  final String notes;
}

class _ActivateDialog extends StatefulWidget {
  const _ActivateDialog({required this.playbook});
  final PlaybookEntry playbook;

  @override
  State<_ActivateDialog> createState() => _ActivateDialogState();
}

class _ActivateDialogState extends State<_ActivateDialog> {
  String _level = 'LEVEL_0';
  final _notesController = TextEditingController();

  static const _levels = [
    ('LEVEL_0', 'Suggestion-only — no auto action.'),
    ('LEVEL_1', 'Auto reversible action (allowlisted kinds only).'),
    ('LEVEL_2', 'Operator-confirmed action.'),
    // LEVEL_3 intentionally absent — reserved / blocked.
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.panel,
      title: Text('Activate ${widget.playbook.name}',
          style: Theme.of(context).textTheme.titleLarge),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Choose the automation level. LEVEL_3 is reserved and not selectable. Acceptance creates a PlaybookFeedback row (OPERATOR_APPROVED).',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.muted)),
            const SizedBox(height: 12),
            for (final lvl in _levels)
              RadioListTile<String>(
                value: lvl.$1,
                groupValue: _level,
                activeColor: AppTheme.accent,
                title: Text(lvl.$1,
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(lvl.$2,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.muted)),
                onChanged: (v) {
                  if (v != null) setState(() => _level = v);
                },
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.text),
              decoration: const InputDecoration(
                hintText: 'Notes (audit-visible).',
                hintStyle: TextStyle(color: AppTheme.subdued),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(
              _ActivationResult(level: _level, notes: _notesController.text.trim())),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: AppTheme.background,
          ),
          child: const Text('Activate'),
        ),
      ],
    );
  }
}

Future<String?> _promptNote(BuildContext context,
    {required String title}) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.panel,
      title: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        style: const TextStyle(color: AppTheme.text),
        decoration: const InputDecoration(
          hintText: 'Optional notes (audit-visible).',
          hintStyle: TextStyle(color: AppTheme.subdued),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: AppTheme.background,
          ),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}
