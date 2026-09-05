import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'ops_platform_repository.dart';
import 'ops_platform_surface.dart';

/// THE BUSINESSES ORCHESTRATE OPERATES FOR.
///
/// This screen read the organisation of the session and rendered "No clients
/// found" for a platform operator, whose organisation holds none — while nine
/// client businesses operated normally on the other side of the boundary. It
/// now reads the platform's client directory: identity, operational state, and
/// what is actually blocking each one.
///
/// Blockers rather than a checklist. A satisfied step rendered as a tick is a
/// progress bar in disguise, and it buries the one line that matters.
class OpsClientsScreen extends StatelessWidget {
  const OpsClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformSurface<Map<String, dynamic>>(
      title: 'Clients',
      describes: 'Every business on the platform, and what is in its way.',
      load: OpsPlatformRepository().clients,
      rows: (data) => ((data['clients'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(),
      summarise: (rows) {
        final blocked =
            rows.where((r) => ((r['blockers'] as List?) ?? []).isNotEmpty).length;
        if (rows.isEmpty) return 'No businesses.';
        return '${rows.length} business${rows.length == 1 ? '' : 'es'}'
            '${blocked == 0 ? ', none blocked.' : ', $blocked with something in the way.'}';
      },
      emptyHeadline: 'No businesses on the platform yet.',
      build: (context, row) => _ClientRow(client: row),
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({required this.client});

  final Map<String, dynamic> client;

  @override
  Widget build(BuildContext context) {
    final blockers =
        ((client['blockers'] as List?) ?? const []).whereType<String>().toList();
    final mailboxes = _pair(client['mailboxes']);
    final domains = _pair(client['domains']);
    final campaigns = _pair(client['campaigns']);
    final authority = client['authority'] is Map
        ? Map<String, dynamic>.from(client['authority'] as Map)
        : const <String, dynamic>{};
    final held = (client['heldMessages'] as num?)?.toInt() ?? 0;
    final awaiting = (authority['awaitingDecision'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: blockers.isEmpty ? AppTheme.line : AppTheme.amber.withOpacity(0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text('${client['name'] ?? '—'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        if (client['isPlatformOrganization'] == true) ...[
                          const SizedBox(width: 8),
                          const _Tag(text: 'us'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        '${client['organizationSlug'] ?? ''}',
                        '${client['status'] ?? ''}'.toLowerCase(),
                        if (client['setupComplete'] != true) 'still in setup',
                      ].where((s) => s.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.subdued),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 16,
                children: [
                  _Fact(label: 'mailboxes', value: '${mailboxes.$1}/${mailboxes.$2}'),
                  _Fact(label: 'domains', value: '${domains.$1}/${domains.$2}'),
                  _Fact(label: 'campaigns', value: '${campaigns.$1}/${campaigns.$2}'),
                  _Fact(
                    label: 'recognised',
                    value: '${(authority['recognisedPeople'] as num?)?.toInt() ?? 0}',
                  ),
                ],
              ),
            ],
          ),
          if (blockers.isNotEmpty || awaiting > 0 || held > 0) ...[
            const SizedBox(height: 10),
            for (final blocker in blockers) _Owed(text: blocker),
            if (awaiting > 0)
              _Owed(
                text: '$awaiting authority submission${awaiting == 1 ? '' : 's'} '
                    'waiting for a decision.',
              ),
            if (held > 0)
              _Owed(
                text: '$held held message${held == 1 ? '' : 's'} waiting to be placed.',
              ),
          ],
        ],
      ),
    );
  }

  static (int, int) _pair(dynamic raw) {
    if (raw is! Map) return (0, 0);
    final map = Map<String, dynamic>.from(raw);
    final total = (map['total'] as num?)?.toInt() ?? 0;
    final good = (map['connected'] ?? map['active'] ?? 0) as num;
    return (good.toInt(), total);
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.subdued)),
        ],
      );
}

class _Owed extends StatelessWidget {
  const _Owed({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.flag_outlined, size: 13, color: AppTheme.amber),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.muted, height: 1.45)),
            ),
          ],
        ),
      );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 10, color: AppTheme.accent)),
      );
}
