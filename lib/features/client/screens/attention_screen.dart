import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/attention/client_attention.dart';
import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/client/widgets/safe_message_sheet.dart';

/// MAIL THAT ARRIVED FOR THIS BUSINESS AND COULD NOT BE PLACED.
///
/// Not a "Quarantine" destination. Quarantine is a system condition, not a
/// product domain a business should have to learn — this is an Attention view,
/// reached from Today, showing the same correspondence a person would expect to
/// find in their own mailbox.
///
/// Twenty-seven real messages sat where the client could not see them: carrier
/// billing alerts, a named person writing "we should likely talk", conference
/// invitations. Orchestrate held a business's post and decided what they were
/// allowed to know about it. That is the defect this screen closes, and it
/// closes it without granting anything — reading is not admitting, and every
/// consequential act still asks the authority contract.
class AttentionScreen extends StatefulWidget {
  const AttentionScreen({super.key});

  @override
  State<AttentionScreen> createState() => _AttentionScreenState();
}

class _AttentionScreenState extends State<AttentionScreen> {
  final ClientAttention _attention = ClientAttention.instance;
  bool _showSettled = false;

  @override
  void initState() {
    super.initState();
    _attention.addListener(_onChanged);
    if (!_attention.hasAnswer && !_attention.isLoading && _attention.error == null) {
      _attention.load().catchError((Object e) => throw e);
    }
  }

  @override
  void dispose() {
    _attention.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final view = _attention.view;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspaceHeader(
          title: 'Inbound',
          context_: 'Mail that reached your business and has not been placed.',
          onBack: () => context.go('/client/today'),
        ),
        Expanded(child: _body(view)),
      ],
    );
  }

  Widget _body(AttentionView? view) {
    if (_attention.error != null) {
      return _Unavailable(onRetry: () => _attention.refresh());
    }
    if (view == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final mine = view.needsYou;
    final ours = view.waitingOnUs;
    final noted = view.observational;
    final settled = view.settled;

    // A healthy inbox is a real state and gets said plainly, not left as an
    // empty list a person has to interpret.
    if (mine.isEmpty && ours.isEmpty && noted.isEmpty && settled.isEmpty) {
      return const QuietState(
        message: 'Nothing arrived that we could not place.',
        hint: 'Mail Orchestrate cannot match to a relationship shows up here.',
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (mine.isNotEmpty)
          WorkspaceBand(
            title: 'NEEDS YOU',
            children: [for (final item in mine) _Row(item: item, onDone: _refresh)],
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: QuietState(message: 'Nothing here needs a decision from you.'),
          ),
        if (ours.isNotEmpty)
          WorkspaceBand(
            title: 'WITH ORCHESTRATE',
            children: [for (final item in ours) _Row(item: item, onDone: _refresh)],
          ),
        // Arrived, and nobody owes work about it. Shown anyway: mail that
        // reached this business and happens to be inconsequential is still
        // theirs to know about.
        if (noted.isNotEmpty)
          WorkspaceBand(
            title: 'FOR YOUR RECORDS',
            children: [for (final item in noted) _Row(item: item, onDone: _refresh)],
          ),
        if (settled.isNotEmpty) ...[
          const SizedBox(height: 8),
          // History stays reachable. Resolution removes work owed; it does not
          // erase what happened.
          TextButton.icon(
            onPressed: () => setState(() => _showSettled = !_showSettled),
            icon: Icon(_showSettled ? Icons.expand_less : Icons.expand_more, size: 18),
            label: Text(_showSettled
                ? 'Hide what is already dealt with'
                : 'Show ${settled.length} already dealt with'),
          ),
          if (_showSettled)
            WorkspaceBand(
              title: 'DEALT WITH',
              children: [for (final item in settled) _Row(item: item, onDone: _refresh)],
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  void _refresh() => _attention.refresh();
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onDone});

  final AttentionItem item;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return WorkspaceRow(
      title: item.title,
      detail: item.why,
      meta: _meta,
      tone: switch (item.state) {
        AttentionState.resolved => RowTone.neutral,
        _ => item.isMine ? RowTone.attention : RowTone.waiting,
      },
      onTap: () => _open(context),
      action: item.isMine && item.state != AttentionState.resolved
          ? const Icon(Icons.chevron_right, size: 18, color: AppTheme.publicMuted)
          : null,
    );
  }

  /// Sender and when, plus who owes the work — because a person reading a list
  /// of their own mail should not have to guess which ones are theirs.
  String get _meta {
    final parts = <String>[
      if (item.counterparty != null) item.counterparty!,
      if (item.occurredAt != null) _when(item.occurredAt!),
      if (item.state == AttentionState.resolved)
        'dealt with'
      else if (item.state == AttentionState.inReview)
        'with Orchestrate'
      else if (item.owner == AttentionOwner.operator ||
          item.owner == AttentionOwner.system)
        'with Orchestrate',
    ];
    return parts.join(' · ');
  }

  static String _when(DateTime at) {
    final days = DateTime.now().difference(at).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return '$days days ago';
    return '${at.year}-${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')}';
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // A focus boundary, so keyboard and screen-reader navigation stay inside
      // the sheet while it is open rather than wandering the list behind it.
      useSafeArea: true,
      builder: (_) => SafeMessageSheet(item: item, onDone: onDone),
    );
  }
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
          Text('We could not load what is waiting.',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Nothing has changed and nothing was lost. Your mail is where it '
            'was; we just could not read the list.',
            style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
