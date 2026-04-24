import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_outreach_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_workspace_repository.dart';

class ClientActivityScreen extends StatelessWidget {
  const ClientActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ActivityViewData>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(
              child: Text('Activity could not load at the moment.'));
        }
        final data = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12, bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(data: data),
              const SizedBox(height: 18),
              _MetricRow(data: data),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 980;
                  final left = _Panel(
                    title: 'Reply movement',
                    emptyLabel:
                        'Replies will appear here once conversations begin to move.',
                    items: data.replyRows,
                  );
                  final right = _Panel(
                    title: 'Meeting and mailbox readiness',
                    emptyLabel:
                        'Meeting handoff and mailbox readiness will appear here as execution begins to move.',
                    items: data.meetingRows,
                  );

                  if (stacked) {
                    return Column(
                      children: [left, const SizedBox(height: 18), right],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: left),
                      const SizedBox(width: 18),
                      Expanded(flex: 5, child: right),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_ActivityViewData> _load() async {
    final outreachRepo = ClientOutreachRepository();
    final workspaceRepo = ClientWorkspaceRepository();

    final overview = await workspaceRepo.fetchOverview();
    final replies = await outreachRepo.fetchReplies();
    final dispatches = await outreachRepo.fetchEmailDispatches();

    final activity = _asMap(overview['activity']);
    final replyRows = replies.take(10).map(_activityRowFromReply).toList();
    final meetingRows = _meetingRowsFromOverview(overview).take(10).toList();

    return _ActivityViewData(
      replyCount: _countValue(activity['replies']) == 0
          ? replies.length
          : _countValue(activity['replies']),
      meetingCount:
          _countValue(activity['meetings'] ?? activity['meetingCount']),
      dispatchCount: dispatches.length,
      sendableCount: _countValue(
        activity['sendableLeadCount'] ?? activity['sendableLeads'],
      ),
      replyRows: replyRows,
      meetingRows: meetingRows,
    );
  }
}

class _ActivityViewData {
  const _ActivityViewData({
    required this.replyCount,
    required this.meetingCount,
    required this.dispatchCount,
    required this.sendableCount,
    required this.replyRows,
    required this.meetingRows,
  });

  final int replyCount;
  final int meetingCount;
  final int dispatchCount;
  final int sendableCount;
  final List<_ActivityRow> replyRows;
  final List<_ActivityRow> meetingRows;
}

class _ActivityRow {
  const _ActivityRow({
    required this.title,
    required this.primary,
    required this.secondary,
  });

  final String title;
  final String primary;
  final String secondary;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.data});

  final _ActivityViewData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Execution truth across replies, dispatches, and meeting handoff',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Activity stays separate from targeting so you can see what has actually moved.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.data});

  final _ActivityViewData data;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Replies', '${data.replyCount}'),
      ('Meetings', '${data.meetingCount}'),
      ('Dispatches', '${data.dispatchCount}'),
      ('Sendable', '${data.sendableCount}'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = metrics
            .map(
              (entry) => Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppTheme.publicLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.$1,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    Text(
                      entry.$2,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            )
            .toList();

        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.emptyLabel,
    required this.items,
  });

  final String title;
  final String emptyLabel;
  final List<_ActivityRow> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(emptyLabel, style: Theme.of(context).textTheme.bodyMedium)
          else
            for (int i = 0; i < items.length; i++) ...[
              _Item(item: items[i]),
              if (i != items.length - 1) const Divider(height: 22),
            ],
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item});

  final _ActivityRow item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.title, style: Theme.of(context).textTheme.titleLarge),
        if (item.primary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(item.primary, style: Theme.of(context).textTheme.bodyLarge),
        ],
        if (item.secondary.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.secondary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ],
    );
  }
}

_ActivityRow _activityRowFromReply(dynamic raw) {
  final map = _asMap(raw);
  return _ActivityRow(
    title: _firstNonEmpty([
      _read(map, 'subject'),
      _read(map, 'fromEmail'),
      'Reply',
    ]),
    primary: _join([
      _title(_read(map, 'status')),
      _read(map, 'fromEmail'),
    ]),
    secondary: _join([
      _formatDateTime(_read(map, 'receivedAt')),
      _read(map, 'threadKey'),
    ]),
  );
}

List<_ActivityRow> _meetingRowsFromOverview(Map<String, dynamic> overview) {
  final activity = _asMap(overview['activity']);
  final execution = _asMap(overview['execution']);
  final mailbox = _asMap(overview['mailbox']);
  final primaryMailbox = _asMap(mailbox['primary']);

  final rows = <_ActivityRow>[
    _ActivityRow(
      title: 'Meeting handoff',
      primary:
          '${_countValue(activity['meetings'] ?? activity['meetingCount'])} meetings on record',
      secondary: _join([
        _read(execution, 'surfaceLabel'),
        _read(execution, 'summary'),
      ]),
    ),
  ];

  if (mailbox.isNotEmpty) {
    rows.add(
      _ActivityRow(
        title: 'Mailbox readiness',
        primary: mailbox['ready'] == true
            ? 'Mailbox ready for live execution'
            : 'Mailbox still needs attention',
        secondary: _join([
          _read(primaryMailbox, 'emailAddress'),
          _title(_read(primaryMailbox, 'connectionState')),
          _title(_read(primaryMailbox, 'healthStatus')),
        ]),
      ),
    );
  }

  return rows;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return const <String, dynamic>{};
}

String _read(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return '';
  return value.toString().trim();
}

int _countValue(dynamic value) {
  if (value is int) return value;
  return int.tryParse('${value ?? 0}') ?? 0;
}

String _title(String value) {
  if (value.trim().isEmpty) return '';
  return value
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) =>
          '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _join(List<String> values) =>
    values.where((entry) => entry.trim().isNotEmpty).join(' · ');

String _formatDateTime(String value) {
  if (value.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  final hour =
      local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${_monthName(local.month)} ${local.day}, ${local.year} · $hour:$minute $suffix';
}

String _monthName(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[(month - 1).clamp(0, 11)];
}
