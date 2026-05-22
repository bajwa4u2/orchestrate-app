import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';

/// Shared desktop shell for the focused flows — sign in, create workspace,
/// email verification, password reset, setup, and subscribe.
///
/// Before this, each of those screens was a bare `Scaffold > Center >
/// SingleChildScrollView > ConstrainedBox`, which on a maximized desktop
/// rendered as a small card floating dead-centre in a large empty canvas
/// with no product chrome. [AuthShell] gives every focused flow the same
/// composition language as [PublicShell]: a shared header, the same
/// background, the same outer frame width, consistent side framing, a slim
/// footer, and top-anchored (not vertically floating) content — so public,
/// auth, and onboarding read as one coherent desktop product system.
///
/// [maxContentWidth] is the inner measure for the flow's own content (the
/// form / two-column composition); the header and footer always span the
/// full [_frameWidth] frame so chrome is identical across every flow.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.child,
    this.maxContentWidth = 1120,
  });

  final Widget child;
  final double maxContentWidth;

  static const double _frameWidth = 1320;
  static const double _footerReserveHeight = 96;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.publicBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _AuthShellHeader(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: (constraints.maxHeight -
                                        _footerReserveHeight)
                                    .clamp(0, double.infinity)
                                    .toDouble(),
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      28, 44, 28, 44),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        maxWidth: maxContentWidth),
                                    child: child,
                                  ),
                                ),
                              ),
                            ),
                            const _AuthShellFooter(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Focused header — the brand mark plus a single quiet escape hatch back to
/// the public site. Deliberately lighter than the full public navigation so
/// the auth/onboarding forms keep their focus, while still sharing the same
/// bar height, framing, and background as [PublicShell].
class _AuthShellHeader extends StatelessWidget {
  const _AuthShellHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.publicBackground,
        border: Border(bottom: BorderSide(color: AppTheme.publicLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AuthShell._frameWidth),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    onTap: () => context.go('/'),
                    child: SizedBox(
                      height: 38,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: BrandAssets.logo(context, height: 24),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.publicMuted,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                    ),
                    label: const Text('Back to site'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slim footer — keeps trust/legal continuity with the public footer
/// without reproducing its full column grid inside a focused flow.
class _AuthShellFooter extends StatelessWidget {
  const _AuthShellFooter();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppTheme.publicMuted);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.publicBackground,
        border: Border(top: BorderSide(color: AppTheme.publicLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AuthShell._frameWidth),
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('© 2026 Aura Platform LLC', style: muted),
                _FooterTextLink(
                    label: 'Terms', onTap: () => context.go('/legal/terms')),
                _FooterTextLink(
                    label: 'Privacy',
                    onTap: () => context.go('/legal/privacy')),
                _FooterTextLink(
                    label: 'Contact', onTap: () => context.go('/contact')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterTextLink extends StatelessWidget {
  const _FooterTextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.publicMuted, fontSize: 13),
        ),
      ),
    );
  }
}
