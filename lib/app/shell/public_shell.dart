import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/public/widgets/public_app_acquisition.dart';
import 'package:orchestrate_app/features/public/widgets/execution_visual_chapters.dart';

class PublicShell extends StatefulWidget {
  const PublicShell(
      {super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  static const double _maxFrameWidth = 1320;
  static const double _footerReserveHeight = 168;

  // PublicShell is the canonical chrome for every public route. The
  // router never mounts it on a path that should bypass the chrome —
  // every GoRoute that wraps a child in PublicShell wants the full
  // header / footer / scroll experience. Previously a whitelist here
  // silently dropped the chrome (and the SingleChildScrollView) for
  // any path it did not know about, which caused new public routes
  // such as /why-orchestrate, /how-orchestrate-operates,
  // /trust-architecture, /for-evaluators, /activation, and
  // /account-deletion to render shell-less + unscrollable ("frozen").
  // Always rendering the chrome is the correct posture: a route that
  // wants different chrome must mount its own scaffold instead of
  // using PublicShell.

  @override
  State<PublicShell> createState() => _PublicShellState();
}

class _PublicShellState extends State<PublicShell> {
  late final ScrollController _publicScrollController;

  @override
  void initState() {
    super.initState();
    _publicScrollController = ScrollController();
  }

  @override
  void dispose() {
    _publicScrollController.dispose();
    super.dispose();
  }

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
              _PublicHeader(
                currentPath: widget.currentPath,
                onHome: () {
                  if (_publicScrollController.hasClients) {
                    _publicScrollController.jumpTo(0);
                  }
                  context.go('/');
                },
              ),
              PublicAppAcquisition(
                config: orchestratePublicAppAcquisitionConfig,
                currentPath: widget.currentPath,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final viewportWidth = MediaQuery.sizeOf(context).width;
                    final shellWidth = constraints.hasBoundedWidth
                        ? constraints.maxWidth
                        : viewportWidth;
                    return Scrollbar(
                      controller: _publicScrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      interactive: true,
                      child: SingleChildScrollView(
                        controller: _publicScrollController,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: shellWidth,
                            maxWidth: shellWidth,
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: (constraints.maxHeight -
                                          PublicShell._footerReserveHeight)
                                      .clamp(0, double.infinity)
                                      .toDouble(),
                                ),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: PublicShell._maxFrameWidth,
                                    ),
                                    child: SizedBox(
                                      width: shellWidth.clamp(
                                        0,
                                        PublicShell._maxFrameWidth,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 28,
                                        ),
                                        child: widget.child,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.currentPath != '/intake' &&
                                  widget.currentPath != '/contact' &&
                                  !widget.currentPath.startsWith('/legal/'))
                                const _CommercialClosingBand(),
                              const _CommercializationSupportBand(),
                              const _PublicFooter(),
                            ],
                          ),
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

class _PublicHeader extends StatelessWidget {
  const _PublicHeader({required this.currentPath, required this.onHome});

  final String currentPath;
  final VoidCallback onHome;

  bool _isActive(List<String> paths) => paths.contains(currentPath);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.publicSecondaryField,
        border: Border(bottom: BorderSide(color: Color(0xFF2A4A56))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 9),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PublicShell._maxFrameWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 1120;
                final tablet = constraints.maxWidth >= 720;

                final brand = InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  onTap: onHome,
                  child: SizedBox(
                    height: 34,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: BrandAssets.operatorLockup(
                        context,
                        symbolSize: 30,
                        fontSize: 24,
                        darkSurface: true,
                        color: AppTheme.publicOnDark,
                      ),
                    ),
                  ),
                );

                final nav = Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HeaderLink(
                      label: 'Execution',
                      active: _isActive(const ['/product']),
                      onTap: () => context.go('/product'),
                    ),
                    _HeaderLink(
                      label: 'Readiness',
                      active: _isActive(const ['/how-it-works']),
                      onTap: () => context.go('/how-it-works'),
                    ),
                    _HeaderLink(
                      label: 'Signals',
                      active: _isActive(const ['/lead-sourcing']),
                      onTap: () => context.go('/lead-sourcing'),
                    ),
                    _HeaderLink(
                      label: 'Trust',
                      active: _isActive(const ['/trust-compliance']),
                      onTap: () => context.go('/trust-compliance'),
                    ),
                    _HeaderLink(
                      label: 'Plans',
                      active: _isActive(const ['/pricing']),
                      onTap: () => context.go('/pricing'),
                    ),
                    _HeaderLink(
                      label: 'Talk to us',
                      active: _isActive(const ['/contact', '/intake']),
                      onTap: () => context.go('/intake'),
                    ),
                  ],
                );

                final actions = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.go('/auth/login'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.publicOnDark,
                        side: const BorderSide(color: Color(0xFF416170)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radius)),
                      ),
                      child: const Text('Sign in'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => context.go('/auth/register'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.publicAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radius)),
                      ),
                      child: const Text('Start setup'),
                    ),
                  ],
                );

                if (desktop) {
                  return SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        SizedBox(width: 190, child: brand),
                        Expanded(child: Center(child: nav)),
                        SizedBox(
                          width: 246,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: actions,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(child: brand),
                      if (tablet) ...[
                        OutlinedButton(
                          onPressed: () => context.go('/auth/login'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.publicOnDark,
                            side: const BorderSide(
                              color: Color(0xFF416170),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radius),
                            ),
                          ),
                          child: const Text('Sign in'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: () => context.go('/auth/register'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.publicAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radius),
                            ),
                          ),
                          child: const Text('Start setup'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _PublicMenuButton(currentPath: currentPath),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CommercialClosingBand extends StatelessWidget {
  const _CommercialClosingBand();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 28),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0E1723), Color(0xFF173A3A)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PublicShell._maxFrameWidth),
            child: LayoutBuilder(builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CONTINUE THE COMMERCIAL PATH',
                      style: TextStyle(
                          color: Color(0xFF67D2C4),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4)),
                  const SizedBox(height: 10),
                  Text('Move from understanding to execution.',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                  const SizedBox(height: 7),
                  const Text(
                      'Talk through readiness, qualification, delivery and the commercial states that matter to your business.',
                      style: TextStyle(color: Color(0xFFB9C8D6), height: 1.5)),
                ],
              );
              final action = FilledButton(
                onPressed: () => context.go('/intake'),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF67D2C4),
                    foregroundColor: const Color(0xFF071311)),
                child: const Text('Talk to Orchestrate'),
              );
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [copy, const SizedBox(height: 18), action])
                  : Row(children: [
                      Expanded(child: copy),
                      const SizedBox(width: 24),
                      action
                    ]);
            }),
          ),
        ),
      );
}

class _CommercializationSupportBand extends StatelessWidget {
  const _CommercializationSupportBand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.publicSupportField,
        border: Border(
          top: BorderSide(color: Color(0xFF2C5960)),
          bottom: BorderSide(color: Color(0xFF2C5960)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: PublicShell._maxFrameWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final copy = const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MADE WITH SUPPORT',
                      style: TextStyle(
                          color: AppTheme.publicAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4)),
                  SizedBox(height: 8),
                  Text(
                      'Orchestrate is being built in a commercialization environment that values durable execution.',
                      style: TextStyle(
                          color: AppTheme.publicOnDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.35)),
                ],
              );
              const marks = OfficialSupportMarks();
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [copy, const SizedBox(height: 16), marks])
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                          Expanded(child: copy),
                          const SizedBox(width: 24),
                          Flexible(child: marks)
                        ]);
            },
          ),
        ),
      ),
    );
  }
}

class _PublicFooter extends StatelessWidget {
  const _PublicFooter();

  @override
  Widget build(BuildContext context) {
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
            constraints:
                const BoxConstraints(maxWidth: PublicShell._maxFrameWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Task #274 — balanced, intentional information architecture.
                // The footer answers five questions (what Orchestrate is,
                // how readiness works, the trust posture, legal obligations,
                // account/billing), each as a comparable column. It is NOT a
                // complete operational index: the ten detailed operational
                // trust policies (mailbox access, reply monitoring, AI usage,
                // credential handling, provider boundaries, suppression,
                // abuse, retention, deliverability) are surfaced on the
                // /trust-compliance hub — reachable from the header "Trust"
                // — rather than as a towering footer column.
                final groups = [
                  _FooterGroup(
                    title: 'Explore execution',
                    links: [
                      _FooterLink(
                          label: 'Product',
                          onTap: () => context.push('/product')),
                      _FooterLink(
                          label: 'Signals and sourcing',
                          onTap: () => context.push('/lead-sourcing')),
                      _FooterLink(
                          label: 'Activation journey',
                          onTap: () => context.push('/how-it-works')),
                      _FooterLink(
                          label: 'DNS readiness check',
                          onTap: () =>
                              context.push('/diagnostics?focus=dns-readiness')),
                    ],
                  ),
                  _FooterGroup(
                    title: 'Readiness + trust',
                    links: [
                      _FooterLink(
                          label: 'Operational answers',
                          onTap: () => context.push('/answers')),
                      _FooterLink(
                          label: 'Trust + compliance',
                          onTap: () => context.push('/trust-compliance')),
                      _FooterLink(
                          label: 'Trust architecture',
                          onTap: () => context.push('/trust-architecture')),
                      _FooterLink(
                          label: 'For evaluators',
                          onTap: () => context.push('/for-evaluators')),
                    ],
                  ),
                  _FooterGroup(
                    title: 'Business + policy',
                    links: [
                      _FooterLink(
                          label: 'Terms',
                          onTap: () => context.push('/legal/terms')),
                      _FooterLink(
                          label: 'Privacy',
                          onTap: () => context.push('/legal/privacy')),
                      _FooterLink(
                          label: 'Billing',
                          onTap: () => context.push('/legal/billing')),
                    ],
                  ),
                  _FooterGroup(
                    title: 'Legal + account',
                    links: [
                      _FooterLink(
                          label: 'Service agreement',
                          onTap: () =>
                              context.push('/legal/service-agreement')),
                      _FooterLink(
                          label: 'Refunds',
                          onTap: () => context.push('/legal/refunds')),
                      _FooterLink(
                          label: 'Account deletion',
                          onTap: () => context.push('/account-deletion')),
                    ],
                  ),
                ];
                // Desktop: all five columns share ONE row as flexible
                // (Expanded) columns, distributed evenly edge-to-edge. They
                // get narrower as the viewport shrinks instead of a fixed
                // 208 px column wrapping onto a lonely second row (the bug
                // that left the 5th column stranded below). The threshold is
                // the width below which five columns can no longer hold their
                // longest label on one line; under it they fall back to a
                // fixed-width wrap (2–3 per row on tablet) and finally a clean
                // single-column stack on mobile.
                final wide = constraints.maxWidth >= 920;
                final groupArea = wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < groups.length; i++) ...[
                            Expanded(child: groups[i]),
                            if (i != groups.length - 1)
                              const SizedBox(width: 24),
                          ],
                        ],
                      )
                    : LayoutBuilder(
                        builder: (context, gridConstraints) {
                          final columnWidth =
                              ((gridConstraints.maxWidth - 20) / 2)
                                  .clamp(0, double.infinity)
                                  .toDouble();
                          return Wrap(
                            alignment: WrapAlignment.start,
                            spacing: 20,
                            runSpacing: 28,
                            children: [
                              for (final g in groups)
                                SizedBox(width: columnWidth, child: g),
                            ],
                          );
                        },
                      );
                // Reconciled 2026-06-01 — see
                // docs/ecosystem/FOOTER_RECONCILIATION_2026-06-01.md
                // in the personal repo. The earlier stacked
                // institutional band beneath the column groups read
                // as a second footer. The ecosystem is now a single
                // bottom-row attribution: the product name over
                // "A product of Aura Platform LLC." on the left,
                // canonical five-link continuity on the right.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, introConstraints) {
                        final stacked = introConstraints.maxWidth < 620;
                        final copy = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ORCHESTRATE',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              'Commercial execution, from prospect to complete.',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        );
                        const description = Text(
                          'A managed path for readiness, relationships, delivery and revenue records.',
                          style: TextStyle(
                              color: AppTheme.publicOnDarkMuted, height: 1.5),
                        );
                        return stacked
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  copy,
                                  const SizedBox(height: 12),
                                  description
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: copy),
                                  const SizedBox(width: 28),
                                  const Expanded(child: description),
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 30),
                    groupArea,
                    const SizedBox(height: 24),
                    Container(height: 1, color: const Color(0xFF263B4A)),
                    const SizedBox(height: 16),
                    const _PublicFooterBottomRow(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterGroup extends StatelessWidget {
  const _FooterGroup({required this.title, required this.links});

  final String title;
  final List<Widget> links;

  @override
  Widget build(BuildContext context) {
    // Width-agnostic footer column. The caller sizes it: an Expanded slot
    // on desktop (all columns share one row and flex) or a fixed-width box
    // in the wrap fallback. Links are a plain Column so a wrapped heading
    // pushes its own links down without bleeding across neighbours.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
        ),
        const SizedBox(height: 8),
        ...links,
      ],
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink(
      {required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor:
            active ? AppTheme.publicOnDark : AppTheme.publicOnDarkMuted,
        backgroundColor: active ? const Color(0xFF1B4050) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        minimumSize: const Size(0, 38),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius)),
        textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
      ),
      child: Text(label),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 28,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB9C8D6),
                    fontSize: 13,
                    height: 1.25,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicMenuButton extends StatelessWidget {
  const _PublicMenuButton({required this.currentPath});

  final String currentPath;

  bool _isActive(List<String> paths) => paths.contains(currentPath);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Open navigation',
      position: PopupMenuPosition.under,
      color: AppTheme.publicSecondaryField,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: const BorderSide(color: Color(0xFF416170)),
      ),
      onSelected: (value) => context.go(value),
      itemBuilder: (context) => [
        _menuItem('Product', '/product', _isActive(const ['/product'])),
        _menuItem(
          'How it works',
          '/how-it-works',
          _isActive(const ['/how-it-works']),
        ),
        _menuItem(
          'Intelligence',
          '/lead-sourcing',
          _isActive(const ['/lead-sourcing']),
        ),
        _menuItem(
          'Trust',
          '/trust-compliance',
          _isActive(const ['/trust-compliance']),
        ),
        _menuItem('Pricing', '/pricing', _isActive(const ['/pricing'])),
        _menuItem(
          'Contact',
          '/intake',
          _isActive(const ['/contact', '/intake']),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '/auth/login',
          child: Text('Sign in'),
        ),
        const PopupMenuItem<String>(
          value: '/auth/register',
          child: Text('Start setup'),
        ),
      ],
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.publicSecondaryField,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: const Color(0xFF416170)),
        ),
        child: const Icon(Icons.menu, size: 20, color: AppTheme.publicOnDark),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String label, String value, bool active) {
    return PopupMenuItem<String>(
      value: value,
      child: Text(
        label,
        style: TextStyle(
          color: active ? AppTheme.publicOnDark : AppTheme.publicOnDarkMuted,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ECOSYSTEM CONTINUITY BAND
// ─────────────────────────────────────────────────────────────────────────────
//
// See docs/ecosystem/ECOSYSTEM_CONTINUITY_ARCHITECTURE.md in the
// personal repo for the doctrine this implements.
//
// Orchestrate's attribution names the product first and the company
// that makes it second: "Orchestrate" over "A product of Aura Platform
// LLC." Naming the company on both lines said the same thing twice and
// left the product itself unnamed. The five canonical links
// appear in doctrine-locked order; the current surface (Orchestrate)
// is the "you are here" link.

class _PublicFooterAttribution extends StatelessWidget {
  const _PublicFooterAttribution();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Orchestrate',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'A product of Aura Platform LLC.',
              style: TextStyle(
                color: AppTheme.publicOnDarkMuted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrchEcosystemEntry {
  const _OrchEcosystemEntry({
    required this.slug,
    required this.label,
    required this.url,
  });
  final String slug;
  final String label;
  final String url;
}

const String _kOrchCompanyUrl = 'https://company.auraplatform.org';

const List<_OrchEcosystemEntry> _kOrchEcosystemLinks = <_OrchEcosystemEntry>[
  _OrchEcosystemEntry(
      slug: 'aura', label: 'Aura', url: 'https://auraplatform.org'),
  _OrchEcosystemEntry(
      slug: 'bajwa-writes',
      label: 'Bajwa Writes',
      url: 'https://bajwawrites.com'),
  _OrchEcosystemEntry(
      slug: 'founder', label: 'Founder', url: 'https://bajwa.auraplatform.org'),
];

/// Bottom row of `_PublicFooter`. Sits beneath the column groups and
/// the single hairline. Institution lockup on the left (linked to the
/// company surface), canonical five-link continuity on the right.
/// One footer container, two layers — same pattern as the founder
/// surface, which is the reference implementation per
/// `docs/ecosystem/FOOTER_RECONCILIATION_2026-06-01.md`.
class _PublicFooterBottomRow extends StatelessWidget {
  const _PublicFooterBottomRow();

  static const String _kCurrentSlug = 'orchestrate';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final lockup = _lockup();
        const links = _OrchEcosystemLinkRow(currentSlug: _kCurrentSlug);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              lockup,
              const Spacer(),
              // Bound the link Wrap's width so it wraps onto additional rows
              // instead of overflowing the Row at narrower "wide" widths
              // (e.g. the 800px test surface). Without this the Wrap is given
              // unbounded width and lays every link on one line.
              Flexible(child: links),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            lockup,
            const SizedBox(height: 10),
            links,
          ],
        );
      },
    );
  }

  Widget _lockup() {
    return InkWell(
      onTap: () => _orchOpenExternal(_kOrchCompanyUrl),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Orchestrate',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'A product of Aura Platform LLC.',
              style: TextStyle(
                color: Color(0xFFB9C8D6),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrchEcosystemLinkRow extends StatelessWidget {
  const _OrchEcosystemLinkRow({required this.currentSlug});
  final String currentSlug;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < _kOrchEcosystemLinks.length; i++) ...[
          if (i > 0)
            const Text('·',
                style: TextStyle(color: Color(0xFF6F8796), fontSize: 11)),
          _OrchEcosystemLink(
            link: _kOrchEcosystemLinks[i],
            currentSlug: currentSlug,
          ),
        ],
      ],
    );
  }
}

class _OrchEcosystemLink extends StatelessWidget {
  const _OrchEcosystemLink({required this.link, required this.currentSlug});
  final _OrchEcosystemEntry link;
  final String currentSlug;

  @override
  Widget build(BuildContext context) {
    final isCurrent = link.slug == currentSlug;
    final style = TextStyle(
      color: isCurrent ? Colors.white : const Color(0xFFB9C8D6),
      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
      fontSize: 11,
      decoration: isCurrent ? TextDecoration.underline : TextDecoration.none,
      decorationColor: AppTheme.publicLine,
      decorationThickness: 1.2,
    );
    if (isCurrent) {
      return Semantics(
        selected: true,
        label: '${link.label} (current surface)',
        child: Text(link.label, style: style),
      );
    }
    return Semantics(
      link: true,
      label: 'Open ${link.label} surface',
      child: InkWell(
        onTap: () => _orchOpenExternal(link.url),
        child: Text(link.label, style: style),
      ),
    );
  }
}

Future<void> _orchOpenExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.platformDefault);
}
