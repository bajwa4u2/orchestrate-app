import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'ops_empty_state.dart';
import 'ops_platform_repository.dart';

/// WHAT AUTHORITY EXISTS, AND WHY.
///
/// The work queue answers "what needs a person now", so a case leaves it the
/// moment it is decided — taking the record of the admission with it. Who may
/// sign for a business, on what evidence, admitted by whom, and what was
/// refused along the way had no surface at all.
///
/// This does not duplicate the queue. The queue is the doing; this is what the
/// doing produced, and it outlives it.
class OpsAuthorityScreen extends StatefulWidget {
  const OpsAuthorityScreen({super.key});

  @override
  State<OpsAuthorityScreen> createState() => _OpsAuthorityScreenState();
}

class _OpsAuthorityScreenState extends State<OpsAuthorityScreen> {
  final _repo = OpsPlatformRepository();

  List<Map<String, dynamic>> _businesses = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.authority();
      if (!mounted) return;
      setState(() {
        _businesses = ((data['businesses'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Authority',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 5),
                  const Text(
                    'Who each business has recognised, what established it, and what '
                    'that business has separately allowed Orchestrate to do.',
                    style: TextStyle(fontSize: 13, color: AppTheme.muted, height: 1.5),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.muted,
                side: const BorderSide(color: AppTheme.line),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_outlined, size: 34, color: AppTheme.amber),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
                child: const Text('Try again',
                    style: TextStyle(color: AppTheme.background)),
              ),
            ],
          ),
        ),
      );
    }
    if (_businesses.isEmpty) {
      return const OpsEmptyState(
        headline: 'No businesses to show.',
        detail: 'This reads across every organisation on the platform. If it is empty, '
            'there are no client businesses yet.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _businesses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _BusinessCard(business: _businesses[i]),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.business});

  final Map<String, dynamic> business;

  @override
  Widget build(BuildContext context) {
    final recognised = _list(business['recognised']);
    final submissions = _list(business['submissions']);
    final awaiting = (business['awaitingDecision'] as num?)?.toInt() ?? 0;
    final orchestrate = business['orchestrate'] is Map
        ? Map<String, dynamic>.from(business['orchestrate'] as Map)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${business['name'] ?? '—'}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              if (awaiting > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$awaiting awaiting a decision',
                    style: const TextStyle(fontSize: 11, color: AppTheme.amber),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Who the business recognises ───────────────────────────────
          const _Label('Recognised by this business'),
          const SizedBox(height: 6),
          if (recognised.isEmpty)
            const Text(
              'Nobody. Until someone is recognised, no agreement or payment '
              'decision can be made for this business.',
              style: TextStyle(fontSize: 12, color: AppTheme.subdued, height: 1.5),
            )
          else
            for (final person in recognised) _Person(person: person),

          const SizedBox(height: 18),

          // ── What Orchestrate itself may do, kept apart ────────────────
          //
          // Never merged into the list above. What a person may do for their
          // business and what they allowed Orchestrate to do have different
          // sources, and one table would read as one grant.
          const _Label('What this business has allowed Orchestrate to do'),
          const SizedBox(height: 6),
          if (orchestrate == null)
            const Text(
              'Nothing. Orchestrate has not been authorised to act for this business.',
              style: TextStyle(fontSize: 12, color: AppTheme.subdued, height: 1.5),
            )
          else
            _Delegation(grant: orchestrate),

          if (submissions.isNotEmpty) ...[
            const SizedBox(height: 18),
            _History(submissions: submissions),
          ],
        ],
      ),
    );
  }

  static List<Map<String, dynamic>> _list(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
      : const [];
}

class _Person extends StatelessWidget {
  const _Person({required this.person});

  final Map<String, dynamic> person;

  static const _areas = {
    'COMMUNICATION': 'Communication',
    'CONTRACTUAL': 'Agreements',
    'FINANCIAL': 'Invoices and payments',
  };

  @override
  Widget build(BuildContext context) {
    final holds = (person['holds'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final describedAs = (person['describedAs'] as String?)?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${person['name'] ?? '—'}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              if (describedAs != null && describedAs.isNotEmpty) ...[
                const SizedBox(width: 8),
                // A job title recorded beside permissions will be read as one
                // unless it says otherwise.
                Tooltip(
                  message: 'Recorded by the business. Carries no authority of its own.',
                  child: Text('“$describedAs”',
                      style: const TextStyle(fontSize: 11, color: AppTheme.subdued)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          for (final hold in holds)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4),
              child: Text(
                _describe(hold),
                style: const TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.45),
              ),
            ),
        ],
      ),
    );
  }

  /// The three permissions, as three sentences.
  ///
  /// `mayExercise` / `mayDelegate` / `maySubdelegate` collapsed into "yes" is
  /// how a person who may approve one invoice ends up appointing the next
  /// approver.
  String _describe(Map<String, dynamic> hold) {
    final area = _areas['${hold['area']}'] ?? '${hold['area']}';
    final can = <String>[
      if (hold['mayDecide'] == true) 'decide',
      if (hold['mayLetOrchestrateAct'] == true) 'let Orchestrate act',
      if (hold['mayRecogniseOthers'] == true) 'recognise other people',
    ];
    final established = hold['establishedBy'] is Map
        ? Map<String, dynamic>.from(hold['establishedBy'] as Map)
        : null;
    final source = established == null
        ? 'no evidence on record'
        : 'from ${established['artifactVersion'] ?? established['kind'] ?? 'the evidence submitted'}';
    return '$area — may ${can.isEmpty ? 'do nothing' : can.join(', ')} · $source';
  }
}

class _Delegation extends StatelessWidget {
  const _Delegation({required this.grant});

  final Map<String, dynamic> grant;

  @override
  Widget build(BuildContext context) {
    final areas = ((grant['mayActIn'] as List?) ?? const []).whereType<String>().toList();
    final note = (grant['note'] as String?)?.trim();
    final acceptedBy = (grant['acceptedBy'] as String?)?.trim();
    final acceptedAt = DateTime.tryParse('${grant['acceptedAt'] ?? ''}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          areas.isEmpty
              ? 'Nothing was named.'
              : areas.map(_area).join(', '),
          style: const TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.45),
        ),
        if (acceptedBy != null && acceptedBy.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Accepted by $acceptedBy'
            '${acceptedAt == null ? '' : ' on ${acceptedAt.toLocal().toString().split(' ').first}'}.',
            style: const TextStyle(fontSize: 12, color: AppTheme.subdued, height: 1.45),
          ),
        ],
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(note,
              style: const TextStyle(fontSize: 12, color: AppTheme.subdued, height: 1.5)),
        ],
      ],
    );
  }

  static String _area(String scope) {
    switch (scope) {
      case 'EXTERNAL_COMMUNICATION':
        return 'Communicate on the business’s behalf';
      case 'CONTRACTUAL':
        return 'Agree to things';
      case 'FINANCIAL':
        return 'Handle invoices and payments';
      default:
        return scope;
    }
  }
}

class _History extends StatelessWidget {
  const _History({required this.submissions});

  final List<Map<String, dynamic>> submissions;

  static const _states = {
    'SUBMITTED': 'Waiting for a decision',
    'MORE_EVIDENCE_REQUESTED': 'We asked for more',
    'ADMITTED': 'Admitted',
    'REFUSED': 'Refused',
    'SUPERSEDED': 'Replaced by a later submission',
  };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        iconColor: AppTheme.subdued,
        collapsedIconColor: AppTheme.subdued,
        title: Text(
          'Every submission (${submissions.length})',
          style: const TextStyle(
              fontSize: 11, color: AppTheme.subdued, letterSpacing: 0.4),
        ),
        children: [
          for (final s in submissions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s['person'] ?? '—'} · ${_states['${s['state']}'] ?? s['state']}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s['claimed'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.subdued, height: 1.4),
                  ),
                  // The outcomes nobody wants to look at are part of the record.
                  for (final line in [
                    if ((s['refusedBecause'] as String?)?.trim().isNotEmpty == true)
                      'Refused: ${s['refusedBecause']}',
                    if ((s['weAskedFor'] as String?)?.trim().isNotEmpty == true)
                      'We asked for: ${s['weAskedFor']}',
                    if ((s['supportedBy'] as String?)?.trim().isNotEmpty == true)
                      'Supported by: ${s['supportedBy']}',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(line,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.muted, height: 1.4)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          color: AppTheme.subdued,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      );
}
