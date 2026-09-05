import 'package:flutter/material.dart';

import 'ops_platform_repository.dart';
import 'ops_platform_surface.dart';

/// CAMPAIGNS ORCHESTRATE OWES THE DELIVERY OF.
///
/// Execution state, never the campaign's content. "This has been held for nine
/// days and nothing will send" is ours to answer; what it says is the
/// business's to write, and this surface cannot read it.
class OpsCampaignsScreen extends StatelessWidget {
  const OpsCampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformSurface<Map<String, dynamic>>(
      title: 'Campaigns',
      describes: 'What is running, what is held, and what failed on our side.',
      load: OpsPlatformRepository().campaigns,
      rows: (data) {
        final rows = ((data['campaigns'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        rows.sort((a, b) {
          final ao = (a['platformOwes'] as String?)?.isNotEmpty == true ? 0 : 1;
          final bo = (b['platformOwes'] as String?)?.isNotEmpty == true ? 0 : 1;
          return ao.compareTo(bo);
        });
        return rows;
      },
      summarise: (rows) {
        final owed =
            rows.where((r) => (r['platformOwes'] as String?)?.isNotEmpty == true).length;
        return '${rows.length} campaign${rows.length == 1 ? '' : 's'}'
            '${owed == 0 ? ', nothing waiting on us.' : ' — $owed waiting on us.'}';
      },
      emptyHeadline: 'No campaigns on the platform yet.',
      build: (context, row) {
        final held = (row['heldSince'] as String?)?.isNotEmpty == true;
        return PlatformRow(
          title: '${row['name'] ?? '—'}',
          subtitle: [
            '${row['clientName'] ?? row['organizationSlug'] ?? ''}',
            '${row['status'] ?? ''}'.toLowerCase(),
            if (held) 'held',
          ].where((s) => s.isNotEmpty).join(' · '),
          facts: [
            ('sent', '${(row['sent'] as num?)?.toInt() ?? 0}'),
            ('bounced', '${(row['bounced'] as num?)?.toInt() ?? 0}'),
            ('failed', '${(row['failed'] as num?)?.toInt() ?? 0}'),
          ],
          owed: row['platformOwes'] as String?,
          attention: held || ((row['failed'] as num?)?.toInt() ?? 0) > 0,
        );
      },
    );
  }
}
