import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/ui/governed_action.dart';
import 'package:orchestrate_app/data/repositories/client/client_relationship_workspace_repository.dart';

/// ONE COMMERCIAL LIFECYCLE, NOT FIVE MODULES.
///
/// Agreement, obligation, acceptance, invoice and payment are five backend
/// concepts and were heading for five screens. They are not five things a
/// person does — they are stages of one undertaking, and the backend already
/// names that undertaking: the Engagement.
///
/// The client had `Engagement` in zero files. That absence is exactly why
/// commerce felt like separate modules: without the container, each stage had
/// nowhere to belong except its own destination.
///
/// So this is a strip, not a section index. A person should be able to see
/// where the engagement has got to, what is owed, what has been accepted and
/// what has been paid, without navigating anywhere.
class EngagementLifecycle extends StatelessWidget {
  const EngagementLifecycle({
    super.key,
    required this.engagement,
    required this.timeline,
  });

  final EngagementSummary engagement;
  final List<TimelineEvent> timeline;

  /// Derived from what actually happened, never from a stored funnel position
  /// somebody has to remember to advance.
  _Reached get _reached {
    bool any(List<String> needles) => timeline.any((e) {
          final t = e.type.toLowerCase();
          return needles.any(t.contains);
        });
    return _Reached(
      proposed: any(['agreement_proposed', 'agreement.proposed', 'proposed']),
      agreed: any(['agreement_accepted', 'acceptance', 'accepted']),
      obligations: any(['obligation']),
      invoiced: any(['invoice_issued', 'invoice']),
      paid: any(['payment']),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reached = _reached;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(engagement.title,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            _StateText(state: engagement.state),
          ],
        ),
        const SizedBox(height: 14),
        _LifecycleStrip(reached: reached),
        const SizedBox(height: 16),
        _StageDetail(reached: reached),
      ],
    );
  }
}

class _Reached {
  const _Reached({
    required this.proposed,
    required this.agreed,
    required this.obligations,
    required this.invoiced,
    required this.paid,
  });

  final bool proposed;
  final bool agreed;
  final bool obligations;
  final bool invoiced;
  final bool paid;

  List<({String label, bool done})> get stages => [
        (label: 'Proposed', done: proposed),
        (label: 'Agreed', done: agreed),
        (label: 'Obligations', done: obligations),
        (label: 'Invoiced', done: invoiced),
        (label: 'Paid', done: paid),
      ];
}

/// The strip. Deliberately typographic rather than five cards in a row —
/// cards would make five stages look like five places to go.
class _LifecycleStrip extends StatelessWidget {
  const _LifecycleStrip({required this.reached});

  final _Reached reached;

  @override
  Widget build(BuildContext context) {
    final stages = reached.stages;
    return LayoutBuilder(builder: (context, c) {
      final tight = c.maxWidth < 520;
      return Wrap(
        spacing: tight ? 10 : 0,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < stages.length; i++) ...[
            _StagePip(label: stages[i].label, done: stages[i].done),
            if (!tight && i < stages.length - 1)
              Container(
                width: 26,
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: stages[i + 1].done
                    ? AppTheme.publicAccent.withValues(alpha: 0.5)
                    : AppTheme.publicLine,
              ),
          ],
        ],
      );
    });
  }
}

class _StagePip extends StatelessWidget {
  const _StagePip({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          done ? Icons.check_circle : Icons.circle_outlined,
          size: 14,
          color: done ? AppTheme.publicAccent : AppTheme.publicLine,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: done ? AppTheme.publicText : AppTheme.publicMuted,
                fontWeight: done ? FontWeight.w600 : FontWeight.w400,
              ),
        ),
      ],
    );
  }
}

/// What the next act would cost, made visible before it is taken.
///
/// Not a confirmation dialog. The action itself says what it does — drafting
/// is quiet, proposing goes to the counterparty, issuing claims money.
class _StageDetail extends StatelessWidget {
  const _StageDetail({required this.reached});

  final _Reached reached;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final (String message, String? action, Consequence consequence) = switch (reached) {
      _ when !reached.proposed => (
          'Nothing has been put to the counterparty yet.',
          'Draft agreement',
          Consequence.reversibleInternal,
        ),
      _ when !reached.agreed => (
          'Proposed. Waiting on the counterparty.',
          null,
          Consequence.externallyCommunicated,
        ),
      _ when !reached.obligations => (
          'Agreed. Nothing has been recorded as owed yet.',
          'Record what is owed',
          Consequence.reversibleInternal,
        ),
      _ when !reached.invoiced => (
          'Obligations are open. Nothing has been billed.',
          'Draft invoice',
          Consequence.reversibleInternal,
        ),
      _ when !reached.paid => (
          'Invoiced. Payment has not been recorded.',
          null,
          Consequence.financial,
        ),
      _ => ('Complete.', null, Consequence.reversibleInternal),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(message,
                style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
          ),
          if (action != null) ...[
            const SizedBox(width: 12),
            GovernedAction(
              label: action,
              consequence: consequence,
              // Authoring acts are not reachable from the client yet: they
              // are governed operator surfaces today. Showing the action
              // disabled states the shape of the lifecycle honestly, and
              // saying why is the difference between an explanation and a
              // dead control.
              onPressed: null,
              unavailableBecause: 'Not yet available from your workspace',
            ),
          ],
        ],
      ),
    );
  }
}

class _StateText extends StatelessWidget {
  const _StateText({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (state) {
      'OPEN' => ('Open', AppTheme.publicAccent),
      'COMPLETED' => ('Completed', AppTheme.emerald),
      'ABANDONED' => ('Abandoned', AppTheme.publicMuted),
      _ => (state, AppTheme.publicMuted),
    };
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: color, fontWeight: FontWeight.w600),
    );
  }
}
