import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/surface_endpoint_repository.dart';

class BackendSurfaceScreen extends StatelessWidget {
  const BackendSurfaceScreen({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.surface,
    required this.sections,
    this.dark = false,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final ApiSurface surface;
  final List<BackendSurfaceSection> sections;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_ResolvedSection>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LoadingBlock(dark: dark, large: true),
                const SizedBox(height: 18),
                _LoadingBlock(dark: dark),
                const SizedBox(height: 18),
                _LoadingBlock(dark: dark),
              ],
            ),
          );
        }

        final resolved = snapshot.data ?? const <_ResolvedSection>[];
        final unavailable = resolved
            .expand((section) => section.snapshots)
            .where((snapshot) => !snapshot.available)
            .length;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle,
                dark: dark,
                sourceCount: resolved.fold<int>(
                  0,
                  (total, section) => total + section.snapshots.length,
                ),
                pendingCount: unavailable,
              ),
              const SizedBox(height: 18),
              for (final section in resolved) ...[
                _SurfacePanel(section: section, dark: dark),
                const SizedBox(height: 18),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<List<_ResolvedSection>> _load() async {
    final repo = SurfaceEndpointRepository();
    final resolved = <_ResolvedSection>[];
    for (final section in sections) {
      final snapshots = <EndpointSnapshot>[];
      for (final endpoint in section.endpoints) {
        snapshots.add(
          await repo.get(endpoint.path,
              query: endpoint.query, surface: surface),
        );
      }
      resolved.add(_ResolvedSection(section: section, snapshots: snapshots));
    }
    return resolved;
  }
}

class BackendSurfaceSection {
  const BackendSurfaceSection({
    required this.title,
    required this.description,
    required this.endpoints,
    this.emptyLabel = 'No data is available yet.',
    this.gapLabel,
  });

  final String title;
  final String description;
  final List<BackendEndpoint> endpoints;
  final String emptyLabel;
  final String? gapLabel;
}

class BackendEndpoint {
  const BackendEndpoint(this.path, {this.query, this.label});

  final String path;
  final Map<String, String>? query;
  final String? label;
}

class _ResolvedSection {
  const _ResolvedSection({required this.section, required this.snapshots});

  final BackendSurfaceSection section;
  final List<EndpointSnapshot> snapshots;
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.dark,
    required this.sourceCount,
    required this.pendingCount,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final bool dark;
  final int sourceCount;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _box(dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: dark ? AppTheme.subdued : AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(
                label: '$sourceCount live data sources checked',
                dark: dark,
              ),
              _Pill(
                label: pendingCount == 0
                    ? 'All configured sources responded'
                    : '$pendingCount capability checks need setup',
                dark: dark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.section, required this.dark});

  final _ResolvedSection section;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final snapshots = section.snapshots;
    final available =
        snapshots.where((snapshot) => snapshot.available).toList();
    final rows = available.expand(_rowsForSnapshot).take(18).toList();
    final gaps = snapshots.where((snapshot) => !snapshot.available).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _box(dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.section.title,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(section.section.description,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final snapshot in snapshots)
                _Pill(
                  label:
                      '${_endpointLabel(section.section, snapshot.path)}: ${snapshot.available ? 'available' : 'not enabled'}',
                  dark: dark,
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            Text(section.section.emptyLabel,
                style: Theme.of(context).textTheme.bodyMedium)
          else
            for (int i = 0; i < rows.length; i++) ...[
              _DataRowView(row: rows[i], dark: dark),
              if (i != rows.length - 1)
                Divider(
                    height: 22,
                    color: dark ? AppTheme.line : AppTheme.publicLine),
            ],
          if (gaps.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              section.section.gapLabel ?? 'Capability not available',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            for (final gap in gaps)
              Text(
                '${_endpointLabel(section.section, gap.path)}: ${_cleanReason(gap.reason, gap.statusCode)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ],
      ),
    );
  }

  String _endpointLabel(BackendSurfaceSection section, String path) {
    for (final endpoint in section.endpoints) {
      if (endpoint.path == path && endpoint.label != null) {
        return endpoint.label!;
      }
    }
    return _friendlySource(path);
  }

  Iterable<_DataRow> _rowsForSnapshot(EndpointSnapshot snapshot) sync* {
    final items = snapshot.items;
    if (items.isNotEmpty) {
      for (final item in items) {
        yield _DataRow.from(snapshot.path, item);
      }
      return;
    }

    final map = snapshot.map;
    if (map.isNotEmpty) {
      final scalarEntries = map.entries.where((entry) {
        final value = entry.value;
        return value == null ||
            value is String ||
            value is num ||
            value is bool;
      }).toList();
      if (scalarEntries.isNotEmpty) {
        yield _DataRow(
          title: _friendlySource(snapshot.path),
          primary: scalarEntries
              .take(4)
              .map((entry) =>
                  '${_label(entry.key)}: ${_formatValue('${entry.value}')}')
              .join(' · '),
          secondary: '',
          source: _friendlySource(snapshot.path),
        );
      }

      for (final entry in map.entries) {
        if (entry.value is List) {
          for (final item in (entry.value as List).take(8)) {
            yield _DataRow.from(
              '${_friendlySource(snapshot.path)} ${_label(entry.key)}',
              item,
            );
          }
        }
      }
    }
  }
}

class _DataRowView extends StatelessWidget {
  const _DataRowView({required this.row, required this.dark});

  final _DataRow row;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(row.title, style: Theme.of(context).textTheme.titleLarge),
        if (row.primary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(row.primary, style: Theme.of(context).textTheme.bodyLarge),
        ],
        if (row.secondary.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            row.secondary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: dark ? AppTheme.muted : AppTheme.publicMuted,
                ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          row.source,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: dark ? AppTheme.subdued : AppTheme.publicMuted,
              ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.dark});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? AppTheme.panelRaised : AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: dark ? AppTheme.line : AppTheme.publicLine),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.dark, this.large = false});

  final bool dark;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final base = dark ? AppTheme.panel : Colors.white;
    final line = dark ? AppTheme.line : AppTheme.publicLine;
    final fill = dark ? AppTheme.panelRaised : AppTheme.publicSurfaceSoft;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonLine(width: large ? 260 : 180, fill: fill),
          const SizedBox(height: 14),
          _SkeletonLine(
            width: double.infinity,
            height: large ? 30 : 22,
            fill: fill,
          ),
          const SizedBox(height: 10),
          _SkeletonLine(width: large ? 520 : 380, fill: fill),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.width,
    required this.fill,
    this.height = 14,
  });

  final double width;
  final double height;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = width == double.infinity
            ? constraints.maxWidth
            : width.clamp(0, constraints.maxWidth).toDouble();
        return Container(
          width: resolvedWidth,
          height: height,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      },
    );
  }
}

class _DataRow {
  const _DataRow({
    required this.title,
    required this.primary,
    required this.secondary,
    required this.source,
  });

  factory _DataRow.from(String source, dynamic raw) {
    final map = _asMap(raw);
    if (map.isEmpty) {
      return _DataRow(
        title: '$raw',
        primary: '',
        secondary: '',
        source: _friendlySource(source),
      );
    }

    return _DataRow(
      title: _firstNonEmpty([
        _read(map, 'displayName'),
        _read(map, 'legalName'),
        _read(map, 'name'),
        _read(map, 'title'),
        _read(map, 'subject'),
        _read(map, 'invoiceNumber'),
        _read(map, 'statementNumber'),
        _read(map, 'email'),
        _read(map, 'id'),
        source,
      ]),
      primary: _join([
        _labelValue(map, 'status'),
        _labelValue(map, 'type'),
        _labelValue(map, 'state'),
        _labelValue(map, 'healthStatus'),
        _labelValue(map, 'subscriptionStatus'),
        _labelValue(map, 'amountFormatted'),
      ]),
      secondary: _join([
        _labelValue(map, 'company'),
        _labelValue(map, 'companyName'),
        _labelValue(map, 'recipientEmail'),
        _labelValue(map, 'fromEmail'),
        _labelValue(map, 'createdAt'),
        _labelValue(map, 'updatedAt'),
        _labelValue(map, 'scheduledAt'),
        _labelValue(map, 'sentAt'),
      ]),
      source: _friendlySource(source),
    );
  }

  final String title;
  final String primary;
  final String secondary;
  final String source;
}

BoxDecoration _box(bool dark) {
  return BoxDecoration(
    color: dark ? AppTheme.panel : Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: dark ? AppTheme.line : AppTheme.publicLine),
  );
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return const <String, dynamic>{};
}

String _read(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return '';
  return value.toString().trim();
}

String _label(String key) {
  return key
      .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'), (match) => '${match[1]} ${match[2]}')
      .replaceAll('_', ' ')
      .toLowerCase();
}

String _labelValue(Map<String, dynamic> map, String key) {
  final value = _read(map, key);
  if (value.isEmpty) return '';
  return '${_label(key)}: ${_formatValue(value)}';
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _join(List<String> values) {
  return values.where((value) => value.trim().isNotEmpty).join(' · ');
}

String _friendlySource(String value) {
  final text = value
      .replaceAll(RegExp(r'^/'), '')
      .replaceAll('/', ' ')
      .replaceAll('-', ' ')
      .replaceAll(':', '')
      .trim();
  if (text.isEmpty) return 'System source';
  return text
      .split(RegExp(r'\s+'))
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _cleanReason(String? reason, int? statusCode) {
  if (statusCode == 401 || statusCode == 403) {
    return 'Not available for this account';
  }
  if (statusCode == 404) {
    return 'Capability not enabled';
  }
  if (statusCode != null && statusCode >= 500) {
    return 'Operating status could not be loaded';
  }
  final text = (reason ?? '').trim();
  if (text.isEmpty) return 'Not yet configured';
  if (text.contains('Cannot GET') || text.contains('404')) {
    return 'Capability not available';
  }
  if (text.contains('Unauthorized') || text.contains('401')) {
    return 'Not enabled for this account';
  }
  return text
      .replaceAll('endpoint', 'capability')
      .replaceAll('Endpoint', 'Capability')
      .replaceAll('API', 'system')
      .replaceAll('payload', 'record');
}

String _formatValue(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
