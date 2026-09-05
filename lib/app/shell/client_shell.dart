import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/navigation/workspace_map.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/auth_repository.dart';
import 'package:orchestrate_app/features/client/widgets/command_palette.dart';
import 'package:orchestrate_app/features/client/widgets/feedback_sheet.dart';
import 'package:orchestrate_app/core/release/release_identity.dart';
import 'package:url_launcher/url_launcher.dart';

/// THE WORKSPACE SHELL.
///
/// This used to carry sixteen primary destinations and a status construction
/// that rendered on every one of them — page title, marketing line, and pills
/// reading Onboarded / Plan / Trialing. It cost roughly 250–350px of vertical
/// space before any work appeared, on every surface, restating the account's
/// lifecycle to a person who had already signed in.
///
/// It is gone. Not hidden — the shell no longer has a status-hero
/// responsibility at all. The facts it carried were not discarded:
///
///   Onboarding, once complete, is history and is shown nowhere. Incomplete
///   and actionable, it appears in Today as the specific missing step.
///
///   Plan, trial and billing live in Account. They reach Today only when there
///   is a consequential action — expiry, a failed payment, a service-impacting
///   state.
///
///   Targeting and market coverage live in Business. Healthy coverage is
///   silent; meaningful change appears in Today.
///
/// Three destinations, because there are three things a person does here:
/// orient, work, configure. Everything else is reached by entering the work.
class ClientShell extends StatefulWidget {
  const ClientShell(
      {super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  final AuthRepository _authRepository = AuthRepository();
  bool _signingOut = false;

  static const double _railWidth = 232;
  static const double _railCollapsed = 68;

  /// THREE. Support and Account are affordances, not destinations.
  static const List<_Destination> _destinations = [
    _Destination(
      label: 'Today',
      path: '/client/today',
      // Not Icons.today: it renders blank in the release web build, a
      // codepoint the tree-shaken icon font does not carry. Inbox is also the
      // truer metaphor — Today is the queue of what needs you.
      icon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox,
      // Legacy paths that were conceptually "the operational home".
      absorbs: {'/client/overview', '/client/workspace', '/client/notifications'},
    ),
    // Market sits before Relationships because that is the order the business
    // moves in: understand who may be worth pursuing, then hold a relationship
    // with them. Leads, signals, qualification, intersections and campaigns are
    // NOT destinations — they are how Market knows what it knows, and each one
    // promoted to the sidebar would be a database table wearing a nav item.
    _Destination(
      label: 'Market',
      path: '/client/market',
      icon: Icons.travel_explore_outlined,
      selectedIcon: Icons.travel_explore,
      absorbs: {'/client/leads', '/client/campaigns'},
    ),
    _Destination(
      label: 'Relationships',
      path: '/client/relationships',
      icon: Icons.hub_outlined,
      selectedIcon: Icons.hub,
      // Opportunities, replies, meetings and outreach were all views of, or
      // events inside, a relationship. They stop being destinations.
      absorbs: {
        '/client/opportunities',
        '/client/contacts',
        '/client/replies',
        '/client/meetings',
        '/client/operations',
        '/client/outreach',
      },
    ),
    _Destination(
      label: 'Business',
      path: '/client/business',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune,
      absorbs: {
        '/client/representation',
        '/client/business-identity',
        '/client/infrastructure',
        '/client/mailbox',
        '/client/trust',
        '/client/records',
      },
    ),
  ];

  bool _isSelected(_Destination d) {
    final path = widget.currentPath;
    if (path == d.path || path.startsWith('${d.path}/')) return true;
    return d.absorbs.any((p) => path == p || path.startsWith('$p/'));
  }

  Future<void> _signOut(BuildContext context) async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await _authRepository.logout();
    } catch (_) {
      // Signing out locally must succeed even when the server call does not.
    } finally {
      await AuthSessionController.instance.clear();
      if (context.mounted) context.go('/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;
    // THE RETURN, RENDERED ONCE FOR THE WHOLE ESTATE.
    //
    // The shell already knows the route, so it is the only place that can
    // answer "what contains this" without every screen being taught to answer
    // it for itself. Twenty client surfaces had no return of any kind; adding
    // twenty back buttons would have made twenty more opinions instead of one.
    //
    // A landing gets none, because there is nothing above it.
    final parent = semanticParentOf(widget.currentPath);

    // AN OPAQUE FLOOR UNDER THE ROUTED SURFACE.
    //
    // This is what "clicking the logo does nothing" actually was. Workspace
    // surfaces are lists and panels; almost none of them paints a background.
    // When the route changed, the incoming surface painted only its own
    // content and the outgoing one's pixels stayed on the canvas underneath —
    // so the rail moved, the URL moved, and the screen still showed the page
    // the person had just left.
    //
    // Keying it on the path matters as much as the colour: without a key
    // Flutter reuses the element for the whole content region across routes,
    // and scroll offsets and half-built state carry from one surface into the
    // next. With it, each destination is unambiguously a new subtree that
    // covers what came before.
    // A NEW LAYER PER DESTINATION, NOT JUST A NEW SUBTREE.
    //
    // Demonstrated rather than guessed: after navigating, forcing a resize —
    // which forces a full re-raster — cleared the previous screen instantly.
    // The widget tree was always correct. The pixels were stale.
    //
    // That is also why an opaque background alone did nothing: a region the
    // engine believes unchanged is never redrawn, so a colour that is never
    // painted covers nothing. The retained raster is the thing that needs a
    // new identity, so the boundary is keyed on the route — a new key cannot
    // inherit the previous destination's layer.
    final content = RepaintBoundary(
      key: ValueKey('surface:${widget.currentPath}'),
      child: ColoredBox(
        color: AppTheme.publicBackground,
        child: SelectionArea(
          child: parent == null
              ? widget.child
                  : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SurfaceReturn(
                      title: titleOf(widget.currentPath),
                      area: areaOf(widget.currentPath),
                      parent: parent,
                    ),
                    Expanded(child: widget.child),
                  ],
                ),
        ),
      ),
    );

    return Theme(
      data: AppTheme.lightTheme,
      child: LayoutBuilder(builder: (context, constraints) {
        final size = Workspace.sizeOf(context);
        final phone = size.isPhone;

        return CommandPaletteHost(
          child: Scaffold(
            // The workspace is a light surface. It previously inherited the
            // dark auth canvas, which rendered the content text dark-on-dark.
            backgroundColor: AppTheme.publicBackground,
            bottomNavigationBar: phone ? _BottomBar(
              destinations: _destinations,
              isSelected: _isSelected,
            ) : null,
            appBar: phone
                ? AppBar(
                    title: Text(_currentLabel()),
                    backgroundColor: AppTheme.publicSurface,
                    foregroundColor: AppTheme.publicText,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.search, size: 20),
                        tooltip: 'Search and actions',
                        onPressed: () => CommandPaletteHost.open(context),
                      ),
                      _AccountButton(
                          session: session,
                          currentPath: widget.currentPath,
                          signingOut: _signingOut,
                          onSignOut: () => _signOut(context)),
                    ],
                    bottom: const PreferredSize(
                      preferredSize: Size.fromHeight(1),
                      child: Divider(height: 1, color: AppTheme.publicLine),
                    ),
                  )
                : null,
            body: phone
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: content,
                  )
                : Row(
                    children: [
                      _Rail(
                        width: size == WorkspaceSize.compact
                            ? _railCollapsed
                            : _railWidth,
                        collapsed: size == WorkspaceSize.compact,
                        destinations: _destinations,
                        isSelected: _isSelected,
                        currentPath: widget.currentPath,
                        session: session,
                        signingOut: _signingOut,
                        onSignOut: () => _signOut(context),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
                          child: content,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      }),
    );
  }

  String _currentLabel() {
    for (final d in _destinations) {
      if (_isSelected(d)) return d.label;
    }
    return 'Orchestrate';
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
    this.absorbs = const {},
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;

  /// Legacy paths that now resolve inside this destination, so a deep link
  /// still highlights the right place while redirects propagate.
  final Set<String> absorbs;
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.width,
    required this.collapsed,
    required this.destinations,
    required this.isSelected,
    required this.session,
    required this.signingOut,
    required this.onSignOut,
    required this.currentPath,
  });

  final String currentPath;
  final double width;
  final bool collapsed;
  final List<_Destination> destinations;
  final bool Function(_Destination) isSelected;
  final AuthSessionController session;
  final bool signingOut;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppTheme.publicSurface,
        border: Border(right: BorderSide(color: AppTheme.publicLine)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The mark returns home. It looked like a logo and behaved like
            // decoration, which is the one thing a logo in a workspace is
            // never allowed to be.
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/client/today'),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(collapsed ? 14 : 20, 18, 14, 18),
                  child: Row(
                    children: [
                      BrandAssets.symbol(context, size: 22),
                      if (!collapsed) ...[
                        const SizedBox(width: 10),
                        Text('Orchestrate',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (final d in destinations)
              _RailItem(
                destination: d,
                selected: isSelected(d),
                collapsed: collapsed,
              ),
            const SizedBox(height: 12),
            _RailAction(
              icon: Icons.search,
              label: 'Search',
              collapsed: collapsed,
              onTap: () => CommandPaletteHost.open(context),
            ),
            const Spacer(),
            _RailAction(
              icon: Icons.help_outline,
              label: 'Support',
              collapsed: collapsed,
              onTap: () => context.go('/client/support'),
            ),
            const Divider(height: 20, color: AppTheme.publicLine),
            Padding(
              padding: EdgeInsets.fromLTRB(collapsed ? 10 : 12, 0, 12, 14),
              child: collapsed
                  ? Center(
                      child: _AccountButton(
                          session: session,
                          currentPath: currentPath,
                          signingOut: signingOut,
                          onSignOut: onSignOut))
                  : Row(
                      children: [
                        _AccountButton(
                            session: session,
                            currentPath: currentPath,
                            signingOut: signingOut,
                            onSignOut: onSignOut),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                session.workspaceName.trim().isNotEmpty
                                    ? session.workspaceName.trim()
                                    : 'Workspace',
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                session.email,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppTheme.publicMuted,
                                        fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.collapsed,
  });

  final _Destination destination;
  final bool selected;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      margin: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 12, vertical: 2),
      padding: EdgeInsets.symmetric(
          horizontal: collapsed ? 0 : 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppTheme.publicAccentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        mainAxisAlignment:
            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(selected ? destination.selectedIcon : destination.icon,
              size: 19,
              color: selected ? AppTheme.publicAccent : AppTheme.publicMuted),
          if (!collapsed) ...[
            const SizedBox(width: 12),
            Text(
              destination.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color:
                        selected ? AppTheme.publicAccent : AppTheme.publicText,
                  ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      selected: selected,
      button: true,
      child: Tooltip(
        message: collapsed ? destination.label : '',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go(destination.path),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: collapsed ? label : '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            margin:
                EdgeInsets.symmetric(horizontal: collapsed ? 10 : 12, vertical: 2),
            padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 12, vertical: 9),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: AppTheme.publicMuted),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.publicMuted)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The account layer's entry point.
///
/// Authority, plan, billing and security live behind this rather than in the
/// operational navigation. They describe the business's relationship with
/// Orchestrate, not the work being done today.
class _AccountButton extends StatefulWidget {
  const _AccountButton({
    required this.session,
    required this.signingOut,
    required this.onSignOut,
    this.currentPath = '',
  });

  final AuthSessionController session;
  final bool signingOut;
  final VoidCallback onSignOut;

  /// Where the person is, sent with feedback so a report about a page does not
  /// have to describe which page.
  final String currentPath;

  @override
  State<_AccountButton> createState() => _AccountButtonState();
}

class _AccountButtonState extends State<_AccountButton> {
  ReleaseIdentity? version;

  AuthSessionController get session => widget.session;
  bool get signingOut => widget.signingOut;
  VoidCallback get onSignOut => widget.onSignOut;
  String get currentPath => widget.currentPath;

  @override
  void initState() {
    super.initState();
    // Read once. Every surface that shows a version shows this one.
    ReleaseIdentity.load().then((r) {
      if (mounted) setState(() => version = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = session.fullName.trim();
    final initials = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).take(2).map((p) => p[0]).join()
        : (session.email.isNotEmpty ? session.email[0].toUpperCase() : '?');

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 40),
      onSelected: (value) async {
        if (value == 'signout') {
          onSignOut();
        } else if (value == 'feedback') {
          await FeedbackSheet.open(context, surface: currentPath);
        } else if (value == 'rate') {
          final destination = StoreListing.ratingDestination();
          if (destination != null) {
            // externalApplication so it opens the store app itself where one
            // exists, rather than the web page inside a browser tab.
            await launchUrl(destination, mode: LaunchMode.externalApplication);
          }
        } else {
          context.go(value);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          height: 34,
          child: Text(session.email,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.publicMuted)),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
            value: '/account/people',
            child: Text('People & authority')),
        const PopupMenuItem(
            value: '/account/plan', child: Text('Plan & billing')),
        const PopupMenuItem(
            value: '/account/security', child: Text('Account & security')),
        const PopupMenuDivider(),
        // FEEDBACK, RATE AND VERSION LIVE HERE.
        //
        // In the account menu rather than in the workspace, because none of
        // them is work — they are things a person does about the product
        // rather than in it, and a workspace that carries them starts carrying
        // everything.
        const PopupMenuItem(value: 'feedback', child: Text('Tell us something')),
        // Only where there is a listing to open. Web has none, and Windows
        // holds a Partner Center reservation rather than a published product,
        // so neither shows a Rate action rather than showing one that goes
        // nowhere.
        if (StoreListing.ratingDestination() != null)
          PopupMenuItem(
            value: 'rate',
            child: Text('Rate on ${StoreListing.ratingStoreName()}'),
          ),
        PopupMenuItem(
          enabled: false,
          height: 30,
          child: Text(
            version == null
                ? 'Orchestrate'
                : version!.isUnknown
                    ? 'Orchestrate — version unavailable'
                    : 'Orchestrate ${version!.label}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.publicMuted),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'signout',
          child: Text(signingOut ? 'Signing out…' : 'Sign out'),
        ),
      ],
      child: CircleAvatar(
        radius: 15,
        backgroundColor: AppTheme.publicAccentSoft,
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.publicAccent),
        ),
      ),
    );
  }
}

/// Phone navigation. The same three destinations, reachable with a thumb.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.destinations, required this.isSelected});

  final List<_Destination> destinations;
  final bool Function(_Destination) isSelected;

  @override
  Widget build(BuildContext context) {
    final selectedIndex =
        destinations.indexWhere(isSelected).clamp(0, destinations.length - 1);
    return NavigationBar(
      selectedIndex: selectedIndex,
      height: 62,
      backgroundColor: AppTheme.publicSurface,
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (i) => context.go(destinations[i].path),
      destinations: [
        for (final d in destinations)
          NavigationDestination(
            icon: Icon(d.icon, size: 20),
            selectedIcon: Icon(d.selectedIcon, size: 20),
            label: d.label,
          ),
      ],
    );
  }
}

/// Where you are, and the way back out.
///
/// Deliberately not a browser Back button. It goes to what CONTAINS this
/// surface, which is an answer that exists even when a person arrived on a
/// link and has no history to go back through — the case that strands people.
class _SurfaceReturn extends StatelessWidget {
  const _SurfaceReturn({
    required this.title,
    required this.area,
    required this.parent,
  });

  final String? title;
  final WorkspaceArea? area;
  final String parent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final areaLabel = area?.label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            onTap: () => context.go(parent),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chevron_left,
                      size: 18, color: AppTheme.publicMuted),
                  const SizedBox(width: 2),
                  Text(
                    // Named, not "Back". Back is where you came from; this is
                    // where this surface belongs, and saying which is the
                    // difference between orientation and a guess.
                    areaLabel ?? 'Workspace',
                    style: text.bodySmall?.copyWith(color: AppTheme.publicMuted),
                  ),
                ],
              ),
            ),
          ),
          if (title != null) ...[
            const SizedBox(width: 6),
            Text('/', style: text.bodySmall?.copyWith(color: AppTheme.publicLine)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title!,
                  style: text.bodySmall?.copyWith(color: AppTheme.publicText)),
            ),
          ],
        ],
      ),
    );
  }
}
