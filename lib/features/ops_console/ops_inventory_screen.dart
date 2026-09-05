import 'package:flutter/material.dart';

import 'ops_platform_repository.dart';
import 'ops_platform_surface.dart';

/// IMPORTS THAT DID NOT LAND.
///
/// Orchestrate processes these, so when rows do not make it in, the business
/// cannot fix it from their side and often cannot see it. Counts and failure
/// state — which is what a support obligation needs.
///
/// The rows themselves are the business's own contact data and are not
/// reachable from here. An import failing is our problem; its contents are
/// still theirs.
class OpsInventoryScreen extends StatelessWidget {
  const OpsInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformSurface<Map<String, dynamic>>(
      title: 'Contacts & imports',
      describes: 'What businesses have brought in, and what did not make it.',
      load: OpsPlatformRepository().imports,
      rows: (data) {
        final rows = ((data['imports'] as List?) ?? const [])
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
        return '${rows.length} import${rows.length == 1 ? '' : 's'}'
            '${owed == 0 ? ', all landed cleanly.' : ' — $owed did not land cleanly.'}';
      },
      emptyHeadline: 'No imports on the platform yet.',
      build: (context, row) {
        final counts = row['rows'] is Map
            ? Map<String, dynamic>.from(row['rows'] as Map)
            : const <String, dynamic>{};
        int n(String key) => (counts[key] as num?)?.toInt() ?? 0;
        return PlatformRow(
          title: '${row['label'] ?? 'Import'}',
          subtitle: [
            '${row['clientName'] ?? row['organizationSlug'] ?? ''}',
            '${row['status'] ?? ''}'.toLowerCase(),
          ].where((s) => s.isNotEmpty).join(' · '),
          facts: [
            ('rows', '${n('total')}'),
            ('added', '${n('added')}'),
            ('duplicates', '${n('duplicates')}'),
            ('failed', '${n('failed')}'),
          ],
          owed: row['platformOwes'] as String?,
          attention: n('failed') > 0,
        );
      },
    );
  }
}
