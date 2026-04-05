import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/async_surface.dart';
import '../core/widgets/section_header.dart';
import '../core/widgets/surface.dart';
import '../data/models/control_overview.dart';
import '../data/repositories/control_repository.dart';

class CommandScreen extends StatelessWidget {
  const CommandScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = ControlRepository();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Command',
              subtitle: 'Live system posture, today\'s movement, and where attention is needed now.',
            ),
            const SizedBox(height: 20),
            AsyncSurface<ControlOverview>(
              future: repository.fetchOverview(),
              builder: (context, overview) => _CommandBody(overview: overview),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandBody extends StatelessWidget {
  const _CommandBody({required this.overview});

  final ControlOverview? overview;

  @override
  Widget build(BuildContext context) {
    final data = overview;
    final pressureItems = _pressureItems(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusCard(overview: data),
        const SizedBox(height: 16),
        _TodayBand(overview: data),
        const SizedBox(height: 24),
        _FlowSection(overview: data),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final singleColumn = constraints.maxWidth < 980;

            if (singleColumn) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PressurePanel(items: pressureItems),
                  const SizedBox(height: 16),
                  _FootingPanel(overview: data),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _PressurePanel(items: pressureItems),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: _FootingPanel(overview: data),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

Color _statusTone(ControlOverview? overview) {
  if ((overview?.execution.failedJobs ?? 0) > 0 || (overview?.alerts.open ?? 0) > 0) {
    return AppTheme.rose;
  }
  if ((overview?.deliverability.degradedMailboxes ?? 0) > 0 || _replyPressure(overview)) {
    return AppTheme.amber;
  }
  return AppTheme.emerald;
}

bool _replyPressure(ControlOverview? overview) {
  return (overview?.today.replies ?? 0) > (overview?.today.sent ?? 0) &&
      (overview?.today.replies ?? 0) > 0;
}

String _statusLabel(ControlOverview? overview) {
  if (overview == null) return 'Waiting';
  if (overview.execution.failedJobs > 0) return 'Recovery';
  if (overview.alerts.open > 0) return 'Attention';
  if (overview.deliverability.degradedMailboxes > 0) return 'Review';
  if (_replyPressure(overview)) return 'Replies';
  return 'Live';
}

String _statusLine(ControlOverview? overview) {
  if (overview == null) return 'No live signal';
  if (overview.execution.failedJobs > 0) {
    return '${overview.execution.failedJobs} failed ${overview.execution.failedJobs == 1 ? 'job' : 'jobs'}';
  }
  if (overview.deliverability.degradedMailboxes > 0) {
    return '${overview.deliverability.degradedMailboxes} degraded ${overview.deliverability.degradedMailboxes == 1 ? 'mailbox' : 'mailboxes'}';
  }
  if (overview.alerts.open > 0) {
    return '${overview.alerts.open} open ${overview.alerts.open == 1 ? 'alert' : 'alerts'}';
  }
  if (_replyPressure(overview)) {
    return 'Reply pressure';
  }
  if ((overview.today.booked) > 0) return 'Bookings active';
  if ((overview.today.sent) > 0 && (overview.today.replies) == 0) return 'Sending active';
  if ((overview.today.replies) > 0) return 'Replies active';
  return 'System live';
}

String _statusSupport(ControlOverview? overview) {
  if (overview == null) return 'Waiting for live control data.';
  if (overview.execution.failedJobs > 0) {
    return 'Execution has broken items that need recovery before the system settles.';
  }
  if (overview.alerts.open > 0) {
    return 'There is unresolved alert pressure inside the operating layer.';
  }
  if (overview.deliverability.degradedMailboxes > 0) {
    return 'Mailboxes need review before sending posture is fully clean.';
  }
  if (_replyPressure(overview)) {
    return 'Reply load is now ahead of today\'s outbound movement.';
  }
  if ((overview.today.booked) > 0) {
    return 'Meetings are already converting out of today\'s work.';
  }
  return 'Outbound, replies, and booking posture are stable right now.';
}

String _postureLabel(ControlOverview? overview) {
  final posture = overview?.systemPosture.trim() ?? '';
  if (posture.isNotEmpty) return _titleCase(posture.replaceAll('-', ' '));

  final phase = overview?.systemPhase.trim() ?? '';
  if (phase.isNotEmpty) return _titleCase(phase.replaceAll('-', ' '));

  return overview == null ? 'Waiting' : 'Live';
}

String _titleCase(String input) {
  if (input.isEmpty) return input;
  return input
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');
}

List<_PressureItem> _pressureItems(ControlOverview? overview) {
  if (overview == null) return const [];

  final items = <_PressureItem>[];

  if (overview.execution.failedJobs > 0) {
    items.add(
      _PressureItem(
        label: 'Failed execution',
        value: overview.execution.failedJobs,
        tone: AppTheme.rose,
      ),
    );
  }

  if (overview.alerts.open > 0) {
    items.add(
      _PressureItem(
        label: 'Open alerts',
        value: overview.alerts.open,
        tone: AppTheme.rose,
      ),
    );
  }

  if (overview.deliverability.degradedMailboxes > 0) {
    items.add(
      _PressureItem(
        label: 'Degraded mailboxes',
        value: overview.deliverability.degradedMailboxes,
        tone: AppTheme.amber,
      ),
    );
  }

  if (_replyPressure(overview)) {
    items.add(
      _PressureItem(
        label: 'Reply pressure',
        value: overview.today.replies,
        tone: AppTheme.amber,
      ),
    );
  }

  return items;
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.overview});

  final ControlOverview? overview;

  @override
  Widget build(BuildContext context) {
    return Surface(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 920;

          final lead = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _statusTone(overview),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _statusLabel(overview),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.muted,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _statusLine(overview),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  _statusSupport(overview),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.muted,
                        height: 1.45,
                      ),
                ),
              ),
            ],
          );

          final right = Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              _Pill(label: _postureLabel(overview)),
              _Pill(label: 'Alerts ${(overview?.alerts.open ?? 0).toString().padLeft(2, '0')}'),
              _Pill(label: 'Queue ${(overview?.execution.queuedJobs ?? 0).toString().padLeft(2, '0')}'),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                lead,
                const SizedBox(height: 18),
                right,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: lead),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.topRight,
                  child: right,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TodayBand extends StatelessWidget {
  const _TodayBand({required this.overview});

  final ControlOverview? overview;

  @override
  Widget build(BuildContext context) {
    final items = [
      _Metric(label: 'Sent', value: overview?.today.sent ?? 0),
      _Metric(label: 'Replies', value: overview?.today.replies ?? 0),
      _Metric(label: 'Booked', value: overview?.today.booked ?? 0),
      _Metric(label: 'Failed', value: overview?.execution.failedJobs ?? 0),
    ];

    return Surface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.muted,
                ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: constraints.maxWidth < 520
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 12) / 2,
                        child: _MetricTile(item: item),
                      ),
                  ],
                );
              }

              return Row(
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    Expanded(child: _MetricTile(item: items[i])),
                    if (i != items.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FlowSection extends StatelessWidget {
  const _FlowSection({required this.overview});

  final ControlOverview? overview;

  @override
  Widget build(BuildContext context) {
    final items = [
      _FlowData(
        label: 'Leads',
        value: overview?.totals.leads ?? 0,
        detail: _leadDetail(overview),
      ),
      _FlowData(
        label: 'Outreach',
        value: overview?.totals.messages ?? 0,
        detail: _outreachDetail(overview),
      ),
      _FlowData(
        label: 'Replies',
        value: overview?.totals.replies ?? 0,
        detail: _replyDetail(overview),
        accent: _replyPressure(overview),
      ),
      _FlowData(
        label: 'Meetings',
        value: overview?.totals.meetings ?? 0,
        detail: _meetingDetail(overview),
      ),
    ];

    return Surface(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Flow', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'The operating chain from lead intake to meeting conversion.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.muted,
                ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1120) {
                return Row(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      Expanded(child: _FlowTile(data: items[i])),
                      if (i != items.length - 1) const SizedBox(width: 14),
                    ],
                  ],
                );
              }

              if (constraints.maxWidth >= 680) {
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: (constraints.maxWidth - 14) / 2,
                        child: _FlowTile(data: item),
                      ),
                  ],
                );
              }

              return Column(
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    _FlowTile(data: items[i]),
                    if (i != items.length - 1) const SizedBox(height: 14),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _leadDetail(ControlOverview? overview) {
    if (overview == null) return '—';
    if (overview.totals.leads == 0 && overview.totals.clients == 0) return '—';
    if (overview.totals.clients > 0) {
      return '${overview.totals.clients} ${overview.totals.clients == 1 ? 'client' : 'clients'}';
    }
    return 'Open';
  }

  String _outreachDetail(ControlOverview? overview) {
    if (overview == null) return '—';
    if (overview.today.sent > 0) return '${overview.today.sent} today';
    if (overview.execution.queuedJobs > 0) return '${overview.execution.queuedJobs} queued';
    return overview.totals.messages == 0 ? '—' : 'Waiting';
  }

  String _replyDetail(ControlOverview? overview) {
    if (overview == null) return '—';
    if (overview.today.replies > 0) return '${overview.today.replies} today';
    return overview.totals.replies == 0 ? '—' : 'Open';
  }

  String _meetingDetail(ControlOverview? overview) {
    if (overview == null) return '—';
    if (overview.today.booked > 0) return '${overview.today.booked} today';
    return overview.totals.meetings == 0 ? '—' : 'Booked';
  }
}

class _PressurePanel extends StatelessWidget {
  const _PressurePanel({required this.items});

  final List<_PressureItem> items;

  @override
  Widget build(BuildContext context) {
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pressure', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Signals that need active handling before they spread.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.muted,
                ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const _QuietState(label: 'Clear')
          else
            ...[
              for (int i = 0; i < items.length; i++) ...[
                _PressureRow(item: items[i]),
                if (i != items.length - 1) const SizedBox(height: 10),
              ],
            ],
        ],
      ),
    );
  }
}

class _FootingPanel extends StatelessWidget {
  const _FootingPanel({required this.overview});

  final ControlOverview? overview;

  @override
  Widget build(BuildContext context) {
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Footing', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'The underlying operating base carrying today\'s work.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.muted,
                ),
          ),
          const SizedBox(height: 16),
          _ReadRow(
            label: 'Organizations',
            value: (overview?.totals.organizations ?? 0).toString(),
          ),
          _ReadRow(
            label: 'Clients',
            value: (overview?.totals.clients ?? 0).toString(),
          ),
          _ReadRow(
            label: 'Campaigns',
            value: (overview?.totals.campaigns ?? 0).toString(),
          ),
          _ReadRow(
            label: 'Queued jobs',
            value: (overview?.execution.queuedJobs ?? 0).toString(),
          ),
          _ReadRow(
            label: 'Active mailboxes',
            value: (overview?.deliverability.activeMailboxes ?? 0).toString(),
          ),
          _ReadRow(
            label: 'Posture',
            value: _postureLabel(overview),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.line.withOpacity(0.7)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.muted,
            ),
      ),
    );
  }
}

class _Metric {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.item});

  final _Metric item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.muted,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            item.value.toString().padLeft(2, '0'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}

class _FlowData {
  const _FlowData({
    required this.label,
    required this.value,
    required this.detail,
    this.accent = false,
  });

  final String label;
  final int value;
  final String detail;
  final bool accent;
}

class _FlowTile extends StatelessWidget {
  const _FlowTile({required this.data});

  final _FlowData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: data.accent ? AppTheme.panelSoft : AppTheme.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: data.accent
              ? AppTheme.line.withOpacity(0.95)
              : AppTheme.line.withOpacity(0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.muted,
                ),
          ),
          const SizedBox(height: 20),
          Text('${data.value}', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 10),
          Text(
            data.detail,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _PressureItem {
  const _PressureItem({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final int value;
  final Color tone;
}

class _PressureRow extends StatelessWidget {
  const _PressureRow({required this.item});

  final _PressureItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line.withOpacity(0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: item.tone,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              item.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            item.value.toString().padLeft(2, '0'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: item.tone,
                ),
          ),
        ],
      ),
    );
  }
}

class _QuietState extends StatelessWidget {
  const _QuietState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line.withOpacity(0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppTheme.emerald,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

class _ReadRow extends StatelessWidget {
  const _ReadRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.muted,
                  ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
