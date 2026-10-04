import 'package:orchestrate_app/features/client/widgets/pursuit_outcome.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/market/client_market.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/ui/authority_gate.dart';
import 'package:orchestrate_app/core/ui/governed_action.dart';
import 'package:orchestrate_app/core/commercial/client_capabilities.dart';
import 'package:orchestrate_app/features/client/widgets/commercial_boundary.dart';
import 'package:orchestrate_app/features/client/widgets/contact_readiness_panel.dart';
import 'package:orchestrate_app/features/client/widgets/prospect_facts.dart';

/// ONE BUSINESS, AND THE ONE DECISION ABOUT IT.
///
/// Who they are, why they would need you, who would be written to, what a yes
/// does; then Yes, write to them / Not now / Not for us. A yes starts the first
/// note through the governed send path. Everything checked folds under Details.
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

  /// ONE DECISION, ENOUGH TO MAKE IT (3 Oct 2026).
  ///
  /// Founder: "pursue card its opening details has to be enough good so it
  /// must be easier for client to decide. not this and that". The sheet read
  /// as nine sections and three verdict buttons, with a "Reach out" control
  /// that did nothing. It now answers, in order, the four things a person asks
  /// before saying yes: who they are, why they would need you, who exactly
  /// would be written to, and what a yes does. Then one choice. Everything we
  /// checked and where it came from folds under Details.
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = _depth?.candidate ?? widget.candidate;
    final checks = c.checks;
    final writing = c.disposition == PursuitDisposition.pursuing;

    final whoWhere = [
      if (c.domain.isNotEmpty && !c.domain.startsWith('name:')) c.domain,
      if ((c.geography ?? '').isNotEmpty) c.geography!,
    ].join(' · ');
    final why = [
      prospectProposal(c),
      if (c.whyItMatters != null && (checks == null || checks.matchesYour.isEmpty))
        c.whyItMatters!,
    ].where((s) => s.trim().isNotEmpty).join(' ');
    final recipient = checks == null
        ? null
        : [
            if (c.contactName != null)
              c.contactRole != null ? '${c.contactName}, ${c.contactRole}' : c.contactName!,
            checks.email,
          ].join(' · ');

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
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (whoWhere.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(whoWhere,
                style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
          ],
          const SizedBox(height: 20),

          if (why.isNotEmpty) ...[
            _Answer(title: 'What we propose', body: why),
            const SizedBox(height: 16),
          ],
          if (c.moments.isNotEmpty) ...[
            _Answer(
              title: 'Why now',
              body: c.moments.take(2).map(momentSaid).join('\n'),
            ),
            const SizedBox(height: 16),
          ],
          if (recipient != null) ...[
            _Answer(
              title: 'Who you would be writing to',
              body: recipient,
              footnote: checks!.mailboxConfirmed
                  ? 'Published by them ${checks.addressFoundInSaid}; it accepts mail.'
                  : 'Published by them ${checks.addressFoundInSaid}.',
            ),
            const SizedBox(height: 16),
          ],

          if (c.hasRelationship) ...[
            _Answer(
              title: 'You already work with them',
              body: 'What happens next lives with that relationship.',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: c.relationshipId == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      context.go('/client/relationships/${c.relationshipId}');
                    },
              child: const Text('Open the relationship'),
            ),
          ] else if (writing) ...[
            _Answer(
              title: 'Orchestrate is writing to them',
              body: 'From your own email. Replies come straight to you.',
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy ? null : () => _set(PursuitDisposition.holding),
              child: const Text('Stop: not now'),
            ),
          ] else ...[
            _Answer(
              title: 'If you say yes',
              body: 'Orchestrate writes them a short first note from your own '
                  'email, and follows up if they do not answer. Replies come '
                  'straight to you. Not now keeps them for later; Not for us '
                  'means they are not proposed again.',
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton(
                onPressed: _busy ? null : () => _set(PursuitDisposition.pursuing),
                child: Text(_busy ? 'Saving…' : 'Yes, write to them'),
              ),
              OutlinedButton(
                onPressed: _busy || c.disposition == PursuitDisposition.holding
                    ? null
                    : () => _set(PursuitDisposition.holding),
                child: const Text('Not now'),
              ),
              TextButton(
                onPressed: _busy || c.disposition == PursuitDisposition.declined
                    ? null
                    : () => _set(PursuitDisposition.declined),
                child: const Text('Not for us'),
              ),
            ]),
          ],
          // Where the commercial boundary belongs: at the act. A business with
          // no plan can still read why; it cannot yet say yes.
          const CommercialBoundary(
              capability: Capabilities.operateCommercially, compact: true),
          if (_refusal != null) RefusalNotice(refusal: _refusal!),

          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showProvenance = !_showProvenance),
              icon: Icon(_showProvenance ? Icons.expand_less : Icons.expand_more, size: 18),
              label: const Text('Details'),
            ),
          ),
          if (_showProvenance) ..._details(text, c),
        ],
      ),
    );
  }

  /// Everything checked and where it came from, for whoever wants it.
  List<Widget> _details(TextTheme text, Candidate c) => [
        for (final f in prospectFacts(c).where((f) => f.icon != Icons.bolt))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(f.icon, size: 16, color: AppTheme.publicMuted),
              const SizedBox(width: 8),
              Expanded(child: Text(f.text, style: text.bodySmall)),
            ]),
          ),
        if (c.checks == null) ...[
          const SizedBox(height: 6),
          _evidence(text),
        ],
        for (final reason in c.reasons)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(reason, style: text.bodySmall),
          ),
        _provenance(text, c),
      ];

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
            'A yes starts a first note from your own email. Not now and Not '
            'for us send nothing.',
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
      showPursuitOutcome(context, result);
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
    if (days < 365) {
      final months = (days / 30).round();
      return months <= 1 ? 'last month' : '$months months ago';
    }
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
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;

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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One answer to one question a person asks before deciding.
class _Answer extends StatelessWidget {
  const _Answer({required this.title, required this.body, this.footnote});
  final String title;
  final String body;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(body, style: text.bodyMedium?.copyWith(height: 1.45)),
        if (footnote != null) ...[
          const SizedBox(height: 3),
          Text(footnote!, style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
        ],
      ],
    );
  }
}
