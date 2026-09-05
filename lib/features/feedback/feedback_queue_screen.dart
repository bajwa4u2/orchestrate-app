import 'package:flutter/material.dart';

import '../../data/repositories/product_feedback_repository.dart';
import 'package:orchestrate_app/features/ops_console/ops_empty_state.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';

/// THE OPERATOR'S SIDE OF THE LOOP.
///
/// A feedback form whose submissions land in a table nobody opens is worse
/// than no form: it teaches people that telling us things is pointless while
/// letting us believe we are listening. So this is the smallest surface that
/// lets someone work the queue — read it, say what was done, and say where it
/// shipped.
///
/// Deliberately not a dashboard. No charts, no sentiment, no volume trends.
/// The unit of work is one person's message.
class FeedbackQueueScreen extends StatefulWidget {
  const FeedbackQueueScreen({super.key});

  @override
  State<FeedbackQueueScreen> createState() => _FeedbackQueueScreenState();
}

class _FeedbackQueueScreenState extends State<FeedbackQueueScreen> {
  final _repository = ProductFeedbackRepository();

  // Open work first. Somebody arriving here is working the queue, not
  // browsing what has already been dealt with.
  String _state = 'RECEIVED';
  late Future<List<Map<String, dynamic>>> _future;

  static const _states = <String, String>{
    'RECEIVED': 'New',
    'REVIEWED': 'Read',
    'ACTIONED': 'Acted on',
    'CLOSED': 'Closed',
    '': 'All',
  };

  @override
  void initState() {
    super.initState();
    _future = _repository.queue(state: _state);
  }

  void _reload() {
    setState(() => _future = _repository.queue(state: _state));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A heading like every other operator surface, rather than an AppBar
          // band. This was the one screen still wearing a Scaffold, which is
          // why it looked like a different product.
          Text('Feedback', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 5),
          const Text(
            'What people using Orchestrate have told us, and what was done '
            'about it.',
            style: TextStyle(fontSize: 13, color: AppTheme.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                for (final entry in _states.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _state == entry.key,
                    onSelected: (_) {
                      _state = entry.key;
                      _reload();
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Could not load the feedback queue.'),
                    ),
                  );
                }
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return OpsEmptyState(
                    headline: 'Nothing ${_states[_state]?.toLowerCase() ?? 'here'}.',
                    detail: 'Feedback arrives from people using the product. '
                        'Nothing is waiting in this state right now.',
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _QueueRow(
                    row: items[i],
                    onTriage: () => _openTriage(items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      );
  }

  Future<void> _openTriage(Map<String, dynamic> row) async {
    final outcome = TextEditingController();
    final note = TextEditingController();
    final release = TextEditingController();
    String state = 'REVIEWED';

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Triage ${row['ref']}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: state,
                    decoration: const InputDecoration(labelText: 'Move to'),
                    items: const [
                      DropdownMenuItem(value: 'REVIEWED', child: Text('Read')),
                      DropdownMenuItem(
                          value: 'ACTIONED', child: Text('Acted on')),
                      DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
                    ],
                    onChanged: (v) => setDialogState(() => state = v ?? state),
                  ),
                  const SizedBox(height: 12),
                  // Shown to the person. ACTIONED is refused without it.
                  TextField(
                    controller: outcome,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'What was done (the person sees this)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: release,
                    decoration: const InputDecoration(
                      labelText: 'Where it shipped — version, build or commit',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Internal note (never shown)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (save != true) return;
    try {
      await _repository.triage(
        id: (row['id'] ?? '').toString(),
        state: state,
        outcome: outcome.text,
        operatorNote: note.text,
        releaseRef: release.text,
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      // The server refuses for real reasons — ACTIONED without an outcome is
      // one — so the refusal is surfaced rather than swallowed.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That could not be saved.')),
      );
    }
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.row, required this.onTriage});

  final Map<String, dynamic> row;
  final VoidCallback onTriage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = row['from'] as Map<String, dynamic>?;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${row['intent']}', style: theme.textTheme.labelLarge),
              const SizedBox(width: 8),
              Text('${row['state']}', style: theme.textTheme.bodySmall),
              const Spacer(),
              SelectableText('${row['ref']}', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          // Build and platform: what makes a report actionable, and the whole
          // reason the context is collected at all.
          Text(
            [
              row['platform'],
              if ((row['appVersion'] ?? '').toString().isNotEmpty)
                row['appVersion'],
              if (from != null) from['email'],
            ].where((e) => e != null).join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text('${row['excerpt'] ?? ''}'),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onTriage, child: const Text('Triage')),
          ),
        ],
      ),
    );
  }
}
