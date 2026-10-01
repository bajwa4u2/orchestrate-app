import 'package:flutter/material.dart';
import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/public/widgets/public_app_acquisition.dart';
import 'package:orchestrate_app/features/public/widgets/execution_visual_chapters.dart';
import 'package:orchestrate_app/app/routing/app_router.dart';

/// Public pages rebuilt in direction B (DD-26). They sit on paper; every
/// other public page keeps the estate's dark field until it is rebuilt.
const Set<String> publicPaperPaths = {'/', '/pricing', '/how-it-works'};

/// DD-26 public rebuild: every public page now sits on paper.
const bool publicAllPaper = true;

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
    return UpBackHandler(
      path: widget.currentPath,
      child: Theme(
        data: AppTheme.lightTheme,
        child: Scaffold(
          backgroundColor: AppTheme.publicCanvas,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                PublicHeader(
                  currentPath: widget.currentPath,
                  onHome: () {
                    if (_publicScrollController.hasClients) {
                      _publicScrollController.jumpTo(0);
                    }
                    context.go('/');
                  },
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
                          // One paper ground under the whole page, so no
                          // seam shows where two painted areas meet at a
                          // fractional pixel (founder's 125% display).
                          child: ColoredBox(
                          color: Ob.paper,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: shellWidth,
                              maxWidth: shellWidth,
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              children: [
                                // Scrolls with the page rather than pinning a
                                // second bar under the header: on a short
                                // window the two together took a third of the
                                // screen before any content (founder's 943x489).
                                ColoredBox(
                                  color: Ob.paper,
                                  child: PublicAppAcquisition(
                                    config:
                                        orchestratePublicAppAcquisitionConfig,
                                    currentPath: widget.currentPath,
                                  ),
                                ),
                                ColoredBox(
                                  // DD-26: the rebuilt pages sit on paper,
                                  // full bleed; the estate's dark pages keep
                                  // the canvas beneath them.
                                  color: publicAllPaper ||
                                          publicPaperPaths
                                              .contains(widget.currentPath)
                                      ? Ob.paper
                                      : Colors.transparent,
                                  child: ConstrainedBox(
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
                                ),
                                if (widget.currentPath != '/intake' &&
                                    widget.currentPath != '/contact' &&
                                    !widget.currentPath.startsWith('/legal/'))
                                  const _CommercialClosingBand(),
                                // DD-26 F1: the supporters are a line in
                                // the footer now, not a band of their own.
                                const _PublicFooter(),
                              ],
                            ),
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
      ),
    );
  }
}

/// BRAND, THE TWO THINGS A VISITOR CAN DO, AND EVERYTHING ELSE BEHIND A MENU.
///
/// This carried six centred links — Execution, Readiness, Signals, Trust,
/// Plans, Talk to us — across the top of every public page. Six competing
/// destinations at the moment of arrival is noise: it asks a visitor to choose
/// a section before they know what the product is, and it competes with the two
/// actions that actually matter on this surface.
///
/// Nothing became unreachable. The footer carries the section pages and the
/// menu carries all of them including Pricing, which the footer does not. So
/// this is one button in place of six links rather than a removal of
/// navigation.
class PublicHeader extends StatelessWidget {
  const PublicHeader({super.key, required this.currentPath, required this.onHome});

  final String currentPath;
  final VoidCallback onHome;

  bool _isActive(List<String> paths) => paths.contains(currentPath);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Ob.paper,
        border: Border(bottom: BorderSide(color: Ob.line)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 28,
            vertical: MediaQuery.sizeOf(context).height < 640 ? 6 : 16),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PublicShell._maxFrameWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tablet = constraints.maxWidth >= 720;

                final brand = InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  onTap: onHome,
                  child: SizedBox(
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: BrandAssets.operatorLockup(
                        context,
                        symbolSize: 34,
                        fontSize: 26,
                        darkSurface: false,
                        color: Ob.ink,
                        // Never shortened. Everywhere else a lockup may fade
                        // when space runs out; the company name on its own
                        // front door may not, so it scales instead.
                        allowTruncation: false,
                      ),
                    ),
                  ),
                );

                final wide = constraints.maxWidth >= 1080;
                final link = TextButton.styleFrom(
                  foregroundColor: Ob.inkSoft,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                );
                final actions = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (wide) ...[
                      TextButton(
                        style: link,
                        onPressed: () => context.go('/how-it-works'),
                        child: const Text('One customer, start to paid'),
                      ),
                      TextButton(
                        style: link,
                        onPressed: () => context.go('/pricing'),
                        child: const Text('Pricing'),
                      ),
                    ],
                    TextButton(
                      style: link,
                      onPressed: () => context.go('/auth/login'),
                      child: const Text('Sign in'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => context.go('/auth/register'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Ob.ink,
                        foregroundColor: Ob.onInk,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: const Text('Start with your business'),
                    ),
                  ],
                );

                // Slimmer on a short window, where every pixel of a pinned
                // header is one less of the page.
                final short = MediaQuery.sizeOf(context).height < 640;
                return SizedBox(
                  height: short ? 56 : 72,
                  // THE TRAILING GROUP BELONGS ON THE RIGHT EDGE.
                  //
                  // This was `[Flexible(brand), Spacer(), Flexible(actions)]`.
                  // Three flex children, each with the default flex of 1, so
                  // the Spacer was handed ONE THIRD of the free space rather
                  // than absorbing it — and a loose Flexible that uses less
                  // than its share does not give the remainder back. The
                  // buttons ended up stranded a few hundred pixels short of
                  // the right edge on a wide window.
                  //
                  // No flex children now, so spaceBetween means what it says:
                  // first child on the left edge, last on the right. The caps
                  // keep both earlier fixes intact — the wordmark still scales
                  // rather than losing its last letters, and the buttons still
                  // scale rather than running off the edge — while adding up to
                  // well under the full width so the row cannot overflow.
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.30,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: brand,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!tablet)
                            TextButton(
                              style: TextButton.styleFrom(
                                  foregroundColor: Ob.inkSoft),
                              onPressed: () => context.go('/auth/login'),
                              child: const Text('Sign in'),
                            ),
                          if (tablet) ...[
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.62,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: actions,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          _PublicMenuButton(currentPath: currentPath),
                        ],
                      ),
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

/// THE PAGE'S ENDING, F1 (DD-26 footer, founder 2026-10-01: "f1 is good,
/// ending white card is too big vertically").
///
/// Paper all the way down. The close is one compact white card: a line and
/// the two next steps, no taller than it needs to be. It paints its own paper
/// so the page never shows a dark band between content and footer.
class _CommercialClosingBand extends StatelessWidget {
  const _CommercialClosingBand();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Ob.paper,
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 40),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PublicShell._maxFrameWidth),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              decoration: BoxDecoration(
                color: Ob.card,
                borderRadius: BorderRadius.circular(Ob.radiusPanel),
                boxShadow: Ob.lift,
              ),
              child: LayoutBuilder(builder: (context, constraints) {
                final stacked = constraints.maxWidth < 820;
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Set up free. See who needs you before you pay.',
                        style: Ob.name(stacked ? 21 : 24)),
                    const SizedBox(height: 4),
                    Text(
                        'Orchestrate starts finding businesses as soon as your '
                        'setup is done.',
                        style: Ob.body(14.5)),
                  ],
                );
                final actions = Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => context.go('/auth/register'),
                      child: const Text('Start with your business'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go('/contact'),
                      child: const Text('Ask us anything'),
                    ),
                  ],
                );
                return stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [copy, const SizedBox(height: 14), actions])
                    : Row(children: [
                        Expanded(child: copy),
                        const SizedBox(width: 24),
                        actions,
                      ]);
              }),
            ),
          ),
        ),
      );
}

/// The footer: two quiet lines (founder, 2026-10-01).
///
/// The header already names Orchestrate, so the footer carries no brand
/// block, and three uneven columns of 3, 3 and 5 links left empty space under
/// two of them. So it is one line of where to go, policies at its end, and
/// one line of who supports and makes it. Billing and account deletion are
/// one tap away through All policies; both addresses still work directly.
class _PublicFooter extends StatelessWidget {
  const _PublicFooter();

  @override
  Widget build(BuildContext context) {
    Widget link(String label, String path) => _FooterLink(
        label: label, onTap: () => context.push(path));
    final site = Wrap(
      spacing: 28,
      runSpacing: 4,
      children: [
        link('One customer, start to paid', '/how-it-works'),
        link('Pricing', '/pricing'),
        link('Trust', '/trust'),
        link('About', '/about'),
        link('Contact', '/contact'),
        link('Check your domain', '/diagnostics?focus=dns-readiness'),
      ],
    );
    final policies = Wrap(
      spacing: 20,
      runSpacing: 4,
      children: [
        link('Terms', '/legal/terms'),
        link('Privacy', '/legal/privacy'),
        link('All policies', '/legal'),
      ],
    );
    return Container(
      width: double.infinity,
      color: Ob.paper,
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: PublicShell._maxFrameWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 1, color: Ob.line),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth >= 920) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: site),
                      const SizedBox(width: 24),
                      policies,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [site, const SizedBox(height: 10), policies],
                );
              }),
              const SizedBox(height: 14),
              Container(height: 1, color: Ob.line),
              const SizedBox(height: 14),
              // Founder, 1 Oct 2026: startup programmes appear on the company
              // site only, never in a product.
              const _PublicFooterBottomRow(),
            ],
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
          style: Ob.strong(14.5),
        ),
        const SizedBox(height: 8),
        ...links,
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Grows with its words: a fixed height clipped longer labels on a
        // phone ("One customer, start to paid").
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 28),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              label,
              style: Ob.body(14, color: Ob.inkSoft),
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
      color: Ob.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ob.radiusControl),
        side: const BorderSide(color: Ob.line),
      ),
      onSelected: (value) => context.go(value),
      itemBuilder: (context) => [
        // DD-26: the pages that exist in the new design, nothing else.
        _menuItem('One customer, start to paid', '/how-it-works',
            _isActive(const ['/how-it-works'])),
        _menuItem('Pricing', '/pricing', _isActive(const ['/pricing'])),
        _menuItem('Trust', '/trust', _isActive(const ['/trust'])),
        _menuItem('About', '/about', _isActive(const ['/about'])),
        _menuItem(
          'Contact',
          '/contact',
          _isActive(const ['/contact', '/intake']),
        ),
        const PopupMenuDivider(),
        // FOUND ON A PHYSICAL PIXEL, NOT IN THE CODE.
        //
        // These two were the only items in the menu with no style, so their
        // text fell through to the ambient light theme's default ink and
        // rendered dimmer than the six browsing links above them — on a dark
        // panel, the visual language of a disabled control. Both work; they
        // only looked unavailable. The two ways into the product read as the
        // least available things on the public surface.
        //
        // They are not browsing links, so they do not share that styling.
        // Signing in is where a returning operator is going, and it is now the
        // brightest thing here. Start setup is the commitment, and carries the
        // accent that marks it as the primary act.
        _accountItem('Sign in', '/auth/login', Ob.ink),
        _accountItem('Start with your business', '/auth/register', Ob.ink),
      ],
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Ob.card,
          borderRadius: BorderRadius.circular(Ob.radiusControl),
          border: Border.all(color: Ob.lineStrong),
        ),
        child: const Icon(Icons.menu, size: 20, color: Ob.ink),
      ),
    );
  }

  /// The account actions, which are destinations rather than browsing.
  PopupMenuItem<String> _accountItem(String label, String value, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String label, String value, bool active) {
    return PopupMenuItem<String>(
      value: value,
      child: Text(
        label,
        style: TextStyle(
          color: active ? Ob.ink : Ob.inkMuted,
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
      slug: 'colophon',
      label: 'Colophon',
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

  // One line: the company, then the other products (DD-26 F1).
  @override
  Widget build(BuildContext context) {
    final company = InkWell(
      onTap: () => _orchOpenExternal(_kOrchCompanyUrl),
      child: Text('A product of Aura Platform LLC',
          style: Ob.body(13, color: Ob.inkMuted)),
    );
    return LayoutBuilder(builder: (context, constraints) {
      // On a phone the company and the products take a line each, so no
      // line ever ends on a dangling dot.
      if (constraints.maxWidth < 520) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            company,
            const SizedBox(height: 6),
            const _OrchEcosystemLinkRow(currentSlug: _kCurrentSlug),
          ],
        );
      }
      return Wrap(
        spacing: 14,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          company,
          Text('·', style: Ob.body(13, color: Ob.inkFaint)),
          const _OrchEcosystemLinkRow(currentSlug: _kCurrentSlug),
        ],
      );
    });
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
            Text('·', style: Ob.body(13, color: Ob.inkFaint)),
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
      fontFamily: Ob.sans,
      color: isCurrent ? Ob.ink : Ob.inkMuted,
      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
      fontSize: 13,
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
