import 'package:orchestrate_app/core/ui/screen_memory.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/navigation/workspace_map.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/theme/workspace_theme.dart';
import 'package:orchestrate_app/data/repositories/auth_repository.dart';
import 'package:orchestrate_app/features/client/widgets/command_palette.dart';
import 'package:orchestrate_app/features/client/widgets/feedback_sheet.dart';
import 'package:orchestrate_app/core/release/release_identity.dart';
import 'package:orchestrate_app/app/routing/app_router.dart';
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
      absorbs: {
        '/client/overview',
        '/client/workspace',
        '/client/notifications'
      },
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

  /// True on the account layer, which no bottom-bar destination represents.
  bool get _inAccountLayer =>
      areaOf(widget.currentPath) == WorkspaceArea.account;

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
      // Nothing one business was shown is held while nobody is signed in.
      // ScreenMemory also drops everything on the next read once the client
      // id changes; this is the same rule applied at the boundary, so the
      // answers do not sit in memory waiting for that to happen.
      ScreenMemory.forget();
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
        color: Ws.canvas,
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

    return UpBackHandler(
      path: widget.currentPath,
      child: Theme(
        // THE WORKSPACE HAS ITS OWN THEME NOW.
        //
        // This was AppTheme.lightTheme — the marketing site's ThemeData, which
        // is why the authenticated product drifted to white cards on grey while
        // the public surfaces gained depth, and why it carried a 54px headline
        // and 16px of padding inside every button into an environment somebody
        // works in all day.
        data: Ws.data,
        child: LayoutBuilder(builder: (context, constraints) {
          // Measured against the constraints this shell actually has, and in
          // the text that has to fit inside them. With the OS enlarging text the
          // window stays the same size while everything in it grows, so the rail
          // collapses at the width where the work beside it would otherwise be
          // squeezed rather than at a pixel count that assumes ordinary text.
          final size = Workspace.sizeOf(context, constraints.maxWidth);
          final phone = size.isPhone;

          return CommandPaletteHost(
            child: Scaffold(
              // A ground, not a page. Panels sit on it and are separated by
              // the surface step rather than by borders alone.
              backgroundColor: Ws.canvas,
              // THE BAR ALWAYS HIGHLIGHTS SOMETHING, SO IT MUST NOT BE
              // SHOWN WHERE NOTHING IT LISTS IS CURRENT.
              //
              // `indexWhere` answers -1 when no destination matches, and the
              // clamp turned that into 0 — so every account surface, and
              // Workspace settings with it, told the operator they were on
              // Today. Found on a Pixel: the bar said Today while the screen
              // said Account & security.
              //
              // The account layer is not one of these four. It is reached from
              // the avatar and carries its own return, so the honest rendering
              // is no bar rather than a false one.
              bottomNavigationBar: phone && !_inAccountLayer
                  ? _BottomBar(
                      destinations: _destinations,
                      isSelected: _isSelected,
                    )
                  : null,
              appBar: phone
                  ? AppBar(
                      title: Text(_currentLabel()),
                      backgroundColor: Ws.surface,
                      foregroundColor: Ws.ink,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      actions: [
                        IconButton(
                          icon: Icon(Icons.search,
                              size: Workspace.icon(context, 20)),
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
                        child: Divider(height: 1, color: Ws.hairline),
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
                          // Measured against the window rather than against the
                          // text-scaled content width, so a wide monitor keeps
                          // its navigation labels when the OS enlarges text.
                          width: Workspace.railIsCollapsed(
                                  context, constraints.maxWidth)
                              ? _railCollapsed
                              : Workspace.railWidth(context),
                          collapsed: Workspace.railIsCollapsed(
                              context, constraints.maxWidth),
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
      ),
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
    final workspaceName = session.workspaceName.trim();

    return Container(
      width: width,
      decoration: const BoxDecoration(
        // THE DEEP FIELD, WHICH IS THE JOIN TO THE PUBLIC PRODUCT.
        //
        // The public site puts its most deliberate moments on this field.
        // Using it for the rail is what makes signing in read as descending
        // into the same product rather than arriving at a different one, and
        // it gives the work area a ground to be light against, which a white
        // rail beside a white page could never do.
        color: Ws.field,
        border: Border(right: BorderSide(color: Ws.fieldDeep)),
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
                  padding: EdgeInsets.fromLTRB(collapsed ? 14 : 18, 16, 14, 4),
                  child: Row(
                    children: [
                      // Follows the surface it sits on rather than the theme
                      // it inherits, which is light.
                      BrandAssets.symbol(context, size: 20, onDark: true),
                      if (!collapsed) ...[
                        const SizedBox(width: 9),
                        Text('Orchestrate',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Ws.onFieldMuted,
                                  letterSpacing: 0.4,
                                )),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // WHOSE BUSINESS AM I OPERATING?
            //
            // The first question anybody entering a workspace has, and the
            // shell answered it nowhere. It said Orchestrate, which is the
            // supplier rather than the business being operated, so an operator
            // holding more than one client inferred it from the contents of
            // the screen.
            if (!collapsed && workspaceName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workspaceName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Ws.onField,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Commercial workspace',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Ws.onFieldSubtle,
                          ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 14),
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
            const Divider(height: 20, color: Ws.fieldRaised),
            Padding(
              padding: EdgeInsets.fromLTRB(collapsed ? 10 : 12, 0, 12, 14),
              child: collapsed
                  ? Center(
                      child: _AccountButton(
                          session: session,
                          currentPath: currentPath,
                          signingOut: signingOut,
                          onSignOut: onSignOut,
                          onDark: true))
                  // THE WHOLE ROW OPENS THE MENU, NOT THE CIRCLE.
                  //
                  // The avatar was the only tap target: a 30px circle at the
                  // left of a row that reads as one control the full width of
                  // the rail. Clicking the business name or the email — the
                  // obvious place to click — did nothing at all, and this menu
                  // is the only way to People & authority, Plan & billing,
                  // Account & security, feedback, and signing out.
                  : _AccountButton(
                      session: session,
                      currentPath: currentPath,
                      signingOut: signingOut,
                      onSignOut: onSignOut,
                      // The button builds the name and email itself, from the
                      // live session. Built here they were read once, when the
                      // shell built, and the shell does not rebuild when a
                      // profile is saved — so the rail kept the old name.
                      showIdentity: true,
                      onDark: true,
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
    // Selection is structural rather than a filled pill: a lit left spine and
    // a lift in the ground. A pill on a deep field reads as a button somebody
    // pressed, when what it actually says is where you are.
    final child = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      padding: EdgeInsets.only(
          left: collapsed ? 0 : 11,
          right: collapsed ? 0 : 10,
          top: 9,
          bottom: 9),
      decoration: BoxDecoration(
        color: selected ? Ws.fieldRaised : Colors.transparent,
        borderRadius: BorderRadius.circular(Ws.radius),
        border: Border(
          left: BorderSide(
            color: selected ? Ws.accentBright : Colors.transparent,
            width: 2.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment:
            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          // Icons do not follow the text scaler on their own, so with the OS
          // enlarging text they stay at their designed size while every label
          // beside them grows — the rail stops reading as one control and the
          // hit target stops matching the row it belongs to. Tracked, and
          // capped, because an icon is a mark rather than a sentence and does
          // not need to keep growing to stay legible.
          Icon(selected ? destination.selectedIcon : destination.icon,
              size: Workspace.icon(context, 18),
              color: selected ? Ws.onField : Ws.onFieldSubtle),
          if (!collapsed) ...[
            const SizedBox(width: 11),
            Text(
              destination.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Ws.onField : Ws.onFieldMuted,
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
            margin: EdgeInsets.symmetric(
                horizontal: collapsed ? 10 : 12, vertical: 2),
            padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 12, vertical: 9),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(icon,
                    size: Workspace.icon(context, 18), color: Ws.onFieldSubtle),
                if (!collapsed) ...[
                  const SizedBox(width: 11),
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Ws.onFieldMuted)),
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
    this.showIdentity = false,
    this.onDark = false,
  });

  final AuthSessionController session;
  final bool signingOut;
  final VoidCallback onSignOut;

  /// Whether to show the business name and email beside the avatar. They are
  /// built inside this button so they follow the session, and they are inside
  /// the button rather than next to it so the whole row opens the menu — it
  /// reads as one control and it behaves as one.
  final bool showIdentity;

  /// Which surface this sits on. The same control appears in the rail, which
  /// is a deep field, and in the phone app bar, which is not. A control that
  /// assumes one of them is unreadable on the other.
  final bool onDark;

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
    // THE ROW READS THE SESSION, SO IT HAS TO HEAR WHEN THE SESSION CHANGES.
    //
    // The name, the email and the initials all come from the session, which is
    // written at sign-in and again whenever a profile is saved. Nothing
    // rebuilt this, so a saved name appeared on the account screen while the
    // rail two inches away went on showing the old one until the next
    // sign-in — which is what "saved but not surfacing" looked like.
    //
    // Scoped to this row rather than the whole shell: the shell contains
    // layout builders, and rebuilding it from a notification that arrives
    // mid-layout mutates a render object while an ancestor is laying out.
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
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
            value: '/account/people', child: Text('People & authority')),
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
        const PopupMenuItem(
            value: 'feedback', child: Text('Tell us something')),
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
      // Padded so the row has real height to hit, and the identity beside the
      // avatar is inside the button rather than next to it.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: widget.onDark ? Ws.fieldRaised : Ws.accentSoft,
              child: Text(
                initials.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.onDark ? Ws.onField : Ws.accent),
              ),
            ),
            if (widget.showIdentity) ...[
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // WHO YOU ARE, not which business you are operating.
                    //
                    // This row used to lead with the workspace name, which the
                    // rail now states at the top where the question is
                    // actually asked. Repeating it here spent the one place in
                    // the shell that identifies the PERSON on saying the same
                    // thing twice, and left an operator unable to see which
                    // account they were signed in as without opening a menu.
                    Text(
                      session.fullName.trim().isNotEmpty
                          ? session.fullName.trim()
                          : session.email,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: widget.onDark ? Ws.onField : Ws.ink,
                          ),
                    ),
                    if (session.fullName.trim().isNotEmpty)
                      Text(
                        session.email,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: widget.onDark
                                  ? Ws.onFieldSubtle
                                  : Ws.inkSubtle,
                              letterSpacing: 0,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ],
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
            icon: Icon(d.icon, size: Workspace.icon(context, 20)),
            selectedIcon:
                Icon(d.selectedIcon, size: Workspace.icon(context, 20)),
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
                  Icon(Icons.chevron_left,
                      size: Workspace.icon(context, 18),
                      color: AppTheme.publicMuted),
                  const SizedBox(width: 2),
                  Text(
                    // Named, not "Back". Back is where you came from; this is
                    // where this surface belongs, and saying which is the
                    // difference between orientation and a guess.
                    areaLabel ?? 'Workspace',
                    style:
                        text.bodySmall?.copyWith(color: AppTheme.publicMuted),
                  ),
                ],
              ),
            ),
          ),
          if (title != null) ...[
            const SizedBox(width: 6),
            Text('/',
                style: text.bodySmall?.copyWith(color: AppTheme.publicLine)),
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
