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
