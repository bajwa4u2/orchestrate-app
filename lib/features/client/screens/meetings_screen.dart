import 'package:flutter/material.dart';

import 'package:orchestrate_app/data/repositories/client/client_meetings_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_workflow_state_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_charts.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  late Future<List<Map<String, dynamic>>> _futures;

  @override
  void initState() {
    super.initState();
    _futures = _load();
  }

  Future<List<Map<String, dynamic>>> _load() => Future.wait([
        ClientMeetingsRepository().fetchMeetings(),
        ClientWorkflowStateRepository().fetchWorkflowState().catchError((_) => const <String, dynamic>{}),
      ]);

  void _retry() {
    // An arrow body here evaluates to the assigned value — a Future — and
    // Flutter asserts on a setState callback that returns one. Started
    // outside setState, assigned inside a block.
    final request = _load();
    setState(() {
      _futures = request;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futures,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(label: 'Loading meetings');
        }
        if (snapshot.hasError) {
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Meetings are temporarily unavailable',
            onRetry: _retry,
          );
        }
        final data = snapshot.data?[0] ?? const <String, dynamic>{};
        final workflowState = snapshot.data?[1] ?? const <String, dynamic>{};
        final summary = asMap(data['summary']);
        final provider = asMap(data['provider']);
        final meetings = asList(data['items']).map(asMap).toList();
        final upstreamBlocker = _resolveUpstreamBlocker(meetings, workflowState);
        // A meeting the provider never confirmed. The local row is written
        // before the provider is called — deliberately, because a provider
        // meeting with no local row is invisible — so a row on its own proves
        // nothing about whether anybody was invited. Status cannot tell these
        // apart: PROPOSED covers both a real meeting waiting on a counterparty
        // and a handoff that never landed and never will.
        final stranded = meetings
            .where((item) =>
                readText(item, 'handoffStage') == 'NEVER_REACHED_PROVIDER')
            .toList();
        final handoff = meetings
            .where((item) =>
                readText(item, 'status') == 'PROPOSED' &&
                readText(item, 'handoffStage') != 'NEVER_REACHED_PROVIDER')
            .toList();
        final upcoming = meetings.where((item) {
          final status = readText(item, 'status');
          final scheduled = DateTime.tryParse('${item['scheduledAt'] ?? ''}');
          return ['BOOKED', 'SCHEDULED'].contains(status) &&
              scheduled != null &&
              scheduled.toLocal().isAfter(DateTime.now());
        }).toList();
        final unscheduledBooked = meetings
            .where((item) =>
                ['BOOKED', 'SCHEDULED'].contains(readText(item, 'status')) &&
                DateTime.tryParse('${item['scheduledAt'] ?? ''}') == null)
            .toList();
        final past = meetings.where((item) {
          final status = readText(item, 'status');
          final scheduled = DateTime.tryParse('${item['scheduledAt'] ?? ''}');
          // A meeting that never reached the provider did not happen and did
          // not get missed. Listing it as past would say a meeting took place.
          if (readText(item, 'handoffStage') == 'NEVER_REACHED_PROVIDER') {
            return false;
          }
          return ['COMPLETED', 'CANCELED', 'NO_SHOW'].contains(status) ||
              (scheduled != null &&
                  scheduled.toLocal().isBefore(DateTime.now()));
        }).toList();
        final banner = _meetingBanner(
          stranded: stranded,
          handoff: handoff,
          upcoming: upcoming,
          past: past,
          total: meetings.length,
          upstreamBlocker: upstreamBlocker,
        );

        return ClientPage(
          eyebrow: 'Meetings',
          title: meetings.isEmpty
              ? 'No meetings are on record yet'
              : '${meetings.length} meeting records',
          subtitle:
              'Use this timeline to prepare for upcoming meetings, review handoffs, and understand what has already passed.',
          banner: banner,
          actions: [
            if (upcoming.isNotEmpty)
              FilledButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Upcoming meetings are listed below.')),
                ),
                icon: const Icon(Icons.event_available_outlined, size: 18),
                label: const Text('Review upcoming meetings'),
              ),
          ],
          children: [
            // A count Orchestrate cannot observe is shown as unknown, not as
            // zero. The backend sends null for booked / completed / missed
            // while no meeting provider is connected, because "we have no way
            // to know" and "it did not happen" are different statements and
            // only one of them was ever true here.
            ClientMetricStrip(metrics: [
              ClientMetric('Total', '${summary['total'] ?? meetings.length}'),
              ClientMetric('Open handoffs', '${summary['openHandoffs'] ?? 0}'),
              ClientMetric('Booked', _count(summary['booked'])),
              ClientMetric('Completed', _count(summary['completed'])),
            ]),
            const SizedBox(height: 18),
            ...(() {
              // No chart at all when outcomes are unobservable. Bars of zero
              // would draw a picture of meetings that did not happen, which is
              // a claim the product is in no position to make.
              if (provider['observesOutcomes'] != true) return <Widget>[];
              final dist = <ClientChartDatum>[
                ClientChartDatum('Open handoffs', _mi(summary['openHandoffs']),
                    tone: ClientBarTone.attention),
                ClientChartDatum('Booked', _mi(summary['booked'])),
                ClientChartDatum('Completed', _mi(summary['completed']),
                    tone: ClientBarTone.positive),
                ClientChartDatum('Missed', _mi(summary['missed']),
                    tone: ClientBarTone.negative),
              ];
              if (!chartHasSignal(dist)) return <Widget>[];
              return <Widget>[
                ClientPanel(
                  title: 'Meeting status',
                  subtitle:
                      'Where your meetings stand, each a live count from your records.',
                  children: [ClientBarChart(data: dist)],
                ),
                const SizedBox(height: 18),
              ];
            })(),
            ClientPanel(
              title: 'Meeting provider',
              children: [
                ClientInfoRow(
                  title: provider['observesOutcomes'] == true
                      ? 'Connected to ${provider['meetingProviderName'] ?? 'a meeting provider'}'
                      : 'No meeting provider connected',
                  primary:
                      'Mailbox readiness: ${provider['mailboxReady'] == true ? 'Ready' : 'Not ready'}',
                  // The backend's own words about what it can and cannot see,
                  // rather than this screen guessing. Said to the business in
                  // terms of what happens to its meetings, not in terms of
                  // which endpoint is missing.
                  secondary: provider['outcomesNote'] as String? ??
                      'Meeting outcomes are reported by the connected provider.',
                ),
              ],
            ),
            const SizedBox(height: 18),
            // First, because it is the only group here that is waiting on us
            // rather than on somebody else. Rendered only when it happens.
            if (stranded.isNotEmpty) ...[
              _MeetingGroup(
                title: 'Never reached the meeting provider',
                empty: '',
                items: stranded,
                nextStep: 'Nobody was invited',
              ),
              const SizedBox(height: 18),
            ],
            _MeetingGroup(
              title: 'Unconfirmed handoffs',
              empty:
                  'No handoffs are waiting. Interested replies will appear here when the backend creates a meeting handoff.',
              items: handoff,
              nextStep: 'Confirm handoff details',
            ),
            const SizedBox(height: 18),
            _MeetingGroup(
              title: 'Upcoming meetings',
              empty:
                  'No upcoming meetings scheduled yet. Meetings will appear when recipients book time through outreach.',
              items: [...upcoming, ...unscheduledBooked],
              nextStep: 'Prepare',
            ),
            const SizedBox(height: 18),
            _MeetingGroup(
              title: 'Past meetings',
              empty: 'Past meetings will appear after scheduled time passes.',
              items: past,
              nextStep: 'Review outcome',
            ),
          ],
        );
      },
    );
  }
}

class _MeetingGroup extends StatelessWidget {
  const _MeetingGroup({
    required this.title,
    required this.empty,
    required this.items,
    required this.nextStep,
  });

  final String title;
  final String empty;
  final List<Map<String, dynamic>> items;
  final String nextStep;

  @override
  Widget build(BuildContext context) {
    return ClientPanel(
      title: title,
      children: items.isEmpty
          ? [ClientEmptyState(message: empty)]
          : [
              for (final item in items)
                ClientInfoRow(
                  title: readText(item, 'title', fallback: 'Meeting'),
                  primary: [
                    nextStep,
                    titleCase(readText(item, 'status')),
                    relativeDateLabel(item['scheduledAt']),
                    dateLabel(item['scheduledAt']),
                  ].where((part) => part.isNotEmpty).join(' · '),
                  secondary: [
                    readText(asMap(item['contact']), 'name',
                        fallback: readText(asMap(item['contact']), 'email')),
                    readText(asMap(item['contact']), 'company'),
                    readText(asMap(item['campaign']), 'name'),
                    readText(item, 'bookingUrl'),
                  ].where((part) => part.isNotEmpty).join(' · '),
                ),
            ],
    );
  }
}

int _mi(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

/// A count for display, where null means the product cannot see it.
///
/// `_mi` folds null to 0 because a chart needs a number. A metric does not:
/// printing 0 where nothing is known tells a business its meetings did not
/// happen, which is a stronger and different claim than the truth, which is
/// that Orchestrate is not connected to whatever runs them.
String _count(dynamic value) {
  if (value == null) return '—';
  if (value is num) return '${value.toInt()}';
  return '${int.tryParse('$value') ?? 0}';
}

String? _resolveUpstreamBlocker(
  List<Map<String, dynamic>> meetings,
  Map<String, dynamic> workflowState,
) {
  if (meetings.isNotEmpty) return null;
  final stages = asMap(workflowState['stages']);
  final meetingStage = asMap(stages['meetings']);
  final blocker = asMap(meetingStage['upstreamBlocker']);
  if (blocker.isNotEmpty) return readText(blocker, 'message');
  final overallState = readText(workflowState, 'overallState');
  if (overallState.isNotEmpty && overallState != 'OUTREACH_RUNNING' && overallState != 'HEALTHY') {
    final primaryBlocker = asMap(workflowState['primaryBlocker']);
    final msg = readText(primaryBlocker, 'message');
    if (msg.isNotEmpty) return msg;
  }
  return null;
}

ClientStatusBanner _meetingBanner({
  required List<Map<String, dynamic>> stranded,
  required List<Map<String, dynamic>> handoff,
  required List<Map<String, dynamic>> upcoming,
  required List<Map<String, dynamic>> past,
  required int total,
  String? upstreamBlocker,
}) {
  // Ahead of handoffs, because a handoff is a wait and this is not. Nothing
  // will arrive for these however long they are left.
  if (stranded.isNotEmpty) {
    final one = stranded.length == 1;
    return ClientStatusBanner(
      tone: ClientBannerTone.warning,
      title: one
          ? 'A meeting was never created with the meeting provider'
          : '${stranded.length} meetings were never created with the meeting provider',
      message: one
          ? 'It was prepared here, but the meeting provider never confirmed it, so nobody was '
              'invited and nothing will arrive for it. Offer the meeting again to create it.'
          : 'They were prepared here, but the meeting provider never confirmed them, so nobody '
              'was invited and nothing will arrive for them. Offer them again to create them.',
    );
  }
  if (handoff.isNotEmpty) {
    return ClientStatusBanner(
      tone: ClientBannerTone.warning,
      title: '${handoff.length} meeting handoffs need review',
      message:
          'Review unconfirmed handoffs so interested replies do not stall before booking. If you do nothing, these remain pending.',
    );
  }
  if (upcoming.isNotEmpty) {
    return ClientStatusBanner(
      tone: ClientBannerTone.success,
      title: 'Next meeting ${relativeDateLabel(upcoming.first['scheduledAt'])}',
      message:
          'Prepare for upcoming meetings using the contact and campaign context below.',
    );
  }
  if (total == 0) {
    if (upstreamBlocker != null && upstreamBlocker.isNotEmpty) {
      return ClientStatusBanner(
        tone: ClientBannerTone.warning,
        title: 'Meetings require managed execution to be running',
        message: upstreamBlocker,
      );
    }
    return const ClientStatusBanner(
      tone: ClientBannerTone.info,
      title: 'No meetings scheduled yet',
      message:
          'Meetings appear when a recipient replies and classifies as interested. Calendar integration is not automatic. Booking occurs through the configured booking URL.',
    );
  }
  return const ClientStatusBanner(
    tone: ClientBannerTone.info,
    title: 'No upcoming meetings',
    message:
        'There are meeting records, but none are upcoming. Review past outcomes and watch replies for new handoffs.',
  );
}
