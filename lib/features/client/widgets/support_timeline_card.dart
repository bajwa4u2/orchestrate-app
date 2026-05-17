import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/system/widgets/governance_primitives.dart';

/// Operational support timeline.
///
/// Doctrine
/// --------
/// Renders a chronological union of activity events, DNS verification
/// outcomes, recent dispatch states, and open alerts — sourced from
/// the new /client/support/timeline endpoint which composes existing
/// persisted rows. No fabricated events. Every entry maps 1:1 to a
/// real record in the database, with the original timestamp.
///
/// Uses the existing LifecycleTimeline primitive for visual
/// consistency with the operator governance screen and the
/// client-side governance panel — same visual vocabulary, same tone
/// mapping, same "missing data is honest" posture.
class SupportTimelineCard extends StatefulWidget {
  const SupportTimelineCard({super.key, this.repository});

  final ClientPortalRepository? repository;

  @override
  State<SupportTimelineCard> createState() => _SupportTimelineCardState();
}

class _SupportTimelineCardState extends State<SupportTimelineCard> {
  late final ClientPortalRepository _repository =
      widget.repository ?? ClientPortalRepository();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _data = await _repository.fetchSupportTimeline();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_outlined,
                  size: 16, color: AppTheme.publicMuted),
              const SizedBox(width: 8),
              Text(
                'Operational support timeline',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.publicMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Re-read history',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Chronological union of activity, DNS verification, dispatch outcomes, and operational alerts for this workspace — last 60 days. Every event is a persisted record. Nothing is inferred.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.publicMuted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _errorRow(context)
          else
            _renderEvents(context, _data ?? const {}),
        ],
      ),
    );
  }

  Widget _renderEvents(BuildContext context, Map<String, dynamic> data) {
    final events = (data['events'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    if (events.isEmpty) {
      return Text(
        'No operational events recorded in the last 60 days.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.publicMuted,
            ),
      );
    }
    final steps = events.map((e) => _toLifecycleStep(e)).toList();
    return LifecycleTimeline(steps: steps);
  }

  LifecycleStep _toLifecycleStep(Map<String, dynamic> event) {
    final severity = (event['severity'] ?? 'info').toString();
    final kind = (event['kind'] ?? '').toString();
    final occurredAt = event['occurredAt']?.toString();

    // Map severity to LifecycleStep state. We deliberately overload
    // the existing state names so the timeline visual stays uniform
    // across operator + client surfaces.
    final state = switch (severity) {
      'positive' => 'done',
      'warning' => 'attention',
      'critical' => 'failed',
      'info' => 'pending',
      _ => 'pending',
    };

    final title = (event['title'] ?? '').toString();
    final detail = (event['detail'] ?? '').toString();
    final ownerLabel = event['owner']?.toString();
    final detailParts = <String>[];
    if (kind.isNotEmpty) detailParts.add(kind);
    if (ownerLabel != null && ownerLabel.isNotEmpty) {
      detailParts.add('owner: $ownerLabel');
    }
    if (detail.isNotEmpty) detailParts.add(detail);

    return LifecycleStep(
      label: title.isEmpty ? '(unlabeled event)' : title,
      state: state,
      timestamp: occurredAt,
      detail: detailParts.isEmpty ? null : detailParts.join(' · '),
    );
  }

  Widget _errorRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    );
  }
}
