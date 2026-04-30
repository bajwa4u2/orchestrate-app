import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

class ClientNotificationsScreen extends StatefulWidget {
  const ClientNotificationsScreen({super.key});

  @override
  State<ClientNotificationsScreen> createState() =>
      _ClientNotificationsScreenState();
}

class _ClientNotificationsScreenState extends State<ClientNotificationsScreen> {
  final ClientPortalRepository _repository = ClientPortalRepository();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchNotifications();
  }

  void _retry() {
    setState(() => _future = _repository.fetchNotifications());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(label: 'Loading notifications');
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return ClientErrorView(
            message:
                error is ApiException ? error.displayMessage : error.toString(),
            onRetry: _retry,
          );
        }

        final notifications =
            (snapshot.data ?? const <dynamic>[]).map(asMap).toList();
        final open = notifications
            .where((item) => readText(item, 'status') == 'OPEN')
            .length;
        final resolved = notifications
            .where((item) => readText(item, 'status') == 'RESOLVED')
            .length;

        return ClientPage(
          eyebrow: 'Notifications',
          title: notifications.isEmpty
              ? 'No notifications are visible yet'
              : '${notifications.length} account notifications',
          subtitle:
              'Notification history is backed by client-visible alert records. Preferences are not configurable because no preference persistence contract exists yet.',
          children: [
            ClientMetricStrip(metrics: [
              ClientMetric('Total', '${notifications.length}'),
              ClientMetric('Open', '$open'),
              ClientMetric('Resolved', '$resolved'),
              ClientMetric('Preferences', 'Not configurable'),
            ]),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Notification history',
              children: notifications.isEmpty
                  ? const [
                      ClientEmptyState(
                          message:
                              'Account notices, service alerts, and billing notifications will appear here when created for this client.')
                    ]
                  : [
                      for (final item in notifications)
                        ClientInfoRow(
                          title:
                              readText(item, 'title', fallback: 'Notification'),
                          primary: [
                            titleCase(readText(item, 'severity')),
                            titleCase(readText(item, 'category')),
                            titleCase(readText(item, 'status')),
                          ].where((part) => part.isNotEmpty).join(' · '),
                          secondary: [
                            readText(item, 'bodyText'),
                            dateLabel(item['createdAt']),
                          ].where((part) => part.isNotEmpty).join(' · '),
                        ),
                    ],
            ),
            const SizedBox(height: 18),
            const ClientPanel(
              title: 'Preferences',
              children: [
                ClientEmptyState(
                    message:
                        'Notification preferences are not configurable yet. No unsaved toggles are shown on this workspace.')
              ],
            ),
          ],
        );
      },
    );
  }
}
