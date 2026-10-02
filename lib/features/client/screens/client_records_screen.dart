import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/core/ui/ob_widgets.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart'
    show asList, asMap, readText;

/// YOUR RECORD WITH ORCHESTRATE (DD-34/35).
///
/// What is between this business and Orchestrate itself: the service
/// agreement, what Orchestrate has charged, the permission the business gave
/// it, and lists the business brought in. Never the business's own invoices
/// to its customers; those live in Money. Read-only: nothing here is changed
/// from this page. In the design Setup, Support and Account use.
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

  void _retry() => setState(() => _future = _repository.fetchRecords());

  @override
  Widget build(BuildContext context) {
    final phone = Workspace.sizeOf(context, MediaQuery.sizeOf(context).width).isPhone;
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Ob.inkMuted),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Plan & billing'),
            onPressed: () => context.go('/account/plan'),
          ),
        ),
        const SizedBox(height: 6),
        ObHeadline('Your record with Orchestrate', size: phone ? 28 : 38),
        const SizedBox(height: 6),
        Text(
            'What Orchestrate agreed with your business, what it has charged, and '
            'the permission your business gave it. Your own invoices to your '
            'customers are in Money.',
            style: Ob.body(16, color: Ob.inkSoft)),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Text('Reading your record…', style: Ob.body(14.5, color: Ob.inkMuted));
                }
                if (snapshot.hasError) {
                  return Row(children: [
                    Expanded(
                      child: Text('Your record could not be read just now.',
                          style: Ob.body(14.5, color: Ob.inkMuted)),
                    ),
                    TextButton(onPressed: _retry, child: const Text('Try again')),
                  ]);
                }
                return _body(snapshot.data ?? const {});
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _body(Map<String, dynamic> data) {
    final billing = asMap(data['billingDocuments']);
    final agreements = asList(data['agreements']).map(asMap).toList();
    final authorizations = asList(data['authorizations']).map(asMap).toList();
    final imports = asList(asMap(data['sourceRecords'])['imports']).map(asMap).toList();
    final charged = <(String, List<Map<String, dynamic>>)>[
      ('Invoices', asList(billing['invoices']).map(asMap).toList()),
      ('Receipts', asList(billing['receipts']).map(asMap).toList()),
      ('Statements', asList(billing['statements']).map(asMap).toList()),
      ('Reminders', asList(billing['reminders']).map(asMap).toList()),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Group(
        title: 'What Orchestrate agreed to do',
        empty: 'No service agreement yet. It appears here when your plan starts.',
        rows: [
          for (final a in agreements)
            _Line(
              title: readText(a, 'title', fallback: readText(a, 'agreementNumber', fallback: 'Service agreement')),
              detail: [
                _status(readText(a, 'status')),
                readText(a, 'agreementNumber'),
                _when(a['acceptedAt'] ?? a['createdAt']),
              ].where((s) => s.isNotEmpty).join(' · '),
            ),
        ],
      ),
      _Group(
        title: 'What Orchestrate has charged',
        empty: '',
        rows: [
          for (final (label, items) in charged)
            _Line(
              title: label,
              detail: items.isEmpty
                  ? 'None yet'
                  : [
                      items.length == 1 ? 'One' : '${items.length}',
                      'latest ${readText(items.first, 'invoiceNumber', fallback: readText(items.first, 'receiptNumber', fallback: readText(items.first, 'statementNumber', fallback: readText(items.first, 'subjectLine'))))}'
                          .trim(),
                      _when(items.first['issuedAt'] ?? items.first['scheduledAt'] ?? items.first['createdAt']),
                    ].where((s) => s.isNotEmpty && s != 'latest').join(' · '),
            ),
        ],
      ),
      _Group(
        title: 'The permission your business gave Orchestrate',
        empty: 'Not given yet. It is recorded when someone confirms they act for the business, in Setup.',
        rows: [
          for (final a in authorizations)
            _Line(
              title: 'Permission to write in the business\'s name',
              detail: [
                readText(a, 'acceptedByName'),
                readText(a, 'acceptedByEmail'),
                _when(a['acceptedAt']),
                if ((a['version'] ?? '').toString().isNotEmpty) 'version ${a['version']}',
              ].where((s) => s.isNotEmpty).join(' · '),
            ),
        ],
      ),
      if (imports.isNotEmpty)
        _Group(
          title: 'Lists you brought in',
          empty: '',
          rows: [
            for (final i in imports)
              _Line(
                title: readText(i, 'sourceLabel', fallback: 'A list'),
                detail: [
                  _status(readText(i, 'status')),
                  '${i['totalRows'] ?? 0} rows',
                  '${i['createdRows'] ?? 0} added',
                  if ((i['invalidRows'] ?? 0) != 0) '${i['invalidRows']} could not be read',
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
          ],
        ),
    ]);
  }
}

String _status(String raw) {
  final s = raw.trim().toLowerCase().replaceAll('_', ' ');
  return s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}';
}

/// "2 Oct 2026 · 12:56 PM". Always with the time.
String _when(dynamic value) {
  final at = DateTime.tryParse('${value ?? ''}')?.toLocal();
  if (at == null) return '';
  final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${at.day} ${months[at.month - 1]} ${at.year} · $h:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'AM' : 'PM'}';
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows, required this.empty});
  final String title;
  final List<Widget> rows;
  final String empty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title.toUpperCase(), style: Ob.eyebrow()),
        const SizedBox(height: 10),
        ObCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(empty, style: Ob.body(14.5, color: Ob.inkMuted)),
              ),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Ob.line),
              rows[i],
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.title, required this.detail});
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Ob.strong(15)),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(detail, style: Ob.body(14, color: Ob.inkSoft)),
        ],
      ]),
    );
  }
}
