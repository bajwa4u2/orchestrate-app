import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'system_status.dart';

/// THE STRIP ACROSS THE TOP OF EVERY OPERATOR SCREEN.
///
/// Four facts about the things Orchestrate runs on, each one actionable: where
/// credentials live, how many mailboxes are healthy, how many sending domains
/// are verified, and how many mailboxes are waiting to be re-authorised.
///
/// It states nothing it cannot prove. Where a count is zero out of zero it says
/// so plainly rather than showing a reassuring green — nothing configured is
/// not the same as everything healthy.
class SystemStatusRibbon extends StatelessWidget {
  const SystemStatusRibbon({super.key, this.status, this.loading = false});

  final SystemStatus? status;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.panel,
        border: Border(
          bottom: BorderSide(color: AppTheme.line),
        ),
      ),
      child: DefaultTextStyle(
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppTheme.subdued, height: 1.3) ??
            const TextStyle(),
        child: Wrap(
          spacing: 18,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // No decorative "Trust ●" pill. It asserted a posture without
            // measuring anything, which is the decoration this workspace is
            // being rebuilt to remove.
            if (loading)
              const _TrustPill(
                  label: 'Reading', value: '…', caption: 'checking services'),
            if (status != null) ..._pills(status!),
          ],
        ),
      ),
    );
  }

  List<Widget> _pills(SystemStatus r) {
    return [
      _TrustPill(
        label: 'Vault',
        value: r.vaultAdapter,
        caption: r.vaultWarning
            ? 'memory adapter in production — investigate'
            : 'credential vault adapter',
        tone: r.vaultWarning ? _Tone.warning : _Tone.neutral,
      ),
      _TrustPill(
        label: 'Mailboxes',
        value: '${r.mailboxesHealthy} / ${r.mailboxesTotal}',
        caption: 'healthy mailboxes',
        tone: r.mailboxesTotal == 0
            ? _Tone.neutral
            : r.mailboxesHealthy == r.mailboxesTotal
                ? _Tone.ok
                : _Tone.warning,
      ),
      _TrustPill(
        label: 'Domains',
        value: '${r.domainsVerified} / ${r.domainsTotal}',
        caption: 'sending domains verified',
        tone: r.domainsTotal == 0
            ? _Tone.neutral
            : r.domainsVerified == r.domainsTotal
                ? _Tone.ok
                : _Tone.warning,
      ),
      _TrustPill(
        label: 'Re-auth',
        value: '${r.mailboxesAwaitingReauth}',
        caption: 'mailboxes awaiting re-authorisation',
        tone: r.mailboxesAwaitingReauth == 0 ? _Tone.ok : _Tone.warning,
      ),
    ];
  }
}

enum _Tone { neutral, ok, warning }

class _TrustPill extends StatelessWidget {
  const _TrustPill({
    required this.label,
    this.value,
    required this.caption,
    this.tone = _Tone.neutral,
  });

  final String label;
  final String? value;
  final String caption;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (tone) {
      case _Tone.ok:
        color = AppTheme.coVerdant;
        break;
      case _Tone.warning:
        color = AppTheme.coSun;
        break;
      case _Tone.neutral:
        color = AppTheme.subdued;
    }
    return Tooltip(
      message: caption,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.subdued),
          ),
          const SizedBox(width: 6),
          Text(
            value ?? '',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
