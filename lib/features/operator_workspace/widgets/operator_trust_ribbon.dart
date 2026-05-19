import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import '../models/cognition_models.dart';

/// Always-on trust ribbon at the top of every operator screen.
/// Reads vault adapter, provider health rollup, DNS verified count,
/// and OAuth re-auth required count from the cognition composition
/// endpoint. Never claims state it cannot prove —
/// OPERATOR_WORKSPACE_SPECIFICATION.md §5.1.
class OperatorTrustRibbon extends StatelessWidget {
  const OperatorTrustRibbon({super.key, this.ribbon, this.loading = false});

  final TrustRibbon? ribbon;
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
            _TrustPill(
              label: 'Trust',
              valueWidget: const _Dot(color: AppTheme.subdued),
              caption: 'always-on posture',
            ),
            if (loading)
              const _TrustPill(
                  label: 'Loading', value: '…', caption: 'reading services'),
            if (ribbon != null) ..._ribbonChildren(ribbon!),
          ],
        ),
      ),
    );
  }

  List<Widget> _ribbonChildren(TrustRibbon r) {
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
        label: 'Providers',
        value: '${r.providersHealthy} / ${r.providersTotal}',
        caption: 'healthy mailboxes',
        tone: r.providersTotal == 0
            ? _Tone.neutral
            : r.providersHealthy == r.providersTotal
                ? _Tone.ok
                : _Tone.warning,
      ),
      _TrustPill(
        label: 'DNS',
        value: '${r.dnsVerified} / ${r.dnsTotal}',
        caption: 'sending domains verified',
        tone: r.dnsTotal == 0
            ? _Tone.neutral
            : r.dnsVerified == r.dnsTotal
                ? _Tone.ok
                : _Tone.warning,
      ),
      _TrustPill(
        label: 'OAuth',
        value: '${r.oauthReauthRequired} reauth',
        caption: 'mailboxes awaiting re-authorization',
        tone: r.oauthReauthRequired == 0 ? _Tone.ok : _Tone.warning,
      ),
    ];
  }
}

enum _Tone { neutral, ok, warning }

class _TrustPill extends StatelessWidget {
  const _TrustPill({
    required this.label,
    this.value,
    this.valueWidget,
    required this.caption,
    this.tone = _Tone.neutral,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;
  final String caption;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (tone) {
      case _Tone.ok:
        color = AppTheme.emerald;
        break;
      case _Tone.warning:
        color = AppTheme.amber;
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
          if (valueWidget != null)
            valueWidget!
          else
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
