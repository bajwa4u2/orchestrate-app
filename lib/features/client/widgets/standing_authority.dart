import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/authority/client_authority.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';

/// WHERE THIS BUSINESS STANDS, IN ITS OWN THREE PARTS.
///
/// The three parts are not stages of one process and are deliberately not
/// drawn as one. They are separate corporate facts that happen to all be true
/// at once:
///
///   THE BUSINESS — has it named anyone who may decide for it.
///   YOU — are you one of them, and for which areas.
///   ORCHESTRATE — what has anyone allowed the software itself to do.
///
/// Rendered from the canonical authority projection and from nothing else.
/// An earlier version of this screen drew a second summary from a different
/// backend model beside this one; two answers to "what may we do" is how a
/// business ends up believing the more generous of them.
///
/// Explicitly not built: a progress ring, a completion percentage, a green
/// "Authorized" banner, a compliance score. A business that has not named
/// anyone has not failed at anything, and a business that has is not owed
/// applause. Both are simply told what is true.
class StandingAuthority extends StatelessWidget {
  const StandingAuthority({super.key, this.onResolve});

  /// Invoked when the person acts on a blocker. Null where there is nothing
  /// this surface can offer, in which case the blocker is still stated.
  final void Function(String missingKey)? onResolve;

  @override
  Widget build(BuildContext context) {
    return AuthorityBuilder(
      builder: (context, authority) => _Standing(
        authority: authority,
        onResolve: onResolve,
      ),
    );
  }
}

class _Standing extends StatelessWidget {
  const _Standing({required this.authority, required this.onResolve});

  final AuthorityProjection authority;
  final void Function(String missingKey)? onResolve;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.publicMuted.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The three parts describe the BUSINESS, the PERSON and
              // ORCHESTRATE. Where a submission is under review, the business
              // row used to borrow the submission's sentence — "we are
              // reviewing what your business sent" — which is the submission
              // card's job and left the business row saying nothing about the
              // business.
              _Part(
                title: authority.businessName,
                settled: authority.organizationEstablished,
                pending: authority.underReview,
                meaning: authority.underReview && !authority.organizationEstablished
                    ? 'This business has not yet recognised anyone as able to '
                        'decide for it.'
                    : authority.organizationMeaning,
              ),
              const Divider(height: 28, color: AppTheme.publicLine, thickness: 1),
              _Part(
                title: 'You',
                settled: authority.youAreRecognised,
                pending: false,
                meaning: authority.youMeaning,
                // The three areas are always shown, including the ones not
                // held. An area that is simply absent from the list reads as
                // an oversight; an area shown as not held reads as an answer.
                areas: authority.youAreRecognised ? authority.areas : const [],
              ),
              const Divider(height: 28, color: AppTheme.publicLine, thickness: 1),
              _Part(
                title: 'Orchestrate',
                settled: authority.orchestrateEverGranted,
                pending: false,
                meaning: authority.orchestrateMeaning,
                // WHY THIS IS NOT A CONTRADICTION.
                //
                // "Your business has not recognised you as able to decide for
                // it" sits directly above "Orchestrate may communicate on your
                // behalf", and the two read as impossible together. They are
                // both true, and the bridge is a record — somebody accepted, on
                // a date, somewhere in the product, naming no areas at all. A
                // person left to reconcile that themselves concludes the
                // product is wrong, and they are not being unreasonable.
                provenance: authority.orchestrateProvenance,
              ),
            ],
          ),
        ),
        // Where this person's own submission stands. Placed above the
        // blockers because a refusal or an unanswered question is the most
        // actionable thing on the screen, and below the card because it is
        // about one person rather than about the business.
        if (authority.submission.state != SubmissionState.notSubmitted) ...[
          const SizedBox(height: 16),
          _SubmissionStanding(submission: authority.submission),
        ],
        if (authority.missing.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final step in authority.missing)
            _Blocker(
              step: step,
              onResolve: onResolve == null ? null : () => onResolve!(step.key),
            ),
        ],
        if (authority.describedAs != null) ...[
          const SizedBox(height: 12),
          Text(
            'Your business describes you as "${authority.describedAs}". '
            'A job title is recorded, and carries no authority by itself — '
            'the areas above are what govern.',
            style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
          ),
        ],
      ],
    );
  }
}

class _Part extends StatelessWidget {
  const _Part({
    required this.title,
    required this.settled,
    required this.pending,
    required this.meaning,
    this.areas = const [],
    this.provenance,
  });

  final String title;
  final bool settled;
  final bool pending;
  final String meaning;
  final List<AreaStanding> areas;

  /// Where this came from. Shown where a statement would otherwise look like it
  /// contradicts the one above it.
  final GrantProvenance? provenance;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Mark(settled: settled, pending: pending),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(meaning, style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
              if (provenance != null) ...[
                const SizedBox(height: 6),
                Text(provenance!.say,
                    style: text.bodySmall?.copyWith(height: 1.5)),
                const SizedBox(height: 2),
                Text(provenance!.why,
                    style: text.bodySmall
                        ?.copyWith(color: AppTheme.publicMuted, height: 1.5)),
              ],
              if (areas.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final area in areas) _AreaLine(area: area),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One area, and the three separate things a person may or may not do in it.
///
/// Kept as three answers rather than one badge because they genuinely differ:
/// someone can be able to approve an agreement, unable to let Orchestrate
/// approve one, and unable to appoint anyone else — all at the same time.
class _AreaLine extends StatelessWidget {
  const _AreaLine({required this.area});

  final AreaStanding area;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final held = area.canAct;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            held ? Icons.check_circle_outline : Icons.remove_circle_outline,
            size: 15,
            color: held ? AppTheme.publicAccent : AppTheme.publicMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: area.label,
                    style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: held ? null : AppTheme.publicMuted,
                    ),
                  ),
                  TextSpan(
                    text: held ? ' — you may approve these' : ' — not yours to approve',
                    style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
                  ),
                  if (held && area.canAuthoriseOrchestrate)
                    TextSpan(
                      text: ', and you may let Orchestrate do it',
                      style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
                    ),
                  if (held && area.canRecogniseOthers)
                    TextSpan(
                      text: ', and you may recognise others',
                      style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
                    ),
                ],
              ),
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Settled, waiting on us, or not yet done. Three states, no score.
class _Mark extends StatelessWidget {
  const _Mark({required this.settled, required this.pending});

  final bool settled;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = settled
        ? (Icons.check_circle, AppTheme.publicAccent)
        : pending
            ? (Icons.schedule, AppTheme.amber)
            : (Icons.circle_outlined, AppTheme.publicMuted);
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

/// What became of this person's designation, in its own words.
///
/// The six states are shown as six states. An earlier version could only say
/// "under review" or nothing at all, which made a refusal, an unanswered
/// question and never having submitted look identical — and the person most
/// likely to give up is the one who cannot tell which of those happened.
class _SubmissionStanding extends StatelessWidget {
  const _SubmissionStanding({required this.submission});

  final Submission submission;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final needsYou = submission.state.needsYou;
    final accent = needsYou
        ? AppTheme.amber
        : submission.state == SubmissionState.admitted
            ? AppTheme.publicAccent
            : AppTheme.publicMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_title,
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(submission.meaning,
                    style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
                // The operator's own words, verbatim. Paraphrasing either of
                // these would lose the only part that says what to do next.
                if (submission.operatorAsked != null) ...[
                  const SizedBox(height: 10),
                  Text('What we need', style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(submission.operatorAsked!, style: text.bodySmall),
                ],
                if (submission.refusedBecause != null) ...[
                  const SizedBox(height: 10),
                  Text('Why', style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(submission.refusedBecause!, style: text.bodySmall),
                ],
                if (submission.asserted != null) ...[
                  const SizedBox(height: 10),
                  Text('You asked to be recognised for: ${submission.asserted}',
                      style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _title => switch (submission.state) {
        SubmissionState.submitted => 'Your submission is with us',
        SubmissionState.moreEvidenceRequested => 'We need something more from you',
        SubmissionState.admitted => 'Your submission was admitted',
        SubmissionState.refused => 'Your submission was not admitted',
        SubmissionState.superseded => 'Replaced by a later submission',
        SubmissionState.notSubmitted => 'Not submitted',
      };

  IconData get _icon => switch (submission.state) {
        SubmissionState.submitted => Icons.schedule,
        SubmissionState.moreEvidenceRequested => Icons.help_outline,
        SubmissionState.admitted => Icons.check_circle,
        SubmissionState.refused => Icons.do_not_disturb_on_outlined,
        SubmissionState.superseded => Icons.history,
        SubmissionState.notSubmitted => Icons.circle_outlined,
      };
}

/// Something genuinely in the way, with the reason it matters.
///
/// Not a checklist item. Only real blockers appear here, and a settled step is
/// never listed as a satisfied tick — the backend decides which is which.
class _Blocker extends StatelessWidget {
  const _Blocker({required this.step, required this.onResolve});

  final MissingStep step;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.say, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(step.because, style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
          if (onResolve != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onResolve, child: const Text('Sort this out')),
          ],
        ],
      ),
    );
  }
}
