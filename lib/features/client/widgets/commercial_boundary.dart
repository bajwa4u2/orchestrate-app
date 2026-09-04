import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/commercial/client_capabilities.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';

/// WHY AN ACTION DID NOT PROCEED, WHEN THE REASON IS COMMERCIAL.
///
/// Deliberately narrow. Orchestrate refuses things for at least four unrelated
/// reasons, and they need four answers:
///
///   PLAN_ACTIVATION_REQUIRED   the service is not commercially active
///   ACTOR_UNAUTHORIZED         nobody holds the authority to do this
///   DESTINATION_NOT_READY      the recipient boundary refused
///   EXECUTION_HELD             the rails are held
///
/// Only the first is solved by paying. Showing the other three as "upgrade your
/// plan" would sell a business a subscription that cannot fix its problem, and
/// would quietly teach people that Orchestrate's governance is a paywall. This
/// widget renders the first and refuses to render the others — if a refusal
/// arrives that is not commercial, it is not this widget's to explain.
class CommercialBoundary extends StatelessWidget {
  const CommercialBoundary({
    super.key,
    required this.capability,
    this.compact = false,
  });

  /// One of [Capabilities]. Nothing is shown when it is permitted.
  final String capability;

  /// A single line rather than a panel, for use beside an action.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final refusal = ClientCapabilities.instance.refusalFor(capability);
    if (refusal == null) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    final lapsed =
        ClientCapabilities.instance.entitlement?.state == EntitlementState.lapsed;

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2, right: 8),
              child: Icon(Icons.lock_outline, size: 15, color: AppTheme.publicMuted),
            ),
            Expanded(
              child: Text(refusal.why ?? '',
                  style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.publicLine),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1, right: 10),
                child: Icon(Icons.lock_outline, size: 16, color: AppTheme.publicMuted),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The server's own sentence. A lapsed business is told its
                    // work is still there; a new one is told what activation
                    // turns on. Neither is told to upgrade.
                    Text(
                      lapsed ? 'Your plan has lapsed' : 'This needs an active plan',
                      style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(refusal.why ?? '',
                        style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => context.go('/account/plan'),
                child: const Text('Plan & billing'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(refusal.resolution ?? '',
                    style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The commercial state of the organisation, said once, where it belongs.
///
/// Used in Plan & billing. Deliberately NOT used across the workspace: a banner
/// on every page is how a product becomes a paywall with software attached, and
/// the boundary belongs at the action, not above it.
class EntitlementSummary extends StatelessWidget {
  const EntitlementSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final capabilities = ClientCapabilities.instance;
    final entitlement = capabilities.entitlement;
    final text = Theme.of(context).textTheme;

    if (capabilities.error != null) {
      return _panel(
        text,
        'We could not read your plan',
        'Nothing has changed about what your business is entitled to — we just '
            'could not check it.',
        null,
      );
    }
    if (entitlement == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: SizedBox(
          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(text, entitlement.says, entitlement.because,
            // How the organisation came to be entitled, when it was not bought.
            // A grant is not a subscription and is not presented as one.
            entitlement.source == EntitlementSource.paid
                ? null
                : entitlement.source.label),

        const SizedBox(height: 20),

        Text('What Orchestrate charges for',
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        // The model, from the server. No plan cards, no amounts — there is no
        // approved price, and inventing one here is how the last catalog
        // became doctrine.
        for (final part in capabilities.projection?.model ?? const [])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('· ${part.means}',
                style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
          ),

        const SizedBox(height: 16),
        Text(capabilities.projection?.note ?? '',
            style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
      ],
    );
  }

  Widget _panel(TextTheme text, String title, String body, String? footnote) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.publicLine),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(body, style: text.bodySmall?.copyWith(color: AppTheme.publicMuted)),
          if (footnote != null) ...[
            const SizedBox(height: 8),
            Text(footnote, style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}
