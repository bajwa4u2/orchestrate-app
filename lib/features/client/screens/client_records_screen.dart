import 'package:flutter/material.dart';

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
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Records are temporarily unavailable',
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

        // WHOSE RECORDS THESE ARE — WHICH THE PAGE NEVER SAID.
        //
        // Traced to the models rather than assumed: this reads
        // serviceAgreement, invoice, receipt, statement, reminder,
        // clientRepresentationAuth and importBatch. Every one of those is
        // between Orchestrate and this business.
        //
        // That matters because the product also holds CommercialAgreement and
        // CommercialInvoice, which are the business's OWN agreements and
        // invoices with its counterparties and live on the relationship. Two
        // sets of documents with the same nouns and opposite parties.
        //
        // "Everything issued to your business collects here — agreements,
        // invoices, receipts" could be read as either, and a business that
        // came here looking for what it had invoiced a counterparty would find
        // what Orchestrate had invoiced IT. The distinction is now stated
        // rather than left to be inferred from the contents.
        return ClientPage(
          eyebrow: 'Records',
          title: 'Your service record with Orchestrate',
          subtitle:
              'What Orchestrate agreed with this business, what it has charged, '
              'what authority the business granted it, and where imported data '
              'came from.',
          banner: const ClientStatusBanner(
            tone: ClientBannerTone.info,
            title: 'These are between the business and Orchestrate',
            message:
                'Agreements and invoices with your own counterparties are not '
                'here — those belong to the relationship they were made in. '
                'Nothing on this page can be changed from it.',
          ),
          children: [
            ClientPanel(
              title: 'What Orchestrate agreed to do',
              subtitle:
                  'The service relationship and the terms this business '
                  'accepted.',
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
              title: 'What Orchestrate has charged',
              // The counts live on the thing they count, rather than in a
              // strip of four numbers at the top of the page — none of which
              // was the subject of an action.
              subtitle:
                  'Charges, payments and account standing between this '
                  'business and Orchestrate.',
              children: [
                _RecordCountRow(label: 'Invoices', items: invoices),
                _RecordCountRow(label: 'Receipts', items: receipts),
                _RecordCountRow(label: 'Statements', items: statements),
                _RecordCountRow(label: 'Reminders', items: reminders),
              ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'What the business authorised Orchestrate to do',
              subtitle:
                  'Whether Orchestrate may represent this business in '
                  'outreach, who accepted that, and when.',
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
              title: 'Where the imported data came from',
              subtitle:
                  'The batches that produced the lead and contact inventory. '
                  'Provenance, so a contact can be traced to how it arrived.',
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
      // Nothing to say under an empty category. The note here explained the
      // absence of a View button by naming the endpoint that would have
      // provided it — three times down the page, under three headings that
      // had already said "No records visible."
      secondary: latest.isEmpty
          ? ''
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
