import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'ops_platform_repository.dart';
import 'ops_platform_surface.dart';

/// CAN WHAT THESE BUSINESSES SEND ACTUALLY GET OUT.
///
/// Mailboxes are connected through Orchestrate and domains are verified by it,
/// so when either stops working the platform is the only party that can see it.
/// This screen used to read the operator's own organisation and report
/// "0 mailboxes · 0 domains" while ten mailboxes and four domains were live.
///
/// Connection and verification state only. There is no message on this surface
/// and no way to ask it for one.
class OpsTransportScreen extends StatelessWidget {
  const OpsTransportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformSurface<Map<String, dynamic>>(
      title: 'Transport',
      describes: 'Whether these businesses can get mail out.',
      load: OpsPlatformRepository().transport,
      rows: (data) {
        final mailboxes = _rows(data['mailboxes']).map((m) => {...m, '_kind': 'mailbox'});
        final domains = _rows(data['domains']).map((m) => {...m, '_kind': 'domain'});
        // Anything the platform owes first: this is a work surface, and a list
        // ordered by creation date buries the one row that needs somebody.
        final all = [...mailboxes, ...domains].toList();
        all.sort((a, b) {
          final ao = (a['platformOwes'] as String?)?.isNotEmpty == true ? 0 : 1;
          final bo = (b['platformOwes'] as String?)?.isNotEmpty == true ? 0 : 1;
          return ao.compareTo(bo);
        });
        return all;
      },
      summarise: (rows) {
        final owed = rows.where((r) => (r['platformOwes'] as String?)?.isNotEmpty == true).length;
        final mailboxes = rows.where((r) => r['_kind'] == 'mailbox').length;
        final domains = rows.length - mailboxes;
        return '$mailboxes mailbox${mailboxes == 1 ? '' : 'es'}, '
            '$domains domain${domains == 1 ? '' : 's'}'
            '${owed == 0 ? '. Nothing needs us.' : ' — $owed need${owed == 1 ? 's' : ''} us.'}';
      },
      emptyHeadline: 'No mailboxes or domains on the platform.',
      build: (context, row) => row['_kind'] == 'mailbox'
          ? _MailboxRow(mailbox: row)
          : _DomainRow(domain: row),
    );
  }

  static List<Map<String, dynamic>> _rows(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
      : const [];
}

class _MailboxRow extends StatelessWidget {
  const _MailboxRow({required this.mailbox});
  final Map<String, dynamic> mailbox;

  @override
  Widget build(BuildContext context) {
    final observing = DateTime.tryParse('${mailbox['observingSince'] ?? ''}');
    return PlatformRow(
      title: '${mailbox['address'] ?? '—'}',
      subtitle: [
        '${mailbox['clientName'] ?? mailbox['organizationSlug'] ?? ''}',
        _words('${mailbox['connection'] ?? ''}'),
        _words('${mailbox['health'] ?? ''}'),
        // "We do not read your history" as a fact on the row rather than a
        // claim in a policy document.
        if (observing != null)
          'observing since ${observing.toLocal().toString().split(' ').first}',
      ].where((s) => s.isNotEmpty).join(' · '),
      owed: mailbox['platformOwes'] as String?,
      attention: mailbox['needsReconnect'] == true,
    );
  }
}

class _DomainRow extends StatelessWidget {
  const _DomainRow({required this.domain});
  final Map<String, dynamic> domain;

  @override
  Widget build(BuildContext context) {
    final failed = (domain['failedReason'] as String?)?.trim();
    return PlatformRow(
      title: '${domain['domain'] ?? '—'}',
      subtitle: [
        // The business, as the mailbox rows do. The organisation slug is an
        // internal handle and reads as one beside a row that says "Northgate
        // Mechanical".
        '${domain['clientName'] ?? domain['organizationSlug'] ?? ''}',
        _words('${domain['status'] ?? ''}'),
        if (failed != null && failed.isNotEmpty) failed,
      ].where((s) => s.isNotEmpty).join(' · '),
      owed: domain['platformOwes'] as String?,
      attention: (domain['platformOwes'] as String?)?.isNotEmpty == true,
    );
  }
}

/// REQUIRES_REAUTH is a database value. "Requires reauth" is a person's.
String _words(String value) {
  if (value.isEmpty) return '';
  if (!RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(value)) return value;
  final parts = value.split('_').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return value;
  return [
    parts.first[0] + parts.first.substring(1).toLowerCase(),
    ...parts.skip(1).map((p) => p.toLowerCase()),
  ].join(' ');
}
