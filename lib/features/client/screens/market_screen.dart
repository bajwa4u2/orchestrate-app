import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/market/client_market.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/client/widgets/candidate_sheet.dart';

/// MARKET — WHO MAY BE WORTH ENTERING INTO COMMERCIAL RELATIONSHIP WITH.
///
/// Relationship is depth; Market is comparison. So this is a list a person can
/// scan and judge across, not a stack of company cards each five screens tall,
/// and not a CRM grid either.
///
/// What it deliberately does not open with: "215 leads", "average score 74",
/// "6 campaigns", "79,705 signals". Those are accounting numbers about a
/// database. The question a business actually arrives with is who deserves
/// attention now and why, so the first thing on screen is what the business
/// sells, and then the counterparties where something was genuinely observed.
///
/// Ordering comes from the server. A client-side re-rank would be a second
/// commercial opinion, and one of the two would be wrong in front of a real
/// business.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final ClientMarket _market = ClientMarket.instance;
  bool _showQuiet = false;

  @override
  void initState() {
    super.initState();
    _market.addListener(_onChanged);
    if (!_market.hasAnswer && !_market.isLoading && _market.error == null) {
      _market.load().catchError((Object e) => throw e);
    }
  }

  @override
  void dispose() {
    _market.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WorkspaceHeader(
          title: 'Market',
          context_: 'Who may be worth entering into commercial relationship with.',
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_market.error != null) {
      return _Unavailable(onRetry: () => _market.refresh());
    }
    final view = _market.view;
    if (view == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    // An empty Market has several truthful shapes and they are not the same
    // situation. Collapsing them into "no leads yet" would tell a business
    // that discovery found nothing when in fact they never said what they sell.
    if (view.candidates.isEmpty) {
      if (view.intent == null) {
        return const QuietState(
          message: 'Your business has not said what it sells.',
          hint: 'Until it does, there is nothing to judge a counterparty '
              'against. Business is where that is set.',
        );
      }
      if (view.excludedWithoutIdentity > 0 || view.excludedArtifacts > 0) {
        return QuietState(
          message: 'Nothing found so far could be shown as a company.',
          hint: view.excludedNote ?? '',
        );
      }
      return const QuietState(
        message: 'Nobody has been found yet.',
        hint: 'Counterparties appear here as discovery finds them.',
      );
    }

    final review = view.needsReview;
    final decided = view.decided;
    final quiet = view.notEnoughKnown;
    final related = view.alreadyRelated;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (view.intent != null) _Intent(intent: view.intent!),

        // Where something was actually observed and nobody has formed a view.
        if (review.isNotEmpty)
          WorkspaceBand(
            title: 'WORTH A LOOK',
            children: [for (final c in review) _Row(candidate: c, onOpen: _open)],
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: QuietState(message: 'Nothing new needs your judgement.'),
          ),

        if (decided.isNotEmpty)
          WorkspaceBand(
            title: 'YOU HAVE DECIDED',
            children: [for (final c in decided) _Row(candidate: c, onOpen: _open)],
          ),

        // Already a relationship. Shown so Market can still explain how they
        // were found, and handed onward rather than duplicated here.
        if (related.isNotEmpty)
          WorkspaceBand(
            title: 'ALREADY A RELATIONSHIP',
            children: [for (final c in related) _Row(candidate: c, onOpen: _open)],
          ),

        // Real companies nobody has observed anything about. Behind a fold,
        // because presenting them beside evidenced ones would imply a finding
        // where there is only a name.
        if (quiet.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _showQuiet = !_showQuiet),
            icon: Icon(_showQuiet ? Icons.expand_less : Icons.expand_more, size: 18),
            label: Text(_showQuiet
                ? 'Hide the ones we know little about'
                : 'Show ${quiet.length} we know little about'),
          ),
          if (_showQuiet)
            WorkspaceBand(
              title: 'NOT ENOUGH OBSERVED',
              children: [for (final c in quiet) _Row(candidate: c, onOpen: _open)],
            ),
        ],

        if (view.excludedNote != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              view.excludedNote!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.publicMuted),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  void _open(Candidate candidate) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CandidateSheet(
        candidate: candidate,
        onChanged: () => _market.refresh(),
      ),
    );
  }
}

/// What this business sells, in its own words.
///
/// First on screen because "worth pursuing" is meaningless without an object.
/// Every judgement below it is relative to this sentence.
class _Intent extends StatelessWidget {
  const _Intent({required this.intent});

  final BusinessIntent intent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.publicLine),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What you are looking for',
              style: text.bodySmall?.copyWith(
                  color: AppTheme.publicMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(intent.says, style: text.bodyMedium),
          if (intent.triggers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'We watch for: ${intent.triggers.join(', ').toLowerCase()}.',
              style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// One counterparty, at scanning density.
///
/// Carries who, why, how sure, and what the business decided — and nothing
/// else. Every signal and score on a row would make the list unreadable and
/// turn comparison back into browsing.
class _Row extends StatelessWidget {
  const _Row({required this.candidate, required this.onOpen});

  final Candidate candidate;
  final void Function(Candidate) onOpen;

  @override
  Widget build(BuildContext context) {
    return WorkspaceRow(
      title: candidate.name,
      // Where the evidence is good, the row leads with why this matters.
      // Where it has aged or was never there, it leads with that instead: a
      // rationale printed beside a four-month-old observation reads as a live
      // reason to act, and the row would be asserting something the evidence
      // no longer supports. The rationale is still in the sheet.
      detail: switch (candidate.certainty) {
        Certainty.evidenced || Certainty.thin =>
          candidate.whyItMatters ?? candidate.certaintyMeans,
        Certainty.stale || Certainty.insufficient => candidate.certaintyMeans,
      },
      meta: _meta,
      tone: candidate.hasRelationship
          ? RowTone.good
          : switch (candidate.certainty) {
              Certainty.evidenced => RowTone.attention,
              Certainty.thin => RowTone.waiting,
              _ => RowTone.neutral,
            },
      onTap: () => onOpen(candidate),
      action: const Icon(Icons.chevron_right, size: 18, color: AppTheme.publicMuted),
    );
  }

  /// Never colour alone. Certainty and disposition are both words.
  String get _meta => [
        candidate.domain,
        if (candidate.hasRelationship)
          'relationship'
        else
          candidate.certainty.label.toLowerCase(),
        if (candidate.disposition != PursuitDisposition.unreviewed)
          candidate.disposition.label.toLowerCase(),
      ].join(' · ');
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('We could not load your market.',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          // Not "0 candidates". A failure that renders as an empty market
          // would tell a business its pipeline had vanished.
          Text(
            'Nothing has changed and nothing was lost. We just could not read '
            'it right now.',
            style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
