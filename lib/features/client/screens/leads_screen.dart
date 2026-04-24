import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_workspace_repository.dart';

class LeadsScreen extends StatelessWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LeadViewData>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(
            child: Text('Lead records could not load at the moment.'),
          );
        }
        final data = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12, bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(
                  total: data.totalLeads,
                  sendable: data.sendableLeads,
                  blocked: data.blockedLeads),
              const SizedBox(height: 18),
              _StatusRow(
                cards: [
                  _StatusCardData(label: 'Leads', value: '${data.totalLeads}'),
                  _StatusCardData(
                    label: 'Sendable',
                    value: '${data.sendableLeads}',
                  ),
                  _StatusCardData(
                    label: 'With phone',
                    value: '${data.phoneCount}',
                  ),
                  _StatusCardData(
                    label: 'Campaigns',
                    value: '${data.campaignCount}',
                  ),
                  _StatusCardData(
                    label: 'Blocked',
                    value: '${data.blockedLeads}',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (data.blockedLeads > 0) ...[
                _ExplanationPanel(
                  title: 'Why some outreach is paused',
                  summary:
                      _buildClientBlockingSummary(data.blockedReasonCounts),
                ),
                const SizedBox(height: 18),
              ],
              _Panel(
                title: 'Visible leads',
                emptyLabel:
                    'Lead records will appear here once sourcing begins.',
                items: data.rows,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_LeadViewData> _load() async {
    final workspaceRepo = ClientWorkspaceRepository();
    final overview = await workspaceRepo.fetchOverview();
    final leads = await workspaceRepo.fetchLeads();

    final activity = _asMap(overview['activity']);
    final totalLeads = _countValue(
      activity['leadCount'] ?? activity['leads'] ?? activity['prospects'],
    );
    final sendableLeads = _countValue(
      activity['sendableLeadCount'] ??
          activity['sendableLeads'] ??
          activity['queuedLeads'],
    );

    final rows = <_LeadRow>[];
    final campaignNames = <String>{};
    final blockedReasonCounts = <String, int>{};
    var phoneCount = 0;
    var blockedLeads = 0;

    for (final item in leads) {
      final map = _asMap(item);
      final campaign = _read(map, 'campaign');
      final phone = _read(map, 'phone');
      if (campaign.isNotEmpty) {
        campaignNames.add(campaign);
      }
      if (phone.isNotEmpty) {
        phoneCount += 1;
      }

      final blockReasons = _extractBlockReasons(map);
      if (blockReasons.isNotEmpty) {
        blockedLeads += 1;
        for (final reason in blockReasons) {
          blockedReasonCounts.update(reason, (value) => value + 1,
              ifAbsent: () => 1);
        }
      }

      rows.add(
        _LeadRow(
          name: _firstNonEmpty([_read(map, 'name'), 'Unnamed lead']),
          company: _read(map, 'company'),
          title: _read(map, 'title'),
          email: _read(map, 'email'),
          phone: phone,
          location: _read(map, 'location'),
          campaign: campaign,
          status: _title(_read(map, 'status')),
          source: _title(_read(map, 'source')),
          createdDate: _formatDate(_read(map, 'createdAt')),
          blockReasons: blockReasons,
        ),
      );
    }

    return _LeadViewData(
      totalLeads: totalLeads,
      sendableLeads: sendableLeads,
      blockedLeads: blockedLeads,
      blockedReasonCounts: blockedReasonCounts,
      phoneCount: phoneCount,
      campaignCount: campaignNames.length,
      rows: rows,
    );
  }
}

class _LeadViewData {
  const _LeadViewData({
    required this.totalLeads,
    required this.sendableLeads,
    required this.blockedLeads,
    required this.blockedReasonCounts,
    required this.phoneCount,
    required this.campaignCount,
    required this.rows,
  });

  final int totalLeads;
  final int sendableLeads;
  final int blockedLeads;
  final Map<String, int> blockedReasonCounts;
  final int phoneCount;
  final int campaignCount;
  final List<_LeadRow> rows;
}

class _LeadRow {
  const _LeadRow({
    required this.name,
    required this.company,
    required this.title,
    required this.email,
    required this.phone,
    required this.location,
    required this.campaign,
    required this.status,
    required this.source,
    required this.createdDate,
    required this.blockReasons,
  });

  final String name;
  final String company;
  final String title;
  final String email;
  final String phone;
  final String location;
  final String campaign;
  final String status;
  final String source;
  final String createdDate;
  final List<String> blockReasons;
}

class _Hero extends StatelessWidget {
  const _Hero(
      {required this.total, required this.sendable, required this.blocked});

  final int total;
  final int sendable;
  final int blocked;

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
            'Lead generation',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 10),
          Text(
            total == 0
                ? 'No leads are visible yet'
                : '$total leads currently visible',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            sendable == 0
                ? (blocked > 0
                    ? 'Some records are being held back while the system validates timing, relevance, and contact readiness.'
                    : 'This screen separates sourced records from sendable records so the client can see what is actually ready for outreach.')
                : '$sendable leads appear ready for outreach from the current client-side view.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted),
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
        borderRadius: BorderRadius.circular(AppTheme.radius),
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
  final List<_LeadRow> items;

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
              _LeadTile(item: items[i]),
              if (i != items.length - 1) const Divider(height: 22),
            ],
        ],
      ),
    );
  }
}

class _LeadTile extends StatelessWidget {
  const _LeadTile({required this.item});

  final _LeadRow item;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      _join([item.company, item.title]),
      _join([item.email, item.phone]),
      _join([item.location, item.campaign]),
      _join([item.status, item.source, item.createdDate]),
      if (item.blockReasons.isNotEmpty)
        item.blockReasons.map(_translateBlockReason).join(' · '),
    ].where((line) => line.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.name, style: Theme.of(context).textTheme.titleLarge),
        for (int i = 0; i < lines.length; i++) ...[
          const SizedBox(height: 6),
          Text(
            lines[i],
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: item.blockReasons.isNotEmpty && i == lines.length - 1
                      ? Colors.orange.shade700
                      : (i == lines.length - 1
                          ? AppTheme.publicMuted
                          : AppTheme.publicText),
                ),
          ),
        ],
      ],
    );
  }
}

class _ExplanationPanel extends StatelessWidget {
  const _ExplanationPanel({required this.title, required this.summary});

  final String title;
  final List<String> summary;

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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          for (final line in summary) ...[
            Text(
              line,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

List<String> _buildClientBlockingSummary(Map<String, int> counts) {
  if (counts.isEmpty) {
    return const <String>[];
  }
  final ordered = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return ordered
      .take(3)
      .map((entry) =>
          '${entry.value} lead${entry.value == 1 ? '' : 's'} ${_translateBlockReason(entry.key).toLowerCase()}')
      .toList();
}

List<String> _extractBlockReasons(Map<String, dynamic> lead) {
  final metadata = _asMap(lead['metadataJson']);
  final rootReasons = _asStringList(metadata['blockReasons']);
  if (rootReasons.isNotEmpty) return rootReasons;
  final messageGeneration = _asMap(metadata['messageGeneration']);
  return _asStringList(messageGeneration['reasons']);
}

List<String> _asStringList(dynamic value) {
  return (value as List? ?? const [])
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _translateBlockReason(String code) {
  switch (code) {
    case 'NO_SIGNAL':
      return 'Waiting for stronger timing signals';
    case 'NO_OPPORTUNITY':
      return 'No clear opportunity has formed yet';
    case 'NO_QUALIFICATION':
      return 'Still validating relevance before outreach';
    case 'NO_EMAIL':
      return 'Missing a contact path for outreach';
    case 'NO_REAL_CONTEXT':
      return 'Do not yet have enough business context to reach out';
    case 'GENERATION_FAILED':
      return 'Message could not be prepared cleanly yet';
    default:
      return 'Still evaluating whether outreach should proceed';
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return const {};
}

String _read(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return '';
  return value.toString().trim();
}

int _countValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _join(List<String> values) =>
    values.where((value) => value.trim().isNotEmpty).join(' · ');

String _title(String value) {
  if (value.trim().isEmpty) return '';
  return value
      .split(RegExp(r'[_\s-]+'))
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _formatDate(String value) {
  if (value.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final month = _monthName(local.month);
  return '$month ${local.day}, ${local.year}';
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}
