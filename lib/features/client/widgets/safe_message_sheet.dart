import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/attention/client_attention.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/ui/governed_action.dart';

/// ONE MESSAGE, SAFELY, AND WHAT MAY BE DONE ABOUT IT.
///
/// Layered the way the questions arrive: what happened, why it needs anyone,
/// the message itself, and only then the legitimate next acts. Provenance is
/// depth on demand rather than a permanent column — this is a business reading
/// their own post, not an enterprise ticketing queue.
///
/// The body is fetched now and never stored. It arrives already stripped of
/// scripts, active content and remote images by the same renderer the operator
/// surface uses: a second rendering path would be a second set of safety bugs,
/// and only one of them would ever get fixed.
class SafeMessageSheet extends StatefulWidget {
  const SafeMessageSheet({super.key, required this.item, required this.onDone});

  final AttentionItem item;

  /// Called after anything that changes what is waiting.
  final VoidCallback onDone;

  @override
  State<SafeMessageSheet> createState() => _SafeMessageSheetState();
}

class _SafeMessageSheetState extends State<SafeMessageSheet> {
  SafeMessage? _message;
  Object? _error;
  bool _busy = false;
  Refusal? _refusal;
  bool _showProvenance = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.actions.contains(AttentionAction.reviewMessage)) _read();
  }

  Future<void> _read() async {
    setState(() {
      _error = null;
      _message = null;
    });
    try {
      final message = await ClientAttention.instance.review(widget.item.id);
      if (mounted) setState(() => _message = message);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final item = widget.item;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // SUMMARY — what happened.
          Semantics(
            header: true,
            child: Text(item.title,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (item.counterparty != null) 'From ${item.counterparty}',
              if (item.occurredAt != null) _when(item.occurredAt!),
            ].join(' · '),
            style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 16),

          // WHY IT NEEDS ATTENTION — the backend's own sentence, verbatim.
          _Panel(
            // Never colour alone: the icon and the wording both carry the
            // state, so it survives a screen reader and a monochrome display.
            icon: item.isMine ? Icons.person_outline : Icons.support_agent_outlined,
            accent: item.isMine ? AppTheme.amber : AppTheme.publicMuted,
            title: item.isMine ? 'Needs you' : 'With Orchestrate',
            body: item.why,
          ),
          const SizedBox(height: 16),

          // THE MESSAGE.
          _content(text),

          if (_refusal != null) RefusalNotice(refusal: _refusal!),

          const SizedBox(height: 20),
          _actions(),

          const SizedBox(height: 16),
          // PROVENANCE — depth on demand.
          TextButton.icon(
            onPressed: () => setState(() => _showProvenance = !_showProvenance),
            icon: Icon(_showProvenance ? Icons.expand_less : Icons.expand_more, size: 18),
            label: const Text('How we know this'),
          ),
          if (_showProvenance) _provenance(text),
        ],
      ),
    );
  }

  Widget _content(TextTheme text) {
    if (!widget.item.actions.contains(AttentionAction.reviewMessage)) {
      return _Panel(
        icon: Icons.drafts_outlined,
        accent: AppTheme.publicMuted,
        title: 'The original is not retrievable',
        body: 'We recorded that this message arrived, but no mailbox reference '
            'was kept, so the content cannot be fetched.',
      );
    }

    if (_error != null) {
      // The item survives a failed read. Losing the evidence because a fetch
      // failed would be the worse outcome by far.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Panel(
            icon: Icons.cloud_off_outlined,
            accent: AppTheme.rose,
            title: 'Reading is unavailable right now',
            body: 'The message is still in your mailbox and still on record here. '
                'We just could not retrieve it to show you.',
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _read, child: const Text('Try again')),
        ],
      );
    }

    final message = _message;
    if (message == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (message.ok == false) {
      return _Panel(
        icon: Icons.block_outlined,
        accent: AppTheme.rose,
        title: 'Not available to you',
        body: message.refusalReason ??
            'This message did not arrive in a mailbox belonging to your business.',
      );
    }

    if (!message.contentAvailable) {
      return _Panel(
        icon: Icons.drafts_outlined,
        accent: AppTheme.publicMuted,
        title: 'The content is gone',
        // Honest, and better than a silent empty body: we know a message
        // existed, and we know we cannot show it.
        body: message.contentNote,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.publicSurface,
            border: Border.all(color: AppTheme.publicLine),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: SelectableText(
            message.content ?? '',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message.contentNote,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.publicMuted),
        ),
        // Never "no attachments" on evidence nobody checked.
        if (message.hasAttachments == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Whether this has attachments has not been determined. '
              'Attachments are not yet handled here.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.publicMuted),
            ),
          ),
      ],
    );
  }

  Widget _actions() {
    final item = widget.item;
    final offered = item.actions
        .where((a) =>
            a != AttentionAction.reviewMessage && a != AttentionAction.viewProvenance)
        .toList();

    if (offered.isEmpty) {
      return Text(
        item.isMine
            ? 'Nothing to do here yet.'
            : 'Nothing here is yours to settle. Orchestrate will deal with it.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppTheme.publicMuted),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final action in offered)
          if (action == AttentionAction.openRelationship)
            OutlinedButton(
              onPressed: item.relationshipId == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      context.go('/client/relationships/${item.relationshipId}');
                    },
              child: Text(action.label),
            )
          else
            GovernedAction(
              label: action.label,
              // Placing a message on a relationship asserts a business fact
              // about a counterparty. Everything else here is a note to self.
              consequence: action == AttentionAction.associateWithRelationship
                  ? Consequence.externallyCommunicated
                  : Consequence.reversibleInternal,
              busy: _busy,
              onPressed: _busy ? null : () => _settle(action),
            ),
      ],
    );
  }

  Widget _provenance(TextTheme text) {
    final item = widget.item;
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
          _fact(text, 'Arrived in', 'a mailbox belonging to your business'),
          _fact(text, 'Placed on a relationship',
              item.relationshipId == null ? 'no' : 'yes'),
          _fact(text, 'Owed by', switch (item.owner) {
            AttentionOwner.client => 'you',
            AttentionOwner.operator => 'Orchestrate',
            AttentionOwner.system => 'a rule, with no human decision',
            AttentionOwner.none => 'nobody',
          }),
          if (item.resolvedBy != null)
            _fact(text, 'Settled by', switch (item.resolvedBy) {
              'SYSTEM_RULE' => 'a rule that could prove what this was',
              'CLIENT' => 'you',
              'OPERATOR' => 'Orchestrate',
              _ => item.resolvedBy!,
            }),
          const SizedBox(height: 8),
          Text(
            'Reading a message places nothing and admits nothing. Anything that '
            'would change what your business is committed to asks separately.',
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
              width: 170,
              child: Text(label,
                  style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
            ),
            Expanded(child: Text(value, style: text.bodySmall)),
          ],
        ),
      );

  Future<void> _settle(AttentionAction action) async {
    setState(() {
      _busy = true;
      _refusal = null;
    });
    try {
      final result =
          await ClientAttention.instance.settle(id: widget.item.id, action: action);
      if (!mounted) return;
      final refusal = Refusal.fromResponse(result);
      if (refusal != null) {
        // A governed refusal, shown with the reason and the way out. The
        // backend wrote both for the person reading them.
        setState(() {
          _busy = false;
          _refusal = Refusal(
            reason: [
              result['refusal']?['why'],
              result['refusal']?['resolution'],
              result['reason'],
            ].whereType<String>().where((s) => s.isNotEmpty).join(' '),
            code: (result['refusal']?['code'] ?? result['code'])?.toString(),
          );
        });
        return;
      }
      widget.onDone();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _refusal = Refusal.unexpected(e);
      });
    }
  }

  static String _when(DateTime at) =>
      '${at.year}-${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';
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
