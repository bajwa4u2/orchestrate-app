import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/market/client_market.dart';
import 'package:orchestrate_app/core/network/api_client.dart';
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
  const MarketScreen({super.key, this.focusCounterpartyKey});

  /// Open straight onto one counterparty. Used when a person arrives from work
  /// that is about a specific company, so they land on the thing rather than
  /// on a list they then have to search.
  final String? focusCounterpartyKey;

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
      // Held, not rethrown. load() has already recorded the error and notified
      // listeners, so _body() renders the failure; rethrowing here does nothing
      // except turn a handled error into an unhandled async one, which reaches
      // the zone handler and reports as a crash on top of a screen that is
      // already showing the problem correctly.
      unawaited(_market.load().then<void>((_) {}, onError: (Object _) {}));
    }
    _focusIfAsked();
  }

  @override
  void dispose() {
    _market.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
    _focusIfAsked();
  }

  bool _focused = false;

  /// Opens the requested counterparty once the answer is in, and only once.
  /// A key we do not hold is left alone — arriving on the list is a fair
  /// outcome, and inventing a sheet for a company Market cannot see is not.
  void _focusIfAsked() {
    final key = widget.focusCounterpartyKey;
    if (_focused || key == null || !mounted || !_market.hasAnswer) return;
    Candidate? match;
    for (final c in _market.view!.candidates) {
      if (c.key == key) match = c;
    }
    if (match == null) return;
    _focused = true;
    final found = match;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open(found);
    });
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
    final failure = _market.error;
    if (failure != null) {
      return _Unavailable(error: failure, onRetry: () => _market.refresh());
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

/// WHY IT COULD NOT BE LOADED, WHICH IS NOT ONE SITUATION.
///
/// This said "we could not read it right now" whatever had happened, and threw
/// away an exception that already knew the status code, the message and the
/// request id. Four different faults with four different owners read
/// identically: a session that ended, a network that could not be reached, an
/// error on our side, and an answer that arrived intact and could not be
/// parsed. Only one of them is fixed by pressing Try again, and nobody looking
/// at the screen could tell which one they had.
///
/// What it keeps: a failure is never rendered as an empty market. Zero
/// candidates would tell a business its pipeline had vanished, and that is a
/// worse lie than an unhelpful message.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  /// Platform-safe: naming SocketException directly would pull in dart:io,
  /// which does not exist on web, and this screen builds for both.
  bool get _isNetwork {
    final name = error.runtimeType.toString();
    return name.contains('SocketException')
        || name.contains('ClientException')
        || name.contains('HandshakeException')
        || name.contains('TimeoutException');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final api = error is ApiException ? error as ApiException : null;

    final String headline;
    final String detail;
    final String? reference;

    if (api != null && api.isAuthFailure) {
      headline = 'Your session has ended.';
      detail = 'Sign in again and your market will be here. Nothing was lost.';
      reference = null;
    } else if (_isNetwork) {
      headline = 'Orchestrate could not be reached.';
      detail = 'This looks like the connection rather than your data. '
          'Nothing has changed and nothing was lost.';
      reference = null;
    } else if (api != null && api.statusCode >= 500) {
      headline = 'Orchestrate answered with an error.';
      // Named as ours, because it is. Telling a business to try again when the
      // fault is on this side wastes their time on a button that cannot help.
      detail = 'This is a fault on our side rather than anything about your '
          'business. Trying again may not help; the reference below identifies '
          'exactly what failed.';
      reference = api.displayId.isEmpty ? null : api.displayId;
    } else if (api != null) {
      headline = 'We could not load your market.';
      detail = api.message;
      reference = api.displayId.isEmpty ? null : api.displayId;
    } else {
      // The answer arrived and could not be read. A different fault with a
      // different owner: retrying fetches the same unreadable answer again.
      headline = 'Your market arrived but could not be read.';
      detail = 'The answer reached this device and did not have the shape this '
          'version expects, so nothing is being shown rather than something '
          'wrong. Updating the app is more likely to help than trying again.';
      reference = error.runtimeType.toString();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(detail,
              style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
          if (reference != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              reference,
              style: text.bodySmall?.copyWith(
                color: AppTheme.publicMuted,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
