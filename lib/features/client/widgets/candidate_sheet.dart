import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/market/client_market.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/ui/authority_gate.dart';
import 'package:orchestrate_app/core/ui/governed_action.dart';

/// ONE COUNTERPARTY, IN DEPTH.
///
/// Layered the way the questions arrive: why this may matter, what was actually
/// observed, what judgement exists, what the business decided, and — on
/// demand — where it all came from.
///
/// Not a record-editing form. The only thing a person writes here is their own
/// view, and that view is internal: it sends nothing, admits nothing, and does
/// not create a relationship. Reaching out is a separate question with a
/// separate answer, and this sheet asks it rather than assuming it.
class CandidateSheet extends StatefulWidget {
  const CandidateSheet({super.key, required this.candidate, required this.onChanged});

  final Candidate candidate;
  final VoidCallback onChanged;

  @override
  State<CandidateSheet> createState() => _CandidateSheetState();
}

class _CandidateSheetState extends State<CandidateSheet> {
  CandidateDepth? _depth;
  Object? _error;
  bool _busy = false;
  Refusal? _refusal;
  bool _showProvenance = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _depth = null;
    });
    try {
      final depth = await ClientMarket.instance.candidate(widget.candidate.key);
      if (mounted) setState(() => _depth = depth);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = _depth?.candidate ?? widget.candidate;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Semantics(
            header: true,
            child: Text(c.name,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          Text(
            [
              c.domain,
              if (c.geography != null) c.geography!,
              if (c.contactName != null)
                c.contactRole != null ? '${c.contactName} · ${c.contactRole}' : c.contactName!,
            ].join(' · '),
            style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
          ),

          const SizedBox(height: 18),

          // ── WHY THIS MAY MATTER ──────────────────────────────────────────
          if (c.whyItMatters != null)
            _Panel(
              icon: Icons.insights_outlined,
              accent: AppTheme.publicAccent,
              title: 'Why this may matter',
              // The server's evidence-citing rationale, verbatim. It names the
              // offer, the situation and the observation behind the link.
              body: c.whyItMatters!,
              footnote: c.opportunityStrength != null
                  ? 'Read as a ${c.opportunityStrength!.toLowerCase()} fit'
                      '${c.opportunityConfidence != null ? ', ${c.opportunityConfidence}% confidence' : ''}.'
                  : null,
            )
          else
            _Panel(
              icon: Icons.help_outline,
              accent: AppTheme.publicMuted,
              title: 'We have not established why this would matter',
              body: 'Nothing we observed connects this company to what your '
                  'business sells. They may still be worth a look — we just '
                  'cannot say so from evidence.',
            ),

          const SizedBox(height: 12),

          // ── HOW SURE ─────────────────────────────────────────────────────
          _Panel(
            icon: switch (c.certainty) {
              Certainty.evidenced => Icons.verified_outlined,
              Certainty.thin => Icons.remove_circle_outline,
              Certainty.stale => Icons.history_toggle_off,
              Certainty.insufficient => Icons.help_outline,
            },
            accent: c.certainty == Certainty.evidenced
                ? AppTheme.publicAccent
                : AppTheme.amber,
            title: c.certainty.label,
            body: c.certaintyMeans,
          ),

          const SizedBox(height: 20),

          // ── EVIDENCE ─────────────────────────────────────────────────────
          Text('What we observed',
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _evidence(text),

          // ── JUDGEMENT ────────────────────────────────────────────────────
          if (c.reasons.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('What held this back',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (final reason in c.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5, right: 8),
                      child: Icon(Icons.circle, size: 5, color: AppTheme.publicMuted),
                    ),
                    Expanded(child: Text(reason, style: text.bodySmall)),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 24),

          // ── YOUR VIEW ────────────────────────────────────────────────────
          Text('Your view',
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            c.dispositionMeans,
            style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
          ),
          if (c.dispositionNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('"${c.dispositionNote}"', style: text.bodySmall),
            ),
          const SizedBox(height: 12),
          _dispositions(c),

          if (_refusal != null) RefusalNotice(refusal: _refusal!),

          // ── WHERE THIS GOES NEXT ─────────────────────────────────────────
          if (c.hasRelationship) ...[
            const SizedBox(height: 20),
            _Panel(
              icon: Icons.link,
              accent: AppTheme.publicAccent,
              title: 'You already have a relationship here',
              body: 'What happens next with this counterparty lives in '
                  'Relationships, not in Market.',
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: c.relationshipId == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      context.go('/client/relationships/${c.relationshipId}');
                    },
              child: const Text('Open the relationship'),
            ),
          ] else ...[
            const SizedBox(height: 20),
            Text('Reaching out',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            // Market may make the opportunity visible. It may not act on it —
            // the authority contract answers, and today it refuses for every
            // client in production.
            AuthorityGate(
              consequence: Consequence.externallyCommunicated,
              label: 'Reach out to ${c.name}',
              onProceed: () {},
            ),
          ],

          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => setState(() => _showProvenance = !_showProvenance),
            icon: Icon(_showProvenance ? Icons.expand_less : Icons.expand_more, size: 18),
            label: const Text('Where this came from'),
          ),
          if (_showProvenance) _provenance(text, c),
        ],
      ),
    );
  }

  Widget _evidence(TextTheme text) {
    if (_error != null) {
      return _Panel(
        icon: Icons.cloud_off_outlined,
        accent: AppTheme.rose,
        title: 'Evidence is unavailable right now',
        body: 'What we know about this company is unchanged. We just could not '
            'read it back.',
      );
    }
    final depth = _depth;
    if (depth == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(
          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (depth.refusalReason != null) {
      return _Panel(
        icon: Icons.block_outlined,
        accent: AppTheme.rose,
        title: 'Not in your market',
        body: depth.refusalReason!,
      );
    }
    if (depth.evidence.isEmpty) {
      return Text(
        'Nothing about this company has been corroborated. Whatever brought '
        'them to our attention was not strong enough to record as an '
        'observation.',
        style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final o in depth.evidence)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.headline, style: text.bodySmall),
                const SizedBox(height: 2),
                Text(
                  [
                    _when(o.observedAt),
                    o.kind.toLowerCase().replaceAll('_', ' '),
                    // Whether it was corroborated is said in words, because it
                    // is the difference between a fact and a rumour.
                    o.corroborated ? 'corroborated' : 'weak',
                  ].join(' · '),
                  style: text.bodySmall?.copyWith(
                      color: AppTheme.publicMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        if (depth.opportunityNarrative != null) ...[
          const SizedBox(height: 4),
          Text(depth.opportunityNarrative!, style: text.bodySmall),
        ],
      ],
    );
  }

  Widget _dispositions(Candidate c) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final d in PursuitDisposition.values)
          if (d != PursuitDisposition.unreviewed)
            OutlinedButton(
              onPressed: _busy || c.disposition == d ? null : () => _set(d),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    c.disposition == d ? AppTheme.publicAccent : null,
                side: BorderSide(
                  color: c.disposition == d
                      ? AppTheme.publicAccent
                      : AppTheme.publicLine,
                ),
              ),
              child: Text(d.label),
            ),
      ],
    );
  }

  Widget _provenance(TextTheme text, Candidate c) {
    final depth = _depth;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.publicLine),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fact(text, 'Identified by', c.domain),
          if (depth?.discoveredAt != null)
            _fact(text, 'First seen', _when(depth!.discoveredAt!)),
          // Surfaced rather than hidden: a person deserves to know when our
          // view of a company is assembled from several separate sightings.
          if (c.discoveredRepresentations > 1)
            _fact(text, 'Found separately',
                '${c.discoveredRepresentations} times, treated as one company'),
          if ((depth?.campaigns ?? 0) > 1)
            _fact(text, 'Across', '${depth!.campaigns} campaigns'),
          if (c.decision != null)
            _fact(text, 'Current assessment',
                '${c.decision!.toLowerCase()}${c.decidedAt != null ? ', ${_when(c.decidedAt!)}' : ''}'),
          const SizedBox(height: 8),
          Text(
            'Deciding your view here is internal to your business. Nothing is '
            'sent and no relationship is created by it.',
            style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
          ),
        ],
      ),
    );
  }

  Widget _fact(TextTheme text, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(label,
                  style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
            ),
            Expanded(child: Text(value, style: text.bodySmall)),
          ],
        ),
      );

  Future<void> _set(PursuitDisposition disposition) async {
    setState(() {
      _busy = true;
      _refusal = null;
    });
    try {
      final result = await ClientMarket.instance
          .setPursuit(key: widget.candidate.key, disposition: disposition);
      if (!mounted) return;
      final refusal = Refusal.fromResponse(result);
      if (refusal != null) {
        setState(() {
          _busy = false;
          _refusal = refusal;
        });
        return;
      }
      widget.onChanged();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _refusal = Refusal.unexpected(e);
      });
    }
  }

  static String _when(DateTime at) {
    final days = DateTime.now().difference(at).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 30) return '$days days ago';
    if (days < 365) return '${(days / 30).round()} months ago';
    return '${at.year}-${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')}';
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    this.footnote,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(body,
                    style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
                if (footnote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(footnote!,
                        style: text.bodySmall?.copyWith(
                            color: AppTheme.publicMuted, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
