import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/data/repositories/client/client_meetings_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ClientMeetingsRepository().fetchMeetings();
  }

  void _retry() {
    setState(() => _future = ClientMeetingsRepository().fetchMeetings());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(label: 'Loading meetings');
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return ClientErrorView(
            message:
                error is ApiException ? error.displayMessage : error.toString(),
            onRetry: _retry,
          );
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final summary = asMap(data['summary']);
        final provider = asMap(data['provider']);
        final meetings = asList(data['items']).map(asMap).toList();
        final handoff = meetings
            .where((item) => readText(item, 'status') == 'PROPOSED')
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
          return ['COMPLETED', 'CANCELED', 'NO_SHOW'].contains(status) ||
              (scheduled != null &&
                  scheduled.toLocal().isBefore(DateTime.now()));
        }).toList();
        final banner = _meetingBanner(
          handoff: handoff,
          upcoming: upcoming,
          past: past,
          total: meetings.length,
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
            ClientMetricStrip(metrics: [
              ClientMetric('Total', '${summary['total'] ?? meetings.length}'),
              ClientMetric('Open handoffs', '${summary['openHandoffs'] ?? 0}'),
              ClientMetric('Booked', '${summary['booked'] ?? 0}'),
              ClientMetric('Completed', '${summary['completed'] ?? 0}'),
            ]),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Calendar and provider state',
              children: [
                ClientInfoRow(
                  title: provider['calendarConnected'] == true
                      ? 'Calendar connected'
                      : 'Calendar connection not available',
                  primary:
                      'Mailbox readiness: ${provider['mailboxReady'] == true ? 'Ready' : 'Not ready'}',
                  secondary:
                      'Calendar provider status is not currently exposed by the backend, so unsupported calendar actions are hidden.',
                ),
              ],
            ),
            const SizedBox(height: 18),
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

ClientStatusBanner _meetingBanner({
  required List<Map<String, dynamic>> handoff,
  required List<Map<String, dynamic>> upcoming,
  required List<Map<String, dynamic>> past,
  required int total,
}) {
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
    return const ClientStatusBanner(
      tone: ClientBannerTone.info,
      title: 'No meetings scheduled yet',
      message:
          'Meetings will appear when recipients book time or when an interested reply enters handoff.',
    );
  }
  return const ClientStatusBanner(
    tone: ClientBannerTone.info,
    title: 'No upcoming meetings',
    message:
        'There are meeting records, but none are upcoming. Review past outcomes and watch replies for new handoffs.',
  );
}
