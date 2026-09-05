import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// AN EMPTY OPERATOR SURFACE IS ALMOST NEVER AN EMPTY PLATFORM.
///
/// Every list in this console reads the organisation the session belongs to.
/// A platform operator signs in to Orchestrate Operations, which holds no
/// clients, no mailboxes, no domains and no campaigns of its own — those belong
/// to the businesses that use us, each inside their own organisation. So the
/// console rendered "No clients found", "No mailboxes found", "No import
/// batches found" across nine screens while nine client organisations were
/// operating normally on the other side of the boundary.
///
/// "None found" is a claim about the platform. What is true is narrower and
/// more useful: none HERE, and here is not everywhere. Saying which turns a
/// dead end into a boundary somebody can decide about.
class OpsEmptyState extends StatelessWidget {
  const OpsEmptyState({
    super.key,
    required this.headline,
    this.detail = _boundary,
    this.icon,
  });

  /// What is absent, stated as a fact about this organisation.
  final String headline;

  /// Why. Defaults to the scoping boundary, which is the reason nine times in
  /// ten; pass something else where the emptiness means something different.
  final String detail;

  /// Shown above the headline where the emptiness is good news rather than a
  /// boundary. Most surfaces have nothing to celebrate about being empty.
  final IconData? icon;

  static const String _boundary =
      'This surface reads the organisation you are signed in as. Businesses on '
      'the platform each hold their own, in their own organisation, and are not '
      'reached from here.';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 36, color: AppTheme.emerald),
              const SizedBox(height: 12),
            ],
            Text(
              headline,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.muted),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.subdued, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
