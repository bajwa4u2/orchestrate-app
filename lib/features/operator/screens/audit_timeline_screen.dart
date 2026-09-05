import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'audit_events.dart';
import '../widgets/operator_panel.dart';

/// Queryable AuditLog timeline. Closes the long-standing operator
/// gap that audit was backend-only.
class AuditTimelineScreen extends StatefulWidget {
  const AuditTimelineScreen({super.key});

  @override
  State<AuditTimelineScreen> createState() => _AuditTimelineScreenState();
}

class _AuditTimelineScreenState extends State<AuditTimelineScreen> {
  final AuditEventsRepository _repo = AuditEventsRepository();
  Future<List<AuditEvent>>? _future;
  String _action = '';
  String _entityType = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _future = _repo.fetch(
          action: _action.isEmpty ? null : _action,
          entityType: _entityType.isEmpty ? null : _entityType,
          limit: 200,
        ));
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
                  // The eyebrow named a nav group that no longer exists, and
                  // the description named a database table. What a person
                  // needs to know is what is in here and what is not.
                  Text('Audit history',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                      'What was done, by whom, to what, and when. Never '
                      'credentials and never the contents of a message.',
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
        OperatorPanel(
          title: 'Filters',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  style: const TextStyle(color: AppTheme.text),
                  decoration: const InputDecoration(
                    labelText: 'Action',
                    labelStyle: TextStyle(color: AppTheme.subdued),
                    hintText: 'e.g. DISPATCH_PROOF_RUN',
                    hintStyle: TextStyle(color: AppTheme.subdued),
                  ),
                  onChanged: (v) => _action = v.trim(),
                  onSubmitted: (_) => _refresh(),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  style: const TextStyle(color: AppTheme.text),
                  decoration: const InputDecoration(
                    labelText: 'Entity type',
                    labelStyle: TextStyle(color: AppTheme.subdued),
                    hintText: 'e.g. OutreachMessage',
                    hintStyle: TextStyle(color: AppTheme.subdued),
                  ),
                  onChanged: (v) => _entityType = v.trim(),
                  onSubmitted: (_) => _refresh(),
                ),
              ),
              ElevatedButton(
                onPressed: _refresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.background,
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<AuditEvent>>(
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
                  title: 'Audit endpoint failed',
                  detail: '${snapshot.error}',
                  onRetry: _refresh);
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const OperatorEmptyState(
                title: 'No audit entries match',
                body:
                    'Try clearing filters or widening your query. Audit is always-on in the backend; absence here is a query result, not an absence of audit.',
              );
            }
            return Column(
              children: [
                for (final e in items)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      color: AppTheme.panelSoft,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: Text(e.action,
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('${e.entityType}/${e.entityId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.muted)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(e.actorDisplayName ?? 'system',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.subdued)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(e.createdAt.toIso8601String(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.subdued)),
                        ),
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
}
