import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../models/learning_models.dart';
import '../repositories/operator_learning_repository.dart';
import '../widgets/operator_panel.dart';

/// Suggestions queue. Accept / reject converts the suggestion;
/// acceptance separately creates a SelfHealingAction (operator
/// triggers that explicitly from the healing surface).
class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  final OperatorLearningRepository _repo = OperatorLearningRepository();
  Future<List<PolicySuggestionEntry>>? _future;
  String _statusFilter = 'PROPOSED';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _future =
        _repo.listSuggestions(status: _statusFilter, limit: 100));
  }

  Future<void> _accept(PolicySuggestionEntry s) async {
    final note = await _promptNote(context, title: 'Accept "${s.proposalTitle}"?');
    if (note == null) return;
    try {
      await _repo.acceptSuggestion(id: s.id, notes: note.isEmpty ? null : note);
      _refresh();
    } catch (e) {
      _showError('Accept failed: $e');
    }
  }

  Future<void> _reject(PolicySuggestionEntry s) async {
    final note = await _promptNote(context, title: 'Reject "${s.proposalTitle}"?');
    if (note == null) return;
    try {
      await _repo.rejectSuggestion(id: s.id, notes: note.isEmpty ? null : note);
      _refresh();
    } catch (e) {
      _showError('Reject failed: $e');
    }
  }

  void _showError(String msg) {
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
        FutureBuilder<List<PolicySuggestionEntry>>(
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
                  title: 'Suggestions endpoint failed',
                  detail: '${snapshot.error}',
                  onRetry: _refresh);
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const OperatorEmptyState(
                title: 'No suggestions in this status',
                body:
                    'The learning layer has not surfaced anything for review. Switch the filter to see ACCEPTED / REJECTED / EXPIRED / APPLIED.',
              );
            }
            return Column(
              children: [
                for (final s in items)
                  _SuggestionCard(
                      item: s, onAccept: _accept, onReject: _reject),
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
  final String statusFilter;
  final ValueChanged<String> onStatusChanged;
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
              Text('Policy adjustment suggestions',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                  'Suggestions are append-only proposals. Acceptance flips status; it does NOT auto-apply. Self-healing is invoked separately, with full audit.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.muted, height: 1.35)),
            ],
          ),
        ),
        DropdownButton<String>(
          value: statusFilter,
          dropdownColor: AppTheme.panel,
          style: const TextStyle(color: AppTheme.text),
          iconEnabledColor: AppTheme.subdued,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 'PROPOSED', child: Text('PROPOSED')),
            DropdownMenuItem(value: 'ACCEPTED', child: Text('ACCEPTED')),
            DropdownMenuItem(value: 'REJECTED', child: Text('REJECTED')),
            DropdownMenuItem(value: 'EXPIRED', child: Text('EXPIRED')),
            DropdownMenuItem(value: 'APPLIED', child: Text('APPLIED')),
          ],
          onChanged: (v) {
            if (v != null) onStatusChanged(v);
          },
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

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.item,
    required this.onAccept,
    required this.onReject,
  });
  final PolicySuggestionEntry item;
  final ValueChanged<PolicySuggestionEntry> onAccept;
  final ValueChanged<PolicySuggestionEntry> onReject;

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
                child: Text(item.proposalTitle,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              _StatusChip(status: item.status),
            ],
          ),
          const SizedBox(height: 8),
          Text('Category: ${item.category}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.subdued)),
          const SizedBox(height: 8),
          Text(item.proposalRationale,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.muted, height: 1.4)),
          if (item.proposalJson != null) ...[
            const SizedBox(height: 10),
            _JsonPreview(label: 'Proposal payload', data: item.proposalJson!),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Created ${_ago(item.createdAt)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.subdued)),
              if (item.sourcePatternId != null)
                Text('Pattern ${item.sourcePatternId!.substring(0, 8)}…',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.subdued)),
              const Spacer(),
              if (item.status == 'PROPOSED') ...[
                OutlinedButton(
                  onPressed: () => onReject(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.muted,
                    side: const BorderSide(color: AppTheme.lineSoft),
                  ),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => onAccept(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.background,
                  ),
                  child: const Text('Accept'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'ACCEPTED' || 'APPLIED' => AppTheme.emerald,
      'REJECTED' || 'EXPIRED' => AppTheme.subdued,
      _ => AppTheme.amber,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(status,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _JsonPreview extends StatelessWidget {
  const _JsonPreview({required this.label, required this.data});
  final String label;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppTheme.subdued)),
          const SizedBox(height: 6),
          SelectableText(
            _format(data),
            style: const TextStyle(
              fontFamily: 'monospace',
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _format(Map<String, dynamic> data) {
    final buf = StringBuffer();
    data.forEach((k, v) {
      buf.writeln('  $k: $v');
    });
    return buf.toString().trimRight();
  }
}

Future<String?> _promptNote(BuildContext context,
    {required String title}) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.panel,
      title:
          Text(title, style: Theme.of(ctx).textTheme.titleLarge),
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
          child: const Text('Cancel'),
        ),
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
