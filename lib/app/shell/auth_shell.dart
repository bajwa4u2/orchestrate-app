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
    this.setupFlow = false,
  });

  final Widget child;
  final double maxContentWidth;
  final bool setupFlow;

  static const double _frameWidth = 1320;
  static const double _footerReserveHeight = 96;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.publicCanvas,
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
                                  padding:
                                      const EdgeInsets.fromLTRB(28, 44, 28, 44),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        maxWidth: maxContentWidth),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (setupFlow) ...[
                                          const _SetupJourneyHeader(),
                                          const SizedBox(height: 26),
                                        ],
                                        child,
                                      ],
                                    ),
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
        color: AppTheme.publicSecondaryField,
        border: Border(bottom: BorderSide(color: Color(0xFF2A4A56))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AuthShell._frameWidth),
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
                        child: BrandAssets.operatorLockup(
                          context,
                          symbolSize: 28,
                          fontSize: 22,
                          darkSurface: true,
                          color: AppTheme.publicOnDark,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.publicOnDarkMuted,
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
/// Setup-only context rail. It keeps the real activation inputs visible while
/// a person works through the form without inventing progress percentages.
class _SetupJourneyHeader extends StatelessWidget {
  const _SetupJourneyHeader();

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('01', 'Business identity'),
      ('02', 'Market scope'),
      ('03', 'Mailbox + domain'),
      ('04', 'Ready to execute'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.publicDeepField,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: const Color(0xFF294858)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SETUP PATH',
              style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4)),
          const SizedBox(height: 6),
          Text('Establish the inputs Orchestrate needs to execute responsibly.',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppTheme.publicOnDark)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              return compact
                  ? Wrap(
                      spacing: 16,
                      runSpacing: 10,
                      children: [for (final step in steps) _SetupStep(step)],
                    )
                  : Row(
                      children: [
                        for (var i = 0; i < steps.length; i++) ...[
                          Expanded(child: _SetupStep(steps[i])),
                          if (i < steps.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward,
                                  size: 14, color: Color(0xFF5C8994)),
                            ),
                        ],
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep(this.step);
  final (String, String) step;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(step.$1,
            style: const TextStyle(
                color: Color(0xFF6FD3C3),
                fontSize: 11,
                fontWeight: FontWeight.w800)),
        const SizedBox(width: 7),
        Flexible(
          child: Text(step.$2,
              style: const TextStyle(
                  color: AppTheme.publicOnDarkMuted,
                  fontSize: 12,
                  height: 1.3)),
        ),
      ],
    );
  }
}

class _AuthShellFooter extends StatelessWidget {
  const _AuthShellFooter();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppTheme.publicOnDarkMuted);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.publicFooterField,
        border: Border(top: BorderSide(color: Color(0xFF263B4A))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AuthShell._frameWidth),
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
              ?.copyWith(color: AppTheme.publicOnDarkMuted, fontSize: 13),
        ),
      ),
    );
  }
}
