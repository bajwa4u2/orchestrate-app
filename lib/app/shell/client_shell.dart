import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/auth_repository.dart';
import 'package:orchestrate_app/features/client/widgets/command_palette.dart';

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
      icon: Icons.today_outlined,
      selectedIcon: Icons.today,
      // Legacy paths that were conceptually "the operational home".
      absorbs: {'/client/overview', '/client/workspace', '/client/notifications'},
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
        '/client/leads',
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
    final content = SelectionArea(child: widget.child);

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
  });

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
            Padding(
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
                          signingOut: signingOut,
                          onSignOut: onSignOut))
                  : Row(
                      children: [
                        _AccountButton(
                            session: session,
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
class _AccountButton extends StatelessWidget {
  const _AccountButton({
    required this.session,
    required this.signingOut,
    required this.onSignOut,
  });

  final AuthSessionController session;
  final bool signingOut;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final name = session.fullName.trim();
    final initials = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).take(2).map((p) => p[0]).join()
        : (session.email.isNotEmpty ? session.email[0].toUpperCase() : '?');

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 40),
      onSelected: (value) {
        if (value == 'signout') {
          onSignOut();
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
