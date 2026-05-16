import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_mailbox_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_outreach_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

class ClientMailboxScreen extends StatefulWidget {
  const ClientMailboxScreen({super.key});

  @override
  State<ClientMailboxScreen> createState() => _ClientMailboxScreenState();
}

class _ClientMailboxScreenState extends State<ClientMailboxScreen> {
  final ClientMailboxRepository _mailboxRepository = ClientMailboxRepository();
  late Future<_MailboxViewData> _future = _load();
  bool _activating = false;
  String? _result;

  Future<void> _activate() async {
    setState(() => _activating = true);
    try {
      final result = await _mailboxRepository.activateMailbox();
      final ready = result['ready'] == true;
      final blockers = _asList(result['blockers']);
      final blocker = blockers.isEmpty ? '' : _read(_asMap(blockers.first), 'message');
      setState(() {
        _result = ready
            ? 'Mailbox is ready.'
            : blocker.isNotEmpty
                ? blocker
                : 'Mailbox activation is still blocked.';
        _future = _load();
      });
    } catch (error) {
      setState(() {
        _result = error is ApiException ? error.displayMessage : error.toString();
        _future = _load();
      });
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MailboxViewData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(
            eyebrow: 'Mailbox',
            label: 'Loading mailbox state',
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Mailbox is temporarily unavailable',
          );
        }
        final data = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12, bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(data: data),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _activating ? null : _activate,
                    icon: _activating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.outgoing_mail, size: 18),
                    label: Text(_activating ? 'Activating' : 'Activate mailbox'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh mailbox status'),
                  ),
                ],
              ),
              if (_result != null) ...[
                const SizedBox(height: 10),
                Text(_result!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 18),
              _Stats(data: data),
              const SizedBox(height: 18),
              _Panel(
                title: 'Recent dispatch movement',
                emptyLabel:
                    'No dispatches yet. Once a campaign is active and the mailbox is connected, outbound activity surfaces here.',
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
    final readiness = await _mailboxRepository.fetchMailbox();
    final mailbox = _asMap(readiness['mailbox']);
    final blockers = _asList(readiness['blockers']).map(_asMap).toList();
    final firstBlocker = blockers.isEmpty ? const <String, dynamic>{} : blockers.first;

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
      ready: readiness['ready'] == true,
      status: _title(_read(readiness, 'status')),
      blocker: _read(firstBlocker, 'message'),
      lastCheckedAt: _read(mailbox, 'lastCheckedAt'),
      mailboxLine: _join([
        _firstNonEmpty([_read(mailbox, 'fromEmail'), _read(mailbox, 'address')]),
        _title(_read(mailbox, 'provider')),
        _read(mailbox, 'replyToEmail').isEmpty ? '' : 'Reply-to ${_read(mailbox, 'replyToEmail')}',
        _read(mailbox, 'connected') == 'true' ? 'Connected' : '',
        _read(mailbox, 'verified') == 'true' ? 'Verified' : '',
      ]),
      dispatchRows: dispatchRows,
    );
  }
}

class _MailboxViewData {
  const _MailboxViewData({
    required this.dispatchCount,
    required this.replyCount,
    required this.noticeCount,
    required this.ready,
    required this.status,
    required this.blocker,
    required this.lastCheckedAt,
    required this.mailboxLine,
    required this.dispatchRows,
  });

  final int dispatchCount;
  final int replyCount;
  final int noticeCount;
  final bool ready;
  final String status;
  final String blocker;
  final String lastCheckedAt;
  final String mailboxLine;
  final List<_MailboxRow> dispatchRows;
}

class _MailboxRow {
  const _MailboxRow(
      {required this.title, required this.primary, required this.secondary});

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
        borderRadius: BorderRadius.circular(AppTheme.radius),
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
            data.ready
                ? 'Outbound email is ready'
                : 'Outbound email is not ready',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            _join([
              data.status,
              data.mailboxLine.isEmpty
                  ? 'No mailbox is available for this client.'
                  : data.mailboxLine,
              data.lastCheckedAt.isEmpty
                  ? ''
                  : 'Last checked ${_formatDateTime(data.lastCheckedAt)}',
            ]),
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.publicMuted),
          ),
          if (data.blocker.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              data.blocker,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.rose),
            ),
          ],
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
        borderRadius: BorderRadius.circular(AppTheme.radius),
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

List<dynamic> _asList(dynamic value) =>
    value is List ? value : const <dynamic>[];

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
