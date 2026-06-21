import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';
import 'package:orchestrate_app/features/client/widgets/sequence_step_author.dart';
import 'package:orchestrate_app/features/system/widgets/governance_primitives.dart';

/// Sequence authoring screen.
///
/// Lists existing steps for the supplied sequenceId and mounts the
/// SequenceStepAuthor at the bottom so an operator/client can add a
/// new step. Edits land via PATCH; soft-delete via DELETE; create
/// via POST. The screen does not invent governance semantics — each
/// row's body source and template provenance are read directly from
/// the persisted step shape.
class ClientSequenceAuthorScreen extends StatefulWidget {
  const ClientSequenceAuthorScreen({super.key, required this.sequenceId});

  final String sequenceId;

  @override
  State<ClientSequenceAuthorScreen> createState() =>
      _ClientSequenceAuthorScreenState();
}

class _ClientSequenceAuthorScreenState
    extends State<ClientSequenceAuthorScreen> {
  final ClientPortalRepository _repository = ClientPortalRepository();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchSequence(widget.sequenceId);
  }

  void _reload() {
    setState(() {
      _future = _repository.fetchSequence(widget.sequenceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(
            eyebrow: 'Sequence authoring',
            label: 'Loading sequence',
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Sequence is temporarily unavailable',
            onRetry: _reload,
          );
        }
        final sequence = snapshot.data!;
        final steps = (sequence['steps'] as List? ?? const []).cast<dynamic>();
        return ClientPage(
          eyebrow: 'Sequence authoring',
          title: sequence['name']?.toString() ?? 'Sequence',
          subtitle:
              'Each step carries an explicit governance posture: governed template (template provenance stamped on the wire), legacy custom body (no template provenance claimed), or bounded AI (preview). The dispatch path reads the same posture you see here.',
          children: [
            _SequenceMetrics(sequence: sequence, steps: steps),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Existing steps',
              children: steps.isEmpty
                  ? const [
                      ClientEmptyState(
                        message:
                            'This sequence has no steps yet. Add one below.',
                      ),
                    ]
                  : [
                      for (final raw in steps) _StepRow(step: _asMap(raw)),
                    ],
            ),
            const SizedBox(height: 18),
            SequenceStepAuthor(
              sequenceId: widget.sequenceId,
              repository: _repository,
              onSaved: (_) => _reload(),
            ),
          ],
        );
      },
    );
  }
}

class _SequenceMetrics extends StatelessWidget {
  const _SequenceMetrics({required this.sequence, required this.steps});

  final Map<String, dynamic> sequence;
  final List<dynamic> steps;

  @override
  Widget build(BuildContext context) {
    int governed = 0;
    int legacy = 0;
    int nonEmail = 0;
    for (final raw in steps) {
      final step = _asMap(raw);
      final mode = step['mode']?.toString();
      if (mode == 'governed') {
        governed += 1;
      } else if (mode == 'legacy') {
        legacy += 1;
      } else if (mode == 'non_email') {
        nonEmail += 1;
      }
    }
    return ClientMetricStrip(metrics: [
      ClientMetric('Steps', steps.length.toString()),
      ClientMetric('Governed', governed.toString()),
      ClientMetric('Legacy', legacy.toString()),
      ClientMetric('Status', (sequence['status'] ?? 'DRAFT').toString()),
    ]);
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final Map<String, dynamic> step;

  @override
  Widget build(BuildContext context) {
    final order = step['orderIndex']?.toString() ?? '?';
    final type = step['type']?.toString() ?? 'EMAIL';
    final status = step['status']?.toString() ?? '';
    final templateKey = step['templateKey']?.toString();
    final mode = step['mode']?.toString() ?? 'unknown';
    final subject = (step['subjectTemplate'] ?? '').toString();
    final waitDays = step['waitDays']?.toString();
    final bodySource = mode == 'governed'
        ? 'catalog'
        : mode == 'legacy'
            ? 'sequence_legacy'
            : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '#$order',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: AppTheme.publicMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subject.isNotEmpty
                      ? subject
                      : (templateKey ?? '(no subject, non-email step)'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.publicText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                GovernanceBadge(label: 'type', value: type),
                if (status.isNotEmpty)
                  GovernanceBadge(label: 'status', value: status),
                if (waitDays != null && waitDays != 'null' && waitDays.isNotEmpty)
                  GovernanceBadge(label: 'wait', value: '${waitDays}d'),
                BodySourcePill(
                    bodySource: bodySource, templateKey: templateKey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry('$k', val));
  return const <String, dynamic>{};
}
