import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';
import 'package:orchestrate_app/features/client/widgets/operational_continuity_strip.dart';
import 'package:orchestrate_app/features/guidance/guidance_drawer.dart';
import 'package:orchestrate_app/features/guidance/widgets/why_affordance.dart';

/// Outreach is a managed-execution status surface — never a manual
/// infrastructure console. The client should only ever see:
///   * what Orchestrate is doing for them, and
///   * the one client action (if any) that is genuinely blocking progress.
///
/// Start/Retry/Activate buttons have been removed: the backend auto-activates
/// the campaign when readiness is satisfied, and recovery is Orchestrate's
/// responsibility. If something is on the client's side (mailbox / auth /
/// subscription / setup), a single clientAction button routes them to the
/// right surface.
class ClientOutreachScreen extends StatefulWidget {
  const ClientOutreachScreen({super.key});

  @override
  State<ClientOutreachScreen> createState() => _ClientOutreachScreenState();
}

class _ClientOutreachScreenState extends State<ClientOutreachScreen> {
  final ClientPortalRepository _repository = ClientPortalRepository();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() => _repository.fetchOutreach();

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(
            eyebrow: 'Outreach',
            label: 'Loading managed execution status',
          );
        }
        if (snapshot.hasError) {
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Outreach is temporarily unavailable',
            onRetry: _refresh,
          );
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final readiness = asMap(data['readiness']);
        final summary = asMap(data['summary']);
        final mailbox = asMap(data['mailbox']);
        final campaigns = asList(data['campaigns']);
        final managed = _readManagedExecution(asMap(data['managedExecution']));
        final replies = _intValue(summary['replies']);
        final meetings = _intValue(summary['meetings']);

        return ClientPage(
          eyebrow: 'Operations',
          title: managed.headline,
          subtitle: managed.description,
          banner: _ManagedExecutionBanner(state: managed),
          actions: _buildActions(context, managed: managed, replies: replies),
          children: [
            const OperationalContinuityStrip(
                surface: 'client_operations_runtime'),
            const SizedBox(height: 18),
            ClientMetricStrip(metrics: [
              ClientMetric('Scopes', '${summary['campaigns'] ?? 0}'),
              ClientMetric('Queued', '${summary['queued'] ?? 0}'),
              ClientMetric('Sent', '${summary['sent'] ?? 0}'),
              ClientMetric('Replies', '$replies'),
              ClientMetric('Meetings', '$meetings'),
            ]),
            const SizedBox(height: 18),
            _OrchestrateActivityPanel(
              managed: managed,
              campaigns: campaigns,
              mailbox: mailbox,
              readiness: readiness,
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'What Orchestrate is watching for you',
              subtitle:
                  'These are the inputs Orchestrate needs from you. When everything reads "Ready", outreach runs without your involvement.',
              children: _buildReadinessRows(readiness),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildActions(
    BuildContext context, {
    required _ManagedExecution managed,
    required int replies,
  }) {
    final widgets = <Widget>[];
    final action = managed.clientAction;
    if (action != null) {
      widgets.add(
        FilledButton.icon(
          onPressed: () => _routeForAction(context, action.code),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: Text(action.label),
        ),
      );
    }
    if (replies > 0) {
      widgets.add(
        OutlinedButton.icon(
          onPressed: () => context.go('/client/replies'),
          icon: const Icon(Icons.forum_outlined, size: 18),
          label: const Text('Review replies'),
        ),
      );
    }
    widgets.add(
      WhyAffordance(
        target: GuidanceTarget.readiness,
        surface: 'client_outreach_managed_execution_banner',
        label: 'Explain this state',
      ),
    );
    return widgets;
  }

  void _routeForAction(BuildContext context, String code) {
    switch (code) {
      case 'complete_setup':
        context.go('/client/setup');
        return;
      case 'resolve_subscription':
        context.go('/client/billing');
        return;
      case 'complete_representation_authorization':
        // Inline action continuity — Representation owns the
        // authorize-in-place gate. No scavenger hunt back to Campaign.
        context.go('/client/representation');
        return;
      case 'complete_business_identity':
      case 'open_business_identity':
        context.go('/client/representation');
        return;
      case 'provision_mailbox':
      case 'connect_mailbox':
      case 'reconnect_mailbox':
      case 'verify_mailbox':
      case 'verify_sending_identity':
        context.go('/client/infrastructure');
        return;
      default:
        context.go('/client/settings');
    }
  }

  List<Widget> _buildReadinessRows(Map<String, dynamic> readiness) {
    final entries = <_ReadinessEntry>[
      _ReadinessEntry(
        label: 'Business setup',
        ready: readiness['setupComplete'] == true,
        readyMessage: 'Complete — Orchestrate has your offer and market.',
        notReadyMessage:
            'Open Setup to give Orchestrate your offer and target market.',
      ),
      _ReadinessEntry(
        label: 'Representation authorization',
        ready: readiness['representationAuthorized'] == true,
        readyMessage:
            'You have authorized Orchestrate to send outreach on your behalf.',
        notReadyMessage:
            'Authorize Orchestrate from the Campaign screen so we can send for you.',
      ),
      _ReadinessEntry(
        label: 'Sending mailbox',
        ready: readiness['mailboxReady'] == true,
        readyMessage: 'Connected and verified.',
        notReadyMessage: 'Connect or verify the mailbox we should send from.',
      ),
      _ReadinessEntry(
        label: 'Outbound sending identity',
        ready: readiness['outboundEmailReady'] == true,
        readyMessage: 'Sending identity is ready.',
        notReadyMessage:
            'Sending identity is not yet verified. Open Mailbox to complete it.',
      ),
    ];

    return [
      for (final entry in entries)
        ClientInfoRow(
          title: entry.label,
          primary: entry.ready ? entry.readyMessage : entry.notReadyMessage,
          trailing: ClientBadge(label: entry.ready ? 'Ready' : 'Needs you'),
        ),
    ];
  }
}

class _ReadinessEntry {
  const _ReadinessEntry({
    required this.label,
    required this.ready,
    required this.readyMessage,
    required this.notReadyMessage,
  });

  final String label;
  final bool ready;
  final String readyMessage;
  final String notReadyMessage;
}

class _ManagedExecutionBanner extends StatelessWidget {
  const _ManagedExecutionBanner({required this.state});

  final _ManagedExecution state;

  @override
  Widget build(BuildContext context) {
    return ClientStatusBanner(
      tone: _toneFor(state.state),
      title: state.headline,
      message: state.description,
    );
  }

  ClientBannerTone _toneFor(String stateCode) {
    switch (stateCode) {
      case 'awaiting_setup':
      case 'awaiting_subscription':
      case 'awaiting_authorization':
      case 'awaiting_mailbox':
        return ClientBannerTone.warning;
      case 'orchestrate_blocked_internal':
        return ClientBannerTone.blocked;
      case 'waiting_for_replies':
      case 'orchestrate_working':
      case 'ready_to_execute':
        return ClientBannerTone.info;
      case 'orchestrate_recovering':
        return ClientBannerTone.warning;
      case 'executing':
      default:
        return ClientBannerTone.success;
    }
  }
}

class _OrchestrateActivityPanel extends StatelessWidget {
  const _OrchestrateActivityPanel({
    required this.managed,
    required this.campaigns,
    required this.mailbox,
    required this.readiness,
  });

  final _ManagedExecution managed;
  final List<dynamic> campaigns;
  final Map<String, dynamic> mailbox;
  final Map<String, dynamic> readiness;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final campaignSummary = _summarizeCampaigns(campaigns);
    if (campaignSummary != null) {
      children.add(ClientInfoRow(
        title: 'Active campaign',
        primary: campaignSummary.primary,
        secondary: campaignSummary.secondary,
      ));
    }

    children.add(ClientInfoRow(
      title: 'Sending mailbox',
      primary: _mailboxPrimary(mailbox),
      secondary: _mailboxSecondary(mailbox),
    ));

    if (children.isEmpty) {
      children.add(const ClientEmptyState(
        message:
            'Orchestrate has not started outreach yet. The readiness checklist below shows what we are still waiting on.',
      ));
    }

    return ClientPanel(
      title: 'What Orchestrate is doing',
      subtitle: managed.description,
      children: children,
    );
  }

  ({String primary, String secondary})? _summarizeCampaigns(
      List<dynamic> campaigns) {
    if (campaigns.isEmpty) return null;
    final first = asMap(campaigns.first);
    final name = readText(first, 'name', fallback: 'Primary execution');
    final status = titleCase(readText(first, 'status'));
    final counts = asMap(first['counts']);
    final primary = status.isEmpty ? name : '$name · $status';
    final secondary =
        'Leads ${counts['leads'] ?? 0} · Sent ${counts['messages'] ?? 0} · Replies ${counts['replies'] ?? 0} · Meetings ${counts['meetings'] ?? 0}';
    return (primary: primary, secondary: secondary);
  }

  String _mailboxPrimary(Map<String, dynamic> mailbox) {
    final primary = asMap(mailbox['primary']);
    if (primary.isEmpty) {
      return 'Orchestrate is still waiting on a sending mailbox from you.';
    }
    return readText(primary, 'emailAddress',
        fallback: 'A mailbox is connected.');
  }

  String _mailboxSecondary(Map<String, dynamic> mailbox) {
    final primary = asMap(mailbox['primary']);
    if (primary.isEmpty) return '';
    final parts = [
      titleCase(readText(primary, 'status')),
      titleCase(readText(primary, 'connectionState')),
      titleCase(readText(primary, 'healthStatus')),
    ].where((item) => item.isNotEmpty).toList();
    return parts.isEmpty ? '' : parts.join(' · ');
  }
}

class _ManagedExecution {
  const _ManagedExecution({
    required this.state,
    required this.headline,
    required this.description,
    this.clientAction,
  });

  final String state;
  final String headline;
  final String description;
  final _ManagedClientAction? clientAction;
}

class _ManagedClientAction {
  const _ManagedClientAction({
    required this.code,
    required this.label,
    required this.message,
    required this.severity,
  });

  final String code;
  final String label;
  final String message;
  final String severity;
}

_ManagedExecution _readManagedExecution(Map<String, dynamic> map) {
  if (map.isEmpty) {
    return const _ManagedExecution(
      state: 'orchestrate_working',
      headline: 'Orchestrate is working',
      description:
          'Discovery, qualification, and outreach are running on your behalf.',
    );
  }
  final actionMap = asMap(map['clientAction']);
  final action = actionMap.isEmpty
      ? null
      : _ManagedClientAction(
          code: readText(actionMap, 'code'),
          label: readText(actionMap, 'label', fallback: 'Resolve'),
          message: readText(actionMap, 'message'),
          severity: readText(actionMap, 'severity', fallback: 'warning'),
        );
  return _ManagedExecution(
    state: readText(map, 'state', fallback: 'orchestrate_working'),
    headline: readText(map, 'headline', fallback: 'Orchestrate is working'),
    description: readText(map, 'description'),
    clientAction: action,
  );
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
