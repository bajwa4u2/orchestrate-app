import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_outreach_repository.dart';

class ClientMailboxScreen extends StatelessWidget {
  const ClientMailboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MailboxViewData>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(child: Text('Mailbox could not load right now.'));
        }
        final data = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12, bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(data: data),
              const SizedBox(height: 18),
              _Stats(data: data),
              const SizedBox(height: 18),
              _Panel(
                title: 'Recent dispatch movement',
                emptyLabel: 'Dispatch activity will appear here once sending begins.',
                items: data.dispatchRows,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_MailboxViewData> _load() async {
    final repo = ClientOutreachRepository();
    final dispatches = await repo.fetchEmailDispatches();
    final replies = await repo.fetchReplies();
    final notices = await repo.fetchNotifications();

    final dispatchRows = dispatches.take(12).map((raw) {
      final map = _asMap(raw);
      return _MailboxRow(
        title: _firstNonEmpty([
          _read(map, 'subject'),
          _read(map, 'recipientEmail'),
          'Dispatch',
        ]),
        primary: _join([
          _title(_read(map, 'status')),
          _read(map, 'recipientEmail'),
        ]),
        secondary: _join([
          _formatDateTime(_read(map, 'sentAt')),
          _formatDateTime(_read(map, 'createdAt')),
        ]),
      );
    }).toList();

    return _MailboxViewData(
      dispatchCount: dispatches.length,
      replyCount: replies.length,
      noticeCount: notices.length,
      dispatchRows: dispatchRows,
    );
  }
}

class _MailboxViewData {
  const _MailboxViewData({
    required this.dispatchCount,
    required this.replyCount,
    required this.noticeCount,
    required this.dispatchRows,
  });

  final int dispatchCount;
  final int replyCount;
  final int noticeCount;
  final List<_MailboxRow> dispatchRows;
}

class _MailboxRow {
  const _MailboxRow({required this.title, required this.primary, required this.secondary});

  final String title;
  final String primary;
  final String secondary;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.data});

  final _MailboxViewData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mailbox',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 10),
          Text(
            'Outbound and reply movement connected to the client workspace',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'Mailbox visibility is live. Mailbox connection controls can be expanded later without inventing fake state today.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.publicMuted),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.data});

  final _MailboxViewData data;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Dispatches', '${data.dispatchCount}'),
      ('Replies', '${data.replyCount}'),
      ('Notices', '${data.noticeCount}'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = metrics
            .map(
              (entry) => Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.publicLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.$1, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    Text(
                      entry.$2,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            )
            .toList();

        if (constraints.maxWidth < 840) {
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
  final List<_MailboxRow> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
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

  final _MailboxRow item;

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
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.publicMuted),
          ),
        ],
      ],
    );
  }
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

String _title(String value) {
  if (value.trim().isEmpty) return '';
  return value
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _join(List<String> values) => values.where((entry) => entry.trim().isNotEmpty).join(' · ');

String _formatDateTime(String value) {
  if (value.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
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
