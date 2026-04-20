
import 'package:flutter/material.dart';

import '../data/repositories/operator_repository.dart';

class CommandScreen extends StatefulWidget {
  const CommandScreen({super.key});

  @override
  State<CommandScreen> createState() => _CommandScreenState();
}

class _CommandScreenState extends State<CommandScreen> {
  late final OperatorRepository _repo;
  late Future<Map<String, dynamic>> _future;
  String? _busyKey;

  @override
  void initState() {
    super.initState();
    _repo = OperatorRepository();
    _future = _repo.fetchCommandWorkspace();
  }

  Future<void> _refresh() async {
    final next = _repo.fetchCommandWorkspace();
    if (mounted) {
      setState(() {
        _future = next;
      });
    }
    await next;
  }

  Future<void> _runBusy(String key, Future<void> Function() action) async {
    if (_busyKey != null) return;
    setState(() => _busyKey = key);
    try {
      await action();
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyKey = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _ErrorState(
            message: '${snapshot.error}',
            onRetry: _refresh,
          );
        }

        final data = _Json(snapshot.data ?? const <String, dynamic>{});
        final pulse = _Json(data.mapOf('pulse'));
        final today = _Json(pulse.mapOf('today'));
        final executionPulse = _Json(pulse.mapOf('execution'));
        final deliverabilityPulse = _Json(pulse.mapOf('deliverability'));
        final campaignPulse = _Json(pulse.mapOf('campaigns'));

        final execution = _Json(data.mapOf('execution'));
        final health = _Json(data.mapOf('health'));
        final conversations = _Json(data.mapOf('conversations'));
        final outreach = _Json(data.mapOf('outreach'));
        final clients = _Json(data.mapOf('clients'));

        final alerts = health.listOfMaps('alerts');
        final failedJobs = execution.listOfMaps('failedJobs');
        final queuedJobs = execution.listOfMaps('queuedJobs');
        final mailboxes = health.listOfMaps('mailboxes');
        final messages = execution.listOfMaps('emailDispatches');
        final replies = conversations.listOfMaps('replies');
        final inquiries = conversations.listOfMaps('inquiries');
        final campaigns = outreach.listOfMaps('campaigns');
        final clientItems = clients.listOfMaps('items');
        final attention = data.listOfMaps('attention');

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _HeroCard(
                title: data.string('title', fallback: 'Operator command'),
                subtitle: data.string(
                  'subtitle',
                  fallback: 'Live system state across the operator workspace.',
                ),
                rows: [
                  _HeroRow(
                    label: 'Today',
                    value:
                        '${today.intValue('sent')} sent · ${today.intValue('replies')} replies · ${today.intValue('booked')} booked',
                  ),
                  _HeroRow(
                    label: 'Pressure',
                    value:
                        '${executionPulse.intValue('failedJobs')} failed jobs · ${alerts.length} open alerts',
                  ),
                  _HeroRow(
                    label: 'Mailboxes',
                    value:
                        '${deliverabilityPulse.intValue('healthyMailboxes')} healthy · ${deliverabilityPulse.intValue('degradedMailboxes')} degraded',
                  ),
                  _HeroRow(
                    label: 'Campaigns',
                    value:
                        '${campaignPulse.intValue('active')} active · ${campaignPulse.intValue('paused')} paused · ${campaignPulse.intValue('draft')} draft',
                  ),
                  _HeroRow(
                    label: 'Footprint',
                    value:
                        '${clientItems.length} visible clients · ${messages.length} recent sends · ${replies.length} recent replies',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: _busyKey == null
                        ? () => _runBusy(
                              'dispatch_due',
                              () => _repo.dispatchDueJobs(),
                            )
                        : null,
                    child: Text(
                      _busyKey == 'dispatch_due' ? 'Dispatching...' : 'Dispatch due jobs',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _busyKey == null ? _refresh : null,
                    child: const Text('Refresh command'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _MetricGrid(
                items: [
                  _MetricItem(label: 'Sent today', value: '${today.intValue('sent')}'),
                  _MetricItem(label: 'Replies today', value: '${today.intValue('replies')}'),
                  _MetricItem(label: 'Booked today', value: '${today.intValue('booked')}'),
                  _MetricItem(label: 'Active campaigns', value: '${campaignPulse.intValue('active')}'),
                  _MetricItem(label: 'Failed jobs', value: '${failedJobs.length}'),
                  _MetricItem(label: 'Open alerts', value: '${alerts.length}'),
                  _MetricItem(label: 'Healthy mailboxes', value: '${deliverabilityPulse.intValue('healthyMailboxes')}'),
                  _MetricItem(label: 'Degraded mailboxes', value: '${deliverabilityPulse.intValue('degradedMailboxes')}'),
                ],
              ),
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Needs attention now',
                subtitle: 'Immediate operator pressure across the live system.',
                child: attention.isEmpty
                    ? const _EmptyState(text: 'No urgent system pressure is showing right now.')
                    : Column(
                        children: attention.take(8).map((item) {
                          final kind = item.string('kind');
                          final id = item.string('id');
                          final title = item.string('title', fallback: 'Untitled');
                          final status = item.string('status');
                          final severity = item.string('severity');
                          Widget? action;
                          if (kind == 'alert' && id.isNotEmpty) {
                            action = _ActionButton(
                              label: _busyKey == 'alert:$id' ? 'Resolving...' : 'Resolve',
                              onPressed: _busyKey == null
                                  ? () => _runBusy('alert:$id', () => _repo.resolveAlert(id))
                                  : null,
                            );
                          } else if (kind == 'campaign' && id.isNotEmpty) {
                            action = _ActionButton(
                              label: _busyKey == 'campaign:$id' ? 'Activating...' : 'Activate',
                              onPressed: _busyKey == null
                                  ? () => _runBusy('campaign:$id', () => _repo.activateCampaign(id))
                                  : null,
                            );
                          }
                          return _SimpleRow(
                            title: title,
                            subtitle: [kind, status, severity]
                                .where((value) => value.trim().isNotEmpty)
                                .join(' · '),
                            trailing: action,
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 18),
              _TwoColumnWrap(
                left: _SectionCard(
                  title: 'Open alerts',
                  subtitle: 'Resolve system alerts directly from command.',
                  child: alerts.isEmpty
                      ? const _EmptyState(text: 'No open alerts.')
                      : Column(
                          children: alerts.map((alert) {
                            final id = alert.string('id');
                            final title = alert.string('title', fallback: 'System alert');
                            final meta = [
                              alert.string('severity'),
                              alert.string('category'),
                              alert.string('clientName'),
                              alert.string('campaignName'),
                            ].where((value) => value.trim().isNotEmpty).join(' · ');
                            return _SimpleRow(
                              title: title,
                              subtitle: meta,
                              caption: alert.string('bodyText'),
                              trailing: _ActionButton(
                                label: _busyKey == 'resolve:$id' ? 'Resolving...' : 'Resolve',
                                onPressed: id.isEmpty || _busyKey != null
                                    ? null
                                    : () => _runBusy('resolve:$id', () => _repo.resolveAlert(id)),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                right: _SectionCard(
                  title: 'Failed jobs',
                  subtitle: 'Re-run failed execution directly from command.',
                  child: failedJobs.isEmpty
                      ? const _EmptyState(text: 'No failed jobs.')
                      : Column(
                          children: failedJobs.map((job) {
                            final id = job.string('id');
                            final title = job.string('type', fallback: 'Job');
                            final meta = [
                              job.string('clientName'),
                              job.string('campaignName'),
                              'attempt ${job.intValue('attemptCount')}/${job.intValue('maxAttempts')}',
                            ].where((value) => value.trim().isNotEmpty).join(' · ');
                            return _SimpleRow(
                              title: title,
                              subtitle: meta,
                              caption: job.string('error'),
                              trailing: _ActionButton(
                                label: _busyKey == 'job:$id' ? 'Running...' : 'Run now',
                                onPressed: id.isEmpty || _busyKey != null
                                    ? null
                                    : () => _runBusy('job:$id', () => _repo.runJob(jobId: id, force: true)),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              _TwoColumnWrap(
                left: _SectionCard(
                  title: 'Campaigns',
                  subtitle: 'Recent campaigns across the system.',
                  child: campaigns.isEmpty
                      ? const _EmptyState(text: 'No campaigns found.')
                      : Column(
                          children: campaigns.map((campaign) {
                            final id = campaign.string('id');
                            final status = campaign.string('status');
                            return _SimpleRow(
                              title: campaign.string('name', fallback: 'Campaign'),
                              subtitle: [
                                campaign.string('clientName'),
                                status,
                                campaign.string('generationState'),
                              ].where((value) => value.trim().isNotEmpty).join(' · '),
                              trailing: status == 'ACTIVE'
                                  ? const _Pill(text: 'Active')
                                  : _ActionButton(
                                      label: _busyKey == 'activate:$id' ? 'Activating...' : 'Activate',
                                      onPressed: id.isEmpty || _busyKey != null
                                          ? null
                                          : () => _runBusy(
                                                'activate:$id',
                                                () => _repo.activateCampaign(id),
                                              ),
                                    ),
                            );
                          }).toList(),
                        ),
                ),
                right: _SectionCard(
                  title: 'Mailbox health',
                  subtitle: 'Refresh degraded or stale mailbox posture.',
                  child: mailboxes.isEmpty
                      ? const _EmptyState(text: 'No mailboxes found.')
                      : Column(
                          children: mailboxes.map((mailbox) {
                            final id = mailbox.string('id');
                            final healthStatus = mailbox.string('healthStatus');
                            return _SimpleRow(
                              title: mailbox.string('emailAddress', fallback: mailbox.string('label')),
                              subtitle: [
                                mailbox.string('clientName'),
                                mailbox.string('provider'),
                                healthStatus,
                              ].where((value) => value.trim().isNotEmpty).join(' · '),
                              trailing: _ActionButton(
                                label: _busyKey == 'mailbox:$id' ? 'Refreshing...' : 'Refresh',
                                onPressed: id.isEmpty || _busyKey != null
                                    ? null
                                    : () => _runBusy(
                                          'mailbox:$id',
                                          () => _repo.refreshMailboxHealth(id),
                                        ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              _TwoColumnWrap(
                left: _SectionCard(
                  title: 'Recent outreach',
                  subtitle: 'Real sent or queued outreach messages.',
                  child: messages.isEmpty
                      ? const _EmptyState(text: 'No outreach messages found.')
                      : Column(
                          children: messages.map((message) {
                            final leadId = message.string('leadId');
                            final status = message.string('status');
                            return _SimpleRow(
                              title: message.string('subjectLine', fallback: message.string('toEmail', fallback: 'Outreach message')),
                              subtitle: [
                                message.string('clientName'),
                                message.string('campaignName'),
                                message.string('leadName'),
                                status,
                              ].where((value) => value.trim().isNotEmpty).join(' · '),
                              caption: message.string('mailboxEmail'),
                              trailing: (leadId.isNotEmpty && status == 'QUEUED')
                                  ? _ActionButton(
                                      label: _busyKey == 'send:$leadId' ? 'Queueing...' : 'Send now',
                                      onPressed: _busyKey != null
                                          ? null
                                          : () => _runBusy(
                                                'send:$leadId',
                                                () => _repo.queueLeadFirstSend(leadId: leadId),
                                              ),
                                    )
                                  : null,
                            );
                          }).toList(),
                        ),
                ),
                right: _SectionCard(
                  title: 'Recent replies',
                  subtitle: 'Incoming response flow across campaigns.',
                  child: replies.isEmpty
                      ? const _EmptyState(text: 'No replies found.')
                      : Column(
                          children: replies.map((reply) {
                            return _SimpleRow(
                              title: reply.string('fromEmail', fallback: 'Reply'),
                              subtitle: [
                                reply.string('clientName'),
                                reply.string('campaignName'),
                                reply.string('intent'),
                                reply.string('meetingStatus'),
                              ].where((value) => value.trim().isNotEmpty).join(' · '),
                              caption: reply.string('bodyText'),
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              _TwoColumnWrap(
                left: _SectionCard(
                  title: 'Public inquiries',
                  subtitle: 'Human attention and queue pressure.',
                  child: inquiries.isEmpty
                      ? const _EmptyState(text: 'No public inquiries.')
                      : Column(
                          children: inquiries.map((inquiry) {
                            return _SimpleRow(
                              title: inquiry.string('company', fallback: inquiry.string('name', fallback: 'Inquiry')),
                              subtitle: [
                                inquiry.string('email'),
                                inquiry.string('status'),
                                inquiry.string('assignedToName'),
                              ].where((value) => value.trim().isNotEmpty).join(' · '),
                              caption: inquiry.string('message'),
                            );
                          }).toList(),
                        ),
                ),
                right: _SectionCard(
                  title: 'Clients',
                  subtitle: 'Recent client records visible to operator.',
                  child: clientItems.isEmpty
                      ? const _EmptyState(text: 'No clients found.')
                      : Column(
                          children: clientItems.map((client) {
                            return _SimpleRow(
                              title: client.string('displayName', fallback: client.string('legalName', fallback: 'Client')),
                              subtitle: [
                                client.string('status'),
                                client.string('industry'),
                                client.string('organizationName'),
                              ].where((value) => value.trim().isNotEmpty).join(' · '),
                              caption: client.string('websiteUrl'),
                            );
                          }).toList(),
                        ),
                ),
              ),
              if (queuedJobs.isNotEmpty) ...[
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Queued and running jobs',
                  subtitle: 'What the system is currently carrying.',
                  child: Column(
                    children: queuedJobs.map((job) {
                      return _SimpleRow(
                        title: job.string('type', fallback: 'Job'),
                        subtitle: [
                          job.string('status'),
                          job.string('clientName'),
                          job.string('campaignName'),
                        ].where((value) => value.trim().isNotEmpty).join(' · '),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Json {
  const _Json(this.raw);
  final Map<String, dynamic> raw;

  Map<String, dynamic> mapOf(String key) {
    final value = raw[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry('$k', v));
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> listOfMaps(String key) {
    final value = raw[key];
    if (value is! List) return const [];
    return value
        .whereType<Object?>()
        .map((item) {
          if (item is Map<String, dynamic>) return item;
          if (item is Map) return item.map((k, v) => MapEntry('$k', v));
          return <String, dynamic>{};
        })
        .toList();
  }

  String string(String key, {String fallback = ''}) {
    final value = raw[key];
    if (value == null) return fallback;
    final text = '$value'.trim();
    return text.isEmpty ? fallback : text;
  }

  int intValue(String key, {int fallback = 0}) {
    final value = raw[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.rows,
  });

  final String title;
  final String subtitle;
  final List<_HeroRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.16),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Command', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(title, style: theme.textTheme.displaySmall),
          const SizedBox(height: 14),
          Text(subtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyLarge,
                          children: [
                            TextSpan(
                              text: '${row.label}  ',
                              style: theme.textTheme.titleLarge,
                            ),
                            TextSpan(text: row.value),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroRow {
  const _HeroRow({required this.label, required this.value});
  final String label;
  final String value;
}

class _MetricItem {
  const _MetricItem({required this.label, required this.value});
  final String label;
  final String value;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_MetricItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 18,
      runSpacing: 18,
      children: items
          .map(
            (item) => Container(
              width: 220,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 14),
                  Text(item.value, style: theme.textTheme.displaySmall),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TwoColumnWrap extends StatelessWidget {
  const _TwoColumnWrap({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1180) {
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
            Expanded(child: left),
            const SizedBox(width: 18),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.12),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({
    required this.title,
    this.subtitle = '',
    this.caption = '',
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.10),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(subtitle, style: theme.textTheme.bodyMedium),
                ],
                if (caption.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 14),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onPressed, child: Text(label));
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.18)),
      ),
      child: Text(text, style: theme.textTheme.labelLarge),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Command could not load.', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
