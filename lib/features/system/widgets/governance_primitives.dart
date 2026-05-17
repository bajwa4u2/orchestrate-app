import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/system/widgets/trust_primitives.dart';

/// Calm, infrastructural visual primitives for the governed
/// communication system. Used by client + operator governance
/// surfaces.
///
/// Doctrine
/// --------
/// These widgets describe operational truth, not marketing posture.
/// They are deliberately small, restrained, and audit-friendly — no
/// flashy badges, no growth-SaaS colour explosions, no developer-
/// terminal aesthetic. Every primitive answers one question.
///
/// Reusable primitives shipped here:
///
///   - [GovernanceBadge]            – named lifecycle / lane / status
///                                    chip with optional accent tone.
///   - [BodySourcePill]             – names the dispatch body source:
///                                    catalog / governed-fallback /
///                                    legacy / AI / unknown.
///   - [BoundedAIIndicator]         – pill that names whether AI
///                                    involvement (if any) operated
///                                    inside or outside governance.
///   - [ProvenanceChainStrip]       – horizontal Op-Id → Thread-Id →
///                                    Template summary, monospace,
///                                    selectable. Compact audit view.
///   - [DispatchAttemptTrack]       – tiny "attempt N of M" indicator.
///   - [RecoveryStatePill]          – names degradation / recovery
///                                    when present, neutral otherwise.
///   - [GovernanceCoverageMeter]    – proportional bar of governed vs
///                                    non-governed body sources across
///                                    a recent batch.
///
/// Composition principle
/// ---------------------
/// Each primitive is a single Container/Row/Wrap. No primitive owns
/// data fetching. Callers pass already-resolved strings / counts /
/// flags. This keeps the primitives reusable across client and
/// operator workspaces.

// ---------------------------------------------------------------------
// Tones
// ---------------------------------------------------------------------

enum GovernanceTone {
  /// Healthy / fully governed.
  positive,

  /// Informational / neutral default.
  neutral,

  /// Soft warning / partial governance / something to know.
  cautious,

  /// Hard warning / action required / governance gap.
  critical,
}

class _ToneSpec {
  const _ToneSpec({
    required this.background,
    required this.foreground,
    required this.border,
  });
  final Color background;
  final Color foreground;
  final Color border;
}

_ToneSpec _toneSpec(GovernanceTone tone) {
  switch (tone) {
    case GovernanceTone.positive:
      return const _ToneSpec(
        background: Color(0xFFEFF6FF),
        foreground: Color(0xFF1D4ED8),
        border: AppTheme.publicLine,
      );
    case GovernanceTone.neutral:
      return const _ToneSpec(
        background: AppTheme.publicSurfaceSoft,
        foreground: AppTheme.publicMuted,
        border: AppTheme.publicLine,
      );
    case GovernanceTone.cautious:
      return const _ToneSpec(
        background: Color(0xFFFEF6E0),
        foreground: Color(0xFF92400E),
        border: AppTheme.publicLine,
      );
    case GovernanceTone.critical:
      return const _ToneSpec(
        background: Color(0xFFFEECEC),
        foreground: Color(0xFFB1361B),
        border: AppTheme.publicLine,
      );
  }
}

// ---------------------------------------------------------------------
// GovernanceBadge — generic labeled chip.
// ---------------------------------------------------------------------

class GovernanceBadge extends StatelessWidget {
  const GovernanceBadge({
    super.key,
    required this.label,
    this.value,
    this.tone = GovernanceTone.neutral,
    this.monospace = false,
  });

  /// Short label, e.g. "lane".
  final String label;

  /// Optional value rendered after a colon, e.g. "opportunity".
  /// When omitted, only the label appears (useful for "signature applied").
  final String? value;

  final GovernanceTone tone;

  /// Render the value portion in a monospace font (useful for IDs).
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final spec = _toneSpec(tone);
    final hasValue = value != null && value!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: spec.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: spec.border),
      ),
      child: hasValue
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$label: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: spec.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  value!,
                  style: TextStyle(
                    color: spec.foreground,
                    fontWeight: FontWeight.w700,
                    fontFamily: monospace ? 'monospace' : null,
                    fontSize: monospace ? 12.5 : 12.5,
                  ),
                ),
              ],
            )
          : Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: spec.foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
    );
  }
}

// ---------------------------------------------------------------------
// BodySourcePill — primary dispatch-body provenance summary.
// ---------------------------------------------------------------------

class BodySourcePill extends StatelessWidget {
  const BodySourcePill({super.key, required this.bodySource, this.templateKey});

  /// Canonical bodySource enum from OutreachMessage.metadataJson:
  /// 'catalog' | 'ai_fallback_catalog' | 'sequence_legacy' | 'ai_draft' | null
  final String? bodySource;

  /// Template key used (if any). When set + bodySource is governed,
  /// the pill emphasizes the governed claim.
  final String? templateKey;

  @override
  Widget build(BuildContext context) {
    final usingGoverned = (templateKey ?? '').isNotEmpty;
    final spec = _toneSpec(
      usingGoverned ? GovernanceTone.positive : GovernanceTone.neutral,
    );
    final label = _label();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: spec.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: spec.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: spec.foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  String _label() {
    switch (bodySource) {
      case 'catalog':
        return 'governed template';
      case 'ai_fallback_catalog':
        return 'governed fallback';
      case 'sequence_legacy':
        return 'legacy sequence body';
      case 'ai_draft':
        return 'AI body (no template claim)';
      default:
        return 'body source: unknown';
    }
  }
}

// ---------------------------------------------------------------------
// BoundedAIIndicator — names AI involvement vs. governance boundary.
// ---------------------------------------------------------------------

class BoundedAIIndicator extends StatelessWidget {
  const BoundedAIIndicator({super.key, required this.bodySource});

  final String? bodySource;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = _state();
    return GovernanceBadge(label: label, tone: tone);
  }

  (String, GovernanceTone) _state() {
    switch (bodySource) {
      case 'catalog':
        return ('AI not involved', GovernanceTone.positive);
      case 'ai_fallback_catalog':
        return ('AI fell back to catalog', GovernanceTone.cautious);
      case 'ai_draft':
        return ('AI freeform (ungoverned)', GovernanceTone.cautious);
      case 'sequence_legacy':
        return ('Operator-authored body', GovernanceTone.neutral);
      default:
        return ('AI involvement unknown', GovernanceTone.neutral);
    }
  }
}

// ---------------------------------------------------------------------
// ProvenanceChainStrip — selectable monospace summary of identifiers.
// ---------------------------------------------------------------------

class ProvenanceChainStrip extends StatelessWidget {
  const ProvenanceChainStrip({
    super.key,
    this.operationId,
    this.threadId,
    this.templateKey,
    this.templateVersion,
  });

  final String? operationId;
  final String? threadId;
  final String? templateKey;
  final int? templateVersion;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    if ((operationId ?? '').isNotEmpty) {
      parts.add(_field('op', operationId!));
    }
    if ((threadId ?? '').isNotEmpty) {
      parts.add(_field('thread', threadId!));
    }
    if ((templateKey ?? '').isNotEmpty) {
      parts.add(_field(
        'template',
        templateVersion != null ? '$templateKey · v$templateVersion' : templateKey!,
      ));
    }
    if (parts.isEmpty) {
      return Text(
        'No provenance recorded.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.publicMuted,
            ),
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: parts,
    );
  }

  Widget _field(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.publicMuted,
          ),
        ),
        SelectableText(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppTheme.publicText,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// DispatchAttemptTrack — "attempt 2" pill.
// ---------------------------------------------------------------------

class DispatchAttemptTrack extends StatelessWidget {
  const DispatchAttemptTrack({super.key, required this.attempt});

  final int? attempt;

  @override
  Widget build(BuildContext context) {
    if (attempt == null) return const SizedBox.shrink();
    return GovernanceBadge(
      label: 'attempt',
      value: attempt!.toString(),
      tone:
          attempt! > 2 ? GovernanceTone.cautious : GovernanceTone.neutral,
    );
  }
}

// ---------------------------------------------------------------------
// RecoveryStatePill — surfaces degradation / recovery on a row when set.
// ---------------------------------------------------------------------

class RecoveryStatePill extends StatelessWidget {
  const RecoveryStatePill({super.key, this.state});

  /// One of: 'ok' | 'recovering' | 'degraded' | 'failed' | null.
  final String? state;

  @override
  Widget build(BuildContext context) {
    final s = (state ?? '').toLowerCase();
    if (s.isEmpty || s == 'ok' || s == 'sent' || s == 'delivered') {
      return const SizedBox.shrink();
    }
    GovernanceTone tone;
    String label;
    switch (s) {
      case 'recovering':
        tone = GovernanceTone.cautious;
        label = 'recovering';
        break;
      case 'degraded':
        tone = GovernanceTone.cautious;
        label = 'degraded';
        break;
      case 'failed':
      case 'retryable_failed':
        tone = GovernanceTone.critical;
        label = 'failed';
        break;
      default:
        tone = GovernanceTone.neutral;
        label = s;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: PulsingDot(
            color: tone == GovernanceTone.critical
                ? const Color(0xFFB1361B)
                : const Color(0xFFB45309),
            size: 6,
            pulse: tone != GovernanceTone.neutral,
          ),
        ),
        GovernanceBadge(label: label, tone: tone),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// GovernanceCoverageMeter — proportional bar across a row sample.
// ---------------------------------------------------------------------

class GovernanceCoverageMeter extends StatelessWidget {
  const GovernanceCoverageMeter({
    super.key,
    required this.governedCount,
    required this.fallbackCount,
    required this.legacyCount,
    required this.aiFreeformCount,
  });

  final int governedCount;
  final int fallbackCount;
  final int legacyCount;
  final int aiFreeformCount;

  @override
  Widget build(BuildContext context) {
    final total =
        governedCount + fallbackCount + legacyCount + aiFreeformCount;
    if (total == 0) {
      return Text(
        'No dispatches in sample.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.publicMuted,
            ),
      );
    }

    Color governedColor = const Color(0xFF1D4ED8);
    Color fallbackColor = const Color(0xFF7C3AED);
    Color legacyColor = const Color(0xFF6B7280);
    Color aiColor = const Color(0xFFB45309);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 8,
          child: Row(
            children: [
              if (governedCount > 0)
                Expanded(flex: governedCount, child: Container(color: governedColor)),
              if (fallbackCount > 0)
                Expanded(flex: fallbackCount, child: Container(color: fallbackColor)),
              if (legacyCount > 0)
                Expanded(flex: legacyCount, child: Container(color: legacyColor)),
              if (aiFreeformCount > 0)
                Expanded(flex: aiFreeformCount, child: Container(color: aiColor)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            _legend(context, governedColor,
                'governed', governedCount, total),
            _legend(context, fallbackColor,
                'fallback', fallbackCount, total),
            _legend(context, legacyColor,
                'legacy', legacyCount, total),
            _legend(context, aiColor,
                'AI freeform', aiFreeformCount, total),
          ],
        ),
      ],
    );
  }

  Widget _legend(
    BuildContext context,
    Color color,
    String label,
    int count,
    int total,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 5),
        Text(
          '$label · $count / $total',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.publicMuted,
              ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// LifecycleTimeline — vertical timeline of operation stages.
// ---------------------------------------------------------------------

/// One row in a lifecycle timeline. `state` controls the dot tone:
///   'done' (positive)  'pending' (neutral)  'attention' (cautious)
///   'failed' (critical)  'missing' (neutral, dim)
class LifecycleStep {
  const LifecycleStep({
    required this.label,
    required this.state,
    this.detail,
    this.timestamp,
  });
  final String label;
  final String state;
  final String? detail;
  final String? timestamp;
}

class LifecycleTimeline extends StatelessWidget {
  const LifecycleTimeline({super.key, required this.steps});

  final List<LifecycleStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return Text(
        'No lifecycle events recorded.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.publicMuted,
            ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _LifecycleStepRow(
            step: steps[i],
            isFirst: i == 0,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _LifecycleStepRow extends StatelessWidget {
  const _LifecycleStepRow({
    required this.step,
    required this.isFirst,
    required this.isLast,
  });
  final LifecycleStep step;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = _dotColor(step.state);
    final dim = step.state == 'missing' || step.state == 'pending';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rail + dot.
          Column(
            children: [
              Container(
                width: 2,
                height: 8,
                color: isFirst ? Colors.transparent : AppTheme.publicLine,
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: AppTheme.publicLine),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast ? Colors.transparent : AppTheme.publicLine,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: dim ? AppTheme.publicMuted : AppTheme.publicText,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (step.timestamp != null && step.timestamp!.isNotEmpty)
                    Text(
                      step.timestamp!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.publicMuted,
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                          ),
                    ),
                  if (step.detail != null && step.detail!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        step.detail!,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.publicMuted,
                                  height: 1.4,
                                ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _dotColor(String state) {
    switch (state) {
      case 'done':
        return const Color(0xFF1D4ED8);
      case 'attention':
        return const Color(0xFFB45309);
      case 'failed':
        return const Color(0xFFB1361B);
      case 'missing':
        return const Color(0xFFD1D5DB);
      case 'pending':
      default:
        return const Color(0xFF9CA3AF);
    }
  }
}

// ---------------------------------------------------------------------
// OperationContinuityRail — compact horizontal continuity track.
// ---------------------------------------------------------------------

class OperationContinuityRail extends StatelessWidget {
  const OperationContinuityRail({
    super.key,
    required this.markers,
  });

  /// Each marker is (label, state). State accepts the same values as
  /// LifecycleStep.state.
  final List<({String label, String state})> markers;

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 26,
      child: Row(
        children: [
          for (var i = 0; i < markers.length; i++) ...[
            _RailMarker(label: markers[i].label, state: markers[i].state),
            if (i != markers.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: AppTheme.publicLine,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RailMarker extends StatelessWidget {
  const _RailMarker({required this.label, required this.state});
  final String label;
  final String state;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (state) {
      case 'done':
        color = const Color(0xFF1D4ED8);
        break;
      case 'attention':
        color = const Color(0xFFB45309);
        break;
      case 'failed':
        color = const Color(0xFFB1361B);
        break;
      case 'missing':
        color = const Color(0xFFD1D5DB);
        break;
      default:
        color = const Color(0xFF9CA3AF);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: AppTheme.publicLine),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.publicMuted,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// TemplateLineageMap — names the body-source lineage in plain text.
// ---------------------------------------------------------------------

class TemplateLineageMap extends StatelessWidget {
  const TemplateLineageMap({
    super.key,
    required this.bodySource,
    this.templateKey,
    this.templateVersion,
    this.aiToneModifier,
  });

  final String? bodySource;
  final String? templateKey;
  final int? templateVersion;
  final String? aiToneModifier;

  @override
  Widget build(BuildContext context) {
    final entries = _entriesFor(bodySource);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  e.isDone ? Icons.check : Icons.remove,
                  size: 14,
                  color: e.isDone
                      ? const Color(0xFF1D4ED8)
                      : AppTheme.publicMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.text,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.publicText,
                          height: 1.45,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if ((templateKey ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          ProvenanceChainStrip(
            templateKey: templateKey,
            templateVersion: templateVersion,
          ),
        ],
        if ((aiToneModifier ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          GovernanceBadge(
            label: 'tone',
            value: aiToneModifier,
            tone: GovernanceTone.neutral,
          ),
        ],
      ],
    );
  }

  List<_LineageEntry> _entriesFor(String? source) {
    switch (source) {
      case 'catalog':
        return [
          _LineageEntry('Sequence step bound a governed template.', true),
          _LineageEntry('Renderer produced subject + body from the catalog.', true),
          _LineageEntry('Template provenance stamped on the wire.', true),
        ];
      case 'bounded_ai_catalog':
        return [
          _LineageEntry(
            'Bounded AI selected a governed template from the allowed set.',
            true,
          ),
          _LineageEntry('AI bound approved variables (renderer-validated).', true),
          _LineageEntry('Renderer produced subject + body from the catalog.', true),
          _LineageEntry('Template provenance stamped on the wire.', true),
        ];
      case 'ai_fallback_catalog':
        return [
          _LineageEntry('Freeform AI generation failed.', false),
          _LineageEntry(
            'Governed catalog fallback rendered the body.',
            true,
          ),
          _LineageEntry('Template provenance stamped on the wire.', true),
        ];
      case 'sequence_legacy':
        return [
          _LineageEntry('Sequence step used a legacy subject/body string.', true),
          _LineageEntry(
            'No governed-template provenance claimed (honest).',
            false,
          ),
        ];
      case 'ai_draft':
        return [
          _LineageEntry(
            'Freeform AI produced subject + body (WriterAgent path).',
            true,
          ),
          _LineageEntry(
            'No governed-template provenance claimed (honest).',
            false,
          ),
        ];
      default:
        return [
          _LineageEntry('Body source not labeled on this row.', false),
          _LineageEntry(
            'Operation, thread, lane, lifecycle, attempt still attached.',
            true,
          ),
        ];
    }
  }
}

class _LineageEntry {
  const _LineageEntry(this.text, this.isDone);
  final String text;
  final bool isDone;
}

// ---------------------------------------------------------------------
// AttributionChainView — outbound op → thread → (reply | not yet).
// ---------------------------------------------------------------------

class AttributionChainView extends StatelessWidget {
  const AttributionChainView({
    super.key,
    required this.operationId,
    required this.threadId,
    this.replyId,
    this.replyAt,
    this.followUpCancelled,
  });

  final String? operationId;
  final String? threadId;
  final String? replyId;
  final String? replyAt;
  final bool? followUpCancelled;

  @override
  Widget build(BuildContext context) {
    final hasReply = (replyId ?? '').isNotEmpty;
    final steps = <LifecycleStep>[
      LifecycleStep(
        label: 'Outbound operation',
        state: (operationId ?? '').isNotEmpty ? 'done' : 'missing',
        detail: operationId == null
            ? 'Operation id not recorded'
            : 'X-Orchestrate-Operation-Id stamped on the wire',
      ),
      LifecycleStep(
        label: 'Thread continuity',
        state: (threadId ?? '').isNotEmpty ? 'done' : 'missing',
        detail: threadId == null
            ? 'Thread id not recorded'
            : 'X-Orchestrate-Thread-Id stamped on the wire',
      ),
      LifecycleStep(
        label: hasReply ? 'Reply attributed' : 'Reply attribution',
        state: hasReply ? 'done' : 'pending',
        detail: hasReply
            ? 'Reply matched via In-Reply-To / References / X-Operation-Id'
            : 'No reply attributed yet (or not recorded in this view)',
        timestamp: replyAt,
      ),
      if (followUpCancelled == true)
        const LifecycleStep(
          label: 'Follow-up cancelled by reply',
          state: 'done',
          detail:
              'Pending follow-up jobs against this operation were cancelled when the reply landed.',
        ),
    ];
    return LifecycleTimeline(steps: steps);
  }
}

// ---------------------------------------------------------------------
// DispatchRecoveryTrack — retries / failures / recovery.
// ---------------------------------------------------------------------

class DispatchRecoveryTrack extends StatelessWidget {
  const DispatchRecoveryTrack({
    super.key,
    required this.attempt,
    required this.status,
    this.lastError,
  });

  final int? attempt;
  final String? status;
  final String? lastError;

  @override
  Widget build(BuildContext context) {
    final normalized = (status ?? '').toUpperCase();
    final failed =
        normalized == 'FAILED' || normalized == 'RETRYABLE_FAILED';
    final recovering = normalized == 'SENDING' && (attempt ?? 0) > 1;

    final steps = <LifecycleStep>[
      LifecycleStep(
        label: 'Attempt ${attempt ?? 1}',
        state: failed
            ? 'failed'
            : recovering
                ? 'attention'
                : 'done',
        detail: failed
            ? (lastError ?? 'Last attempt failed; awaiting retry')
            : recovering
                ? 'Retry in flight'
                : 'Dispatched successfully',
      ),
      if (failed && (lastError ?? '').isNotEmpty)
        LifecycleStep(
          label: 'Last provider error',
          state: 'failed',
          detail: lastError,
        ),
    ];
    return LifecycleTimeline(steps: steps);
  }
}

