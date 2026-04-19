import 'package:flutter/material.dart';

import '../data/repositories/operator_repository.dart';

class CommandScreen extends StatefulWidget {
  const CommandScreen({super.key});

  @override
  State<CommandScreen> createState() => _CommandScreenState();
}

class _CommandScreenState extends State<CommandScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = OperatorRepository().fetchCommandWorkspace();
  }

  Future<void> _refresh() async {
    final next = OperatorRepository().fetchCommandWorkspace();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Command could not load right now.',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final pulse = _asMap(data['pulse']);
        final totals = _asMap(pulse['totals']);
        final today = _asMap(pulse['today']);
        final executionPulse = _asMap(pulse['execution']);
        final deliverabilityPulse = _asMap(pulse['deliverability']);
        final health = _asMap(data['health']);
        final deliverability = _asMap(health['deliverability']);

        final attention = _asList(data['attention']);
        final dispatches = _asList(_asMap(data['execution'])['dispatches']);
        final campaigns = _asList(_asMap(data['outreach'])['campaigns']);
        final clients = _asList(_asMap(data['clients'])['clients']);
        final inquiries = _asList(_asMap(data['conversations'])['inquiries']);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CommandHero(
                  title: _read(data, 'title', fallback: 'Operator command'),
                  subtitle: _read(
                    data,
                    'subtitle',
                    fallback:
                        'One place to see system pressure, business movement, and what needs action now.',
                  ),
                ),
                const SizedBox(height: 18),
                _MetricGrid(
                  metrics: [
                    _MetricData(
                      label: 'Sent today',
                      value: _read(today, 'sent', fallback: '0'),
                    ),
                    _MetricData(
                      label: 'Replies today',
                      value: _read(today, 'replies', fallback: '0'),
                    ),
                    _MetricData(
                      label: 'Booked today',
                      value: _read(today, 'booked', fallback: '0'),
                    ),
                    _MetricData(
                      label: 'Failed jobs',
                      value: _read(executionPulse, 'failedJobs', fallback: '0'),
                    ),
                    _MetricData(
                      label: 'Healthy mailboxes',
                      value: _read(deliverabilityPulse, 'healthyMailboxes', fallback: '0'),
                    ),
                    _MetricData(
                      label: 'Open alerts',
                      value: _read(_asMap(health['alertsSummary']), 'open', fallback: '0'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 1080;
                    final left = Column(
                      children: [
                        _CardSection(
                          title: 'Needs attention now',
                          subtitle: 'The first place to look before moving through the rest of the workspace.',
                          child: _AttentionList(items: attention),
                        ),
                        const SizedBox(height: 18),
                        _CardSection(
                          title: 'Live execution',
                          subtitle: 'Dispatch pressure and current outbound movement.',
                          child: _DispatchList(items: dispatches),
                        ),
                        const SizedBox(height: 18),
                        _CardSection(
                          title: 'Campaign pressure',
                          subtitle: 'Which campaigns are active, stalled, or need review.',
                          child: _CampaignList(items: campaigns),
                        ),
                      ],
                    );

                    final right = Column(
                      children: [
                        _CardSection(
                          title: 'System health',
                          subtitle: 'Mailbox and deliverability posture from the backend.',
                          child: _HealthSummary(
                            totals: totals,
                            deliverability: deliverability,
                            deliverabilityPulse: deliverabilityPulse,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _CardSection(
                          title: 'Clients needing visibility',
                          subtitle: 'Client-side state without leaving command.',
                          child: _ClientList(items: clients),
                        ),
                        const SizedBox(height: 18),
                        _CardSection(
                          title: 'Inbound pressure',
                          subtitle: 'Open inquiries should stay visible from the same surface.',
                          child: _InquiryList(items: inquiries),
                        ),
                      ],
                    );

                    if (stacked) {
                      return Column(
                        children: [
                          left,
                          const SizedBox(height: 18),
                          right,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: left),
                        const SizedBox(width: 18),
                        Expanded(flex: 5, child: right),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommandHero extends StatelessWidget {
  const _CommandHero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Command', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200 ? 6 : width >= 820 ? 3 : 2;

        return GridView.builder(
          itemCount: metrics.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: width >= 820 ? 1.55 : 1.45,
          ),
          itemBuilder: (context, index) => _MetricTile(metric: metrics[index]),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric.label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(metric.value, style: theme.textTheme.headlineMedium),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _AttentionList extends StatelessWidget {
  const _AttentionList({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'Nothing urgent is open right now.');
    }

    return Column(
      children: items
          .take(8)
          .map((item) => _StatusRow(
                title: _read(item, 'title', fallback: 'Needs review'),
                subtitle: _joinNonEmpty([
                  _read(item, 'severity'),
                  _read(item, 'status'),
                ]),
              ))
          .toList(),
    );
  }
}

class _DispatchList extends StatelessWidget {
  const _DispatchList({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'No dispatch activity is visible.');
    }

    return Column(
      children: items
          .take(8)
          .map((item) => _StatusRow(
                title: _read(item, 'subject', fallback: 'Dispatch'),
                subtitle: _joinNonEmpty([
                  _read(item, 'status'),
                  _read(item, 'recipientEmail'),
                  _read(item, 'createdAt'),
                ]),
              ))
          .toList(),
    );
  }
}

class _CampaignList extends StatelessWidget {
  const _CampaignList({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'No campaigns are available.');
    }

    return Column(
      children: items
          .take(8)
          .map((item) => _StatusRow(
                title: _read(item, 'name', fallback: 'Campaign'),
                subtitle: _joinNonEmpty([
                  _read(item, 'status'),
                  _read(item, 'channel'),
                  _read(item, 'createdAt'),
                ]),
              ))
          .toList(),
    );
  }
}

class _ClientList extends StatelessWidget {
  const _ClientList({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'No clients are available.');
    }

    return Column(
      children: items
          .take(8)
          .map((item) => _StatusRow(
                title: _read(item, 'displayName', fallback: _read(item, 'legalName', fallback: 'Client')),
                subtitle: _joinNonEmpty([
                  _read(item, 'status'),
                  _read(item, 'industry'),
                  _read(item, 'websiteUrl'),
                ]),
              ))
          .toList(),
    );
  }
}

class _InquiryList extends StatelessWidget {
  const _InquiryList({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'No open inquiries are visible.');
    }

    return Column(
      children: items
          .take(8)
          .map((item) => _StatusRow(
                title: _read(item, 'subject', fallback: _read(item, 'name', fallback: 'Inquiry')),
                subtitle: _joinNonEmpty([
                  _read(item, 'status'),
                  _read(item, 'email'),
                  _read(item, 'createdAt'),
                ]),
              ))
          .toList(),
    );
  }
}

class _HealthSummary extends StatelessWidget {
  const _HealthSummary({
    required this.totals,
    required this.deliverability,
    required this.deliverabilityPulse,
  });

  final Map<String, dynamic> totals;
  final Map<String, dynamic> deliverability;
  final Map<String, dynamic> deliverabilityPulse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatusRow(
          title: 'Organizations in view',
          subtitle: _read(totals, 'organizations', fallback: '0'),
        ),
        _StatusRow(
          title: 'Clients in system',
          subtitle: _read(totals, 'clients', fallback: '0'),
        ),
        _StatusRow(
          title: 'Campaigns in system',
          subtitle: _read(totals, 'campaigns', fallback: '0'),
        ),
        _StatusRow(
          title: 'Healthy mailboxes',
          subtitle: _read(deliverabilityPulse, 'healthyMailboxes', fallback: _read(deliverability, 'healthyMailboxes', fallback: '0')),
        ),
        _StatusRow(
          title: 'Degraded mailboxes',
          subtitle: _read(deliverabilityPulse, 'degradedMailboxes', fallback: _read(deliverability, 'degradedMailboxes', fallback: '0')),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            subtitle.isEmpty ? 'No detail available.' : subtitle,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(message),
    );
  }
}

class _MetricData {
  const _MetricData({required this.label, required this.value});

  final String label;
  final String value;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asList(dynamic value) {
  return (value as List? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _read(
  Map<String, dynamic> map,
  String key, {
  String fallback = '',
}) {
  final value = map[key];
  if (value == null) return fallback;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
  return '$value';
}

String _joinNonEmpty(List<String> parts) {
  return parts.where((item) => item.trim().isNotEmpty).join(' • ');
}
