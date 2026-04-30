import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

class ClientRecordsScreen extends StatefulWidget {
  const ClientRecordsScreen({super.key});

  @override
  State<ClientRecordsScreen> createState() => _ClientRecordsScreenState();
}

class _ClientRecordsScreenState extends State<ClientRecordsScreen> {
  final ClientPortalRepository _repository = ClientPortalRepository();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchRecords();
  }

  void _retry() {
    setState(() => _future = _repository.fetchRecords());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(label: 'Loading records');
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
        final billing = asMap(data['billingDocuments']);
        final agreements = asList(data['agreements']);
        final invoices = asList(billing['invoices']);
        final receipts = asList(billing['receipts']);
        final statements = asList(billing['statements']);
        final reminders = asList(billing['reminders']);
        final authorizations = asList(data['authorizations']);
        final imports = asList(asMap(data['sourceRecords'])['imports']);

        return ClientPage(
          eyebrow: 'Records',
          title: 'Service records and documents',
          subtitle:
              'Records are grouped into agreements, billing documents, authorization records, and real source/import records.',
          children: [
            ClientMetricStrip(metrics: [
              ClientMetric('Agreements', '${agreements.length}'),
              ClientMetric('Billing docs',
                  '${invoices.length + receipts.length + statements.length + reminders.length}'),
              ClientMetric('Authorizations', '${authorizations.length}'),
              ClientMetric('Imports', '${imports.length}'),
            ]),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Agreements',
              children: agreements.isEmpty
                  ? const [
                      ClientEmptyState(
                          message: 'No service agreements are visible yet.')
                    ]
                  : [
                      for (final item in agreements)
                        ClientInfoRow(
                          title: readText(asMap(item), 'title',
                              fallback: readText(asMap(item), 'agreementNumber',
                                  fallback: 'Agreement')),
                          primary:
                              'Status: ${titleCase(readText(asMap(item), 'status'))}',
                          secondary: [
                            readText(asMap(item), 'agreementNumber'),
                            dateLabel(asMap(item)['acceptedAt'] ??
                                asMap(item)['createdAt']),
                          ].where((part) => part.isNotEmpty).join(' · '),
                        ),
                    ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Billing documents',
              children: [
                _RecordCountRow(label: 'Invoices', items: invoices),
                _RecordCountRow(label: 'Receipts', items: receipts),
                _RecordCountRow(label: 'Statements', items: statements),
                _RecordCountRow(label: 'Reminders', items: reminders),
              ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Authorization records',
              children: authorizations.isEmpty
                  ? const [
                      ClientEmptyState(
                          message:
                              'Representation authorization has not been recorded yet.')
                    ]
                  : [
                      for (final item in authorizations)
                        ClientInfoRow(
                          title:
                              'Representation authorization v${asMap(item)['version'] ?? ''}',
                          primary: [
                            readText(asMap(item), 'acceptedByName'),
                            readText(asMap(item), 'acceptedByEmail'),
                          ].where((part) => part.isNotEmpty).join(' · '),
                          secondary: dateLabel(asMap(item)['acceptedAt']),
                        ),
                    ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Source and import records',
              children: imports.isEmpty
                  ? const [
                      ClientEmptyState(
                          message:
                              'No source/import batches are visible for this account yet.')
                    ]
                  : [
                      for (final item in imports)
                        ClientInfoRow(
                          title: readText(asMap(item), 'sourceLabel',
                              fallback: 'Import batch'),
                          primary:
                              'Status: ${titleCase(readText(asMap(item), 'status'))}',
                          secondary:
                              'Rows: ${asMap(item)['totalRows'] ?? 0} · Created: ${asMap(item)['createdRows'] ?? 0} · Invalid: ${asMap(item)['invalidRows'] ?? 0}',
                        ),
                    ],
            ),
          ],
        );
      },
    );
  }
}

class _RecordCountRow extends StatelessWidget {
  const _RecordCountRow({required this.label, required this.items});

  final String label;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    final latest =
        items.isEmpty ? const <String, dynamic>{} : asMap(items.first);
    return ClientInfoRow(
      title: label,
      primary:
          items.isEmpty ? 'No records visible.' : '${items.length} records',
      secondary: latest.isEmpty
          ? 'View/download actions are hidden because no client document render endpoint is exposed for this category.'
          : [
              readText(latest, 'invoiceNumber',
                  fallback: readText(latest, 'receiptNumber',
                      fallback: readText(latest, 'statementNumber',
                          fallback: readText(latest, 'subjectLine')))),
              dateLabel(latest['issuedAt'] ??
                  latest['scheduledAt'] ??
                  latest['createdAt']),
            ].where((part) => part.isNotEmpty).join(' · '),
    );
  }
}
