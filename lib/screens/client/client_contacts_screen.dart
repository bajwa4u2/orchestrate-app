import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/client/client_workspace_repository.dart';

class ClientContactsScreen extends StatelessWidget {
  const ClientContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ContactsViewData>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(
            child: Text('Contacts could not load right now.'),
          );
        }

        final data = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12, bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(total: data.totalContacts, ready: data.readyContacts),
              const SizedBox(height: 18),
              _StatusRow(
                cards: [
                  _StatusCardData(label: 'Contacts', value: '${data.totalContacts}'),
                  _StatusCardData(label: 'Ready', value: '${data.readyContacts}'),
                  _StatusCardData(label: 'With phone', value: '${data.phoneCount}'),
                  _StatusCardData(label: 'Companies', value: '${data.companyCount}'),
                ],
              ),
              const SizedBox(height: 18),
              _Panel(
                title: 'Contacts in system memory',
                emptyLabel: 'Contact records will appear here once sourcing begins.',
                items: data.rows,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_ContactsViewData> _load() async {
    final workspaceRepo = ClientWorkspaceRepository();
    final overview = await workspaceRepo.fetchOverview();
    final contacts = await workspaceRepo.fetchLeads();

    final activity = _asMap(overview['activity']);
    final totalContacts = _countValue(
      activity['leadCount'] ?? activity['leads'] ?? activity['prospects'] ?? contacts.length,
    );
    final readyContacts = _countValue(
      activity['sendableLeadCount'] ?? activity['sendableLeads'] ?? activity['queuedLeads'],
    );

    var phoneCount = 0;
    final companies = <String>{};
    final rows = <_ContactRow>[];

    for (final item in contacts) {
      final map = _asMap(item);
      final company = _firstNonEmpty([
        _read(map, 'companyName'),
        _read(map, 'company'),
      ]);
      final phone = _firstNonEmpty([
        _read(map, 'phone'),
        _read(map, 'phoneNumber'),
      ]);
      if (company.isNotEmpty) companies.add(company);
      if (phone.isNotEmpty) phoneCount += 1;

      rows.add(
        _ContactRow(
          name: _firstNonEmpty([
            _read(map, 'fullName'),
            _read(map, 'name'),
            'Unnamed contact',
          ]),
          company: company,
          title: _read(map, 'title'),
          email: _read(map, 'email'),
          phone: phone,
          location: _read(map, 'location'),
          status: _title(_read(map, 'status')),
          source: _title(_read(map, 'source')),
          createdDate: _formatDate(_read(map, 'createdAt')),
        ),
      );
    }

    return _ContactsViewData(
      totalContacts: totalContacts,
      readyContacts: readyContacts,
      phoneCount: phoneCount,
      companyCount: companies.length,
      rows: rows,
    );
  }
}

class _ContactsViewData {
  const _ContactsViewData({
    required this.totalContacts,
    required this.readyContacts,
    required this.phoneCount,
    required this.companyCount,
    required this.rows,
  });

  final int totalContacts;
  final int readyContacts;
  final int phoneCount;
  final int companyCount;
  final List<_ContactRow> rows;
}

class _ContactRow {
  const _ContactRow({
    required this.name,
    required this.company,
    required this.title,
    required this.email,
    required this.phone,
    required this.location,
    required this.status,
    required this.source,
    required this.createdDate,
  });

  final String name;
  final String company;
  final String title;
  final String email;
  final String phone;
  final String location;
  final String status;
  final String source;
  final String createdDate;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.total, required this.ready});

  final int total;
  final int ready;

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
            'Contacts',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 10),
          Text(
            total == 0 ? 'No contacts are visible yet' : '$total contacts currently visible',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            ready == 0
                ? 'Contacts are kept visible here even before outreach readiness is confirmed.'
                : '$ready contacts currently look ready for outreach from the client-side view.',
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

class _StatusCardData {
  const _StatusCardData({required this.label, required this.value});

  final String label;
  final String value;
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.cards});

  final List<_StatusCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                _StatusTile(card: cards[i]),
                if (i != cards.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: _StatusTile(card: cards[i])),
              if (i != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.card});

  final _StatusCardData card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(card.value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
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
  final List<_ContactRow> items;

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
              _ContactTile(item: items[i]),
              if (i != items.length - 1) const Divider(height: 22),
            ],
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.item});

  final _ContactRow item;

  @override
  Widget build(BuildContext context) {
    final primary = _join([
      item.company,
      item.title,
      item.status,
    ]);
    final secondary = _join([
      item.email,
      item.phone,
      item.location,
      item.source,
      item.createdDate,
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.name, style: Theme.of(context).textTheme.titleLarge),
        if (primary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            primary,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.publicText),
          ),
        ],
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            secondary,
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

int _countValue(dynamic value) {
  if (value is int) return value;
  return int.tryParse('${value ?? 0}') ?? 0;
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

String _join(List<String> values) =>
    values.where((entry) => entry.trim().isNotEmpty).join(' · ');

String _formatDate(String value) {
  if (value.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  return '${_monthName(local.month)} ${local.day}, ${local.year}';
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
