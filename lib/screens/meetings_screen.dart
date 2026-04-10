import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/repositories/client_portal_repository.dart';

class MeetingsScreen extends StatelessWidget {
  const MeetingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: ClientPortalRepository().fetchMeetings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text('Meetings could not load right now.'),
          );
        }

        final meetings = snapshot.data ?? const <dynamic>[];
        final upcoming = meetings.where((item) => _bucket(item) == 'Upcoming').length;
        final completed = meetings.where((item) => _bucket(item) == 'Completed').length;
        final missed = meetings.where((item) => _bucket(item) == 'Missed').length;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MeetingsHero(total: meetings.length),
                const SizedBox(height: 18),
                _StatusRow(
                  cards: [
                    _StatusCardData(label: 'Upcoming', value: '$upcoming'),
                    _StatusCardData(label: 'Completed', value: '$completed'),
                    _StatusCardData(label: 'Missed', value: '$missed'),
                  ],
                ),
                const SizedBox(height: 18),
                _MeetingPanel(
                  title: 'Meeting record',
                  emptyLabel: 'Meetings booked through outreach will appear here.',
                  items: meetings.map((item) => _MeetingRow.fromRaw(item)).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MeetingsHero extends StatelessWidget {
  const _MeetingsHero({required this.total});

  final int total;

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
            'Outcomes',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            total == 0 ? 'No meetings are on record yet' : '$total meetings on record',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'This page keeps the outcome side of outreach visible, with scheduled, completed, and missed meetings in one place.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ),
    );
  }
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

class _MeetingPanel extends StatelessWidget {
  const _MeetingPanel({
    required this.title,
    required this.emptyLabel,
    required this.items,
  });

  final String title;
  final String emptyLabel;
  final List<_MeetingRow> items;

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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(emptyLabel, style: Theme.of(context).textTheme.bodyMedium)
          else
            for (int i = 0; i < items.length; i++) ...[
              _MeetingTile(item: items[i]),
              if (i != items.length - 1) const Divider(height: 22),
            ],
        ],
      ),
    );
  }
}

class _MeetingTile extends StatelessWidget {
  const _MeetingTile({required this.item});

  final _MeetingRow item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.title, style: Theme.of(context).textTheme.titleLarge),
        if (item.primary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            item.primary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicText,
                ),
          ),
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

class _StatusCardData {
  const _StatusCardData({required this.label, required this.value});

  final String label;
  final String value;
}

class _MeetingRow {
  const _MeetingRow({
    required this.title,
    required this.primary,
    required this.secondary,
  });

  factory _MeetingRow.fromRaw(dynamic raw) {
    final map = _asMap(raw);
    final lead = _asMap(map['lead']);
    final campaign = _asMap(map['campaign']);
    final client = _asMap(map['client']);

    final title = _firstNonEmpty([
      _read(map, 'title'),
      _read(lead, 'companyName'),
      _read(lead, 'fullName'),
      _read(client, 'displayName'),
      'Meeting',
    ]);

    final primaryParts = <String>[
      _bucket(map),
      _scheduledLabel(_read(map, 'scheduledAt')),
    ].where((value) => value.isNotEmpty).toList();

    final secondaryParts = <String>[
      _firstNonEmpty([
        _read(lead, 'companyName'),
        _read(lead, 'fullName'),
        _read(client, 'displayName'),
      ]),
      _read(campaign, 'name'),
      _read(map, 'bookingUrl'),
    ].where((value) => value.isNotEmpty).toList();

    return _MeetingRow(
      title: title,
      primary: primaryParts.join(' · '),
      secondary: secondaryParts.join(' · '),
    );
  }

  final String title;
  final String primary;
  final String secondary;
}

String _bucket(dynamic raw) {
  final status = _read(_asMap(raw), 'status').toLowerCase();
  if (status.contains('complete') || status.contains('done')) return 'Completed';
  if (status.contains('missed') || status.contains('cancel')) return 'Missed';
  return 'Upcoming';
}

String _scheduledLabel(String value) {
  if (value.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final month = _monthName(local.month);
  final minute = local.minute.toString().padLeft(2, '0');
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
          ? local.hour - 12
          : local.hour;
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$month ${local.day}, ${local.year} · $hour:$minute $suffix';
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const <String, dynamic>{};
}

String _read(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return '';
  return value.toString().trim();
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _monthName(int month) {
  const names = <String>[
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
