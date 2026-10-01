import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/theme/ob.dart';
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
          // DD-26: sign-in and sign-up sit on paper (board S05).
          backgroundColor: Ob.paper,
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
                                          // DD-26: setup is one path with its own
                                          // progress; the old four-step band that
                                          // named a different path is retired.
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
        color: Ob.paper,
        border: Border(bottom: BorderSide(color: Ob.line)),
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
                                darkSurface: false,
                                color: Ob.ink,
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
          foregroundColor: Ob.inkSoft,
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

/// Slim footer: legal continuity with the public footer, on paper.
class _AuthShellFooter extends StatelessWidget {
  const _AuthShellFooter();

  @override
  Widget build(BuildContext context) {
    // DD-26: paper all the way down, like the public footer.
    final muted = Ob.body(13, color: Ob.inkMuted);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Ob.paper,
        border: Border(top: BorderSide(color: Ob.line)),
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
          style: Ob.body(13, color: Ob.inkMuted),
        ),
      ),
    );
  }
}
