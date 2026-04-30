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
        final open = meetings
            .where((item) => readText(item, 'status') == 'PROPOSED')
            .toList();
        final booked = meetings
            .where((item) =>
                ['BOOKED', 'SCHEDULED'].contains(readText(item, 'status')))
            .toList();
        final past = meetings
            .where((item) => ['COMPLETED', 'CANCELED', 'NO_SHOW']
                .contains(readText(item, 'status')))
            .toList();

        return ClientPage(
          eyebrow: 'Meetings',
          title: meetings.isEmpty
              ? 'No meetings are on record yet'
              : '${meetings.length} meeting records',
          subtitle:
              'Meetings now load from the client meetings endpoint instead of being inferred from the reply list.',
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
              title: 'Open handoffs',
              empty:
                  'Interested replies awaiting handoff or booking will appear here.',
              items: open,
            ),
            const SizedBox(height: 18),
            _MeetingGroup(
              title: 'Booked meetings',
              empty: 'Booked meetings will appear after handoff is scheduled.',
              items: booked,
            ),
            const SizedBox(height: 18),
            _MeetingGroup(
              title: 'Past meetings',
              empty:
                  'Completed, canceled, and no-show meetings will appear here.',
              items: past,
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
  });

  final String title;
  final String empty;
  final List<Map<String, dynamic>> items;

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
                    titleCase(readText(item, 'status')),
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
