import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/ui/screen_memory.dart';
import 'package:orchestrate_app/data/repositories/auth_repository.dart';
import 'package:orchestrate_app/app/routing/app_router.dart';

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
    // Auth screens sit outside both shells, so they claim the Android Back
    // gesture here. The path comes from the router rather than a parameter
    // because every caller already knows it as the route it was reached by.
    return UpBackHandler(
      path: GoRouterState.of(context).uri.path,
      child: Theme(
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
                                    padding: const EdgeInsets.fromLTRB(
                                        28, 44, 28, 44),
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
      ),
    );
  }
}

/// Focused header — the brand mark plus one quiet way out. Deliberately
/// lighter than the full public navigation so the auth/onboarding forms keep
/// their focus, while still sharing the same bar height, framing, and
/// background as [PublicShell].
///
/// THE WAY OUT DEPENDS ON WHETHER ANYONE IS SIGNED IN.
///
/// This bar carried one control, "Back to site", for every flow it hosts.
/// For a signed-out visitor on sign-in or registration that is right. For a
/// signed-in person it was a **dead control**: the router sends an
/// authenticated client with unfinished setup straight back to
/// `/client/setup` from `/`, and an unverified one back to verification, so
/// the button bounced them to where they already were.
///
/// Which left the real problem underneath it. Setup sits outside the client
/// shell — correctly, it is a focused flow — so it has no sidebar and
/// therefore no sign-out. Somebody who signed in as the wrong account, or
/// who simply does not want to continue, had no legitimate way to leave.
/// Their only exits were closing the tab or clearing site data.
///
/// So: signed out, the bar still offers the public site. Signed in, the same
/// slot offers sign-out — the one control that actually works from here.
/// The public site stays reachable through the brand mark, which has always
/// been a link.
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A PHONE IS NOT A NARROW DESKTOP.
          //
          // At 400 px this bar overflowed by 149 px: the lockup was given
          // unbounded width by the Align above it, so the wordmark's own
          // Flexible never bound and the Row simply ran off the screen. It
          // scales down here instead of truncating, because a company that
          // introduces itself as "Orchest" is worse than one whose name is a
          // little smaller than intended.
          final compact = constraints.maxWidth < 560;
          return Padding(
            padding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 28, vertical: compact ? 10 : 14),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AuthShell._frameWidth),
                child: SizedBox(
                  height: compact ? 44 : 52,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radius),
                          onTap: () => context.go('/'),
                          child: SizedBox(
                            height: compact ? 30 : 38,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: BrandAssets.operatorLockup(
                                context,
                                symbolSize: compact ? 22 : 28,
                                fontSize: compact ? 17 : 22,
                                darkSurface: true,
                                color: AppTheme.publicOnDark,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const _AuthShellExit(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The one control in the focused header, and which one it is depends on
/// whether a session exists.
///
/// Sign-out is the same sequence the workspace shell performs, deliberately
/// and not by coincidence: ask the server, then clear the session whatever
/// the server said, then forget what was on screen, then land on sign-in.
/// Being unable to reach the server must never strand somebody signed in on
/// a machine they are trying to leave.
class _AuthShellExit extends StatefulWidget {
  const _AuthShellExit();

  @override
  State<_AuthShellExit> createState() => _AuthShellExitState();
}

class _AuthShellExitState extends State<_AuthShellExit> {
  final AuthRepository _authRepository = AuthRepository();
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    final operator = AuthSessionController.instance.surface == 'operator';
    try {
      await _authRepository.logout();
    } catch (_) {
      // Signing out locally must succeed even when the server call does not.
    } finally {
      await AuthSessionController.instance.clear();
      // Nothing one business was shown is held while nobody is signed in.
      ScreenMemory.forget();
      if (mounted) context.go(operator ? '/ops/login' : '/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthSessionController.instance,
      builder: (context, _) {
        final signedIn = AuthSessionController.instance.isAuthenticated;
        final style = TextButton.styleFrom(
          foregroundColor: AppTheme.publicOnDarkMuted,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        );
        if (!signedIn) {
          return TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.arrow_back, size: 16),
            style: style,
            label: const Text('Back to site'),
          );
        }
        return TextButton.icon(
          onPressed: _signingOut ? null : _signOut,
          icon: const Icon(Icons.logout, size: 16),
          style: style,
          label: Text(_signingOut ? 'Signing out…' : 'Sign out'),
        );
      },
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
