import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/config/app_config.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/auth_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_billing_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_branding_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

class ClientShell extends StatefulWidget {
  const ClientShell(
      {super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  final ClientBillingRepository _billingRepository = ClientBillingRepository();
  final ClientBrandingRepository _brandingRepository = ClientBrandingRepository();
  final AuthRepository _authRepository = AuthRepository();
  Map<String, dynamic>? _subscription;
  bool _hasClientLogo = false;
  bool _signingOut = false;

  static const double _sidebarWidth = 284;
  static const double _maxContentWidth = WorkspaceBreakpoints.contentMax;

  // Operational shell IA. Order matches how Orchestrate operates:
  // home overview, the live execution runtime, the intelligence /
  // outcome continuity stack, then the infrastructure + representation
  // surfaces clients own, then records + support + settings. Guidance
  // is no longer a primary destination — it dissolves into inline
  // "Why?" affordances + the contextual drawer.
  static const List<_ClientNavItem> _primaryItems = [
    _ClientNavItem(
        label: 'Home',
        path: '/client/overview',
        icon: Icons.space_dashboard_outlined),
    _ClientNavItem(
        label: 'Relationships',
        path: '/client/relationships',
        icon: Icons.group_outlined),
    _ClientNavItem(
        label: 'Opportunities',
        path: '/client/opportunities',
        icon: Icons.insights_outlined),
    _ClientNavItem(
        label: 'Operations',
        path: '/client/operations',
        icon: Icons.timeline_outlined),
    _ClientNavItem(
        label: 'Replies',
        path: '/client/replies',
        icon: Icons.forum_outlined),
    _ClientNavItem(
        label: 'Meetings',
        path: '/client/meetings',
        icon: Icons.calendar_month_outlined),
    _ClientNavItem(
        label: 'Infrastructure',
        path: '/client/infrastructure',
        icon: Icons.dns_outlined),
    _ClientNavItem(
        label: 'Representation',
        path: '/client/representation',
        icon: Icons.fingerprint),
    _ClientNavItem(
        label: 'Branding',
        path: '/app/branding',
        icon: Icons.palette_outlined),
    _ClientNavItem(
        label: 'Records',
        path: '/client/records',
        icon: Icons.description_outlined),
    _ClientNavItem(
        label: 'Billing',
        path: '/client/billing',
        icon: Icons.credit_card_outlined),
    _ClientNavItem(
        label: 'Notifications',
        path: '/client/notifications',
        icon: Icons.notifications_none_outlined),
    _ClientNavItem(
        label: 'Support',
        path: '/client/support',
        icon: Icons.support_agent_outlined),
    _ClientNavItem(
        label: 'Settings',
        path: '/client/settings',
        icon: Icons.manage_accounts_outlined),
  ];

  @override
  void initState() {
    super.initState();
    AuthSessionController.instance.addListener(_handleSessionChanged);
    _refreshSubscription();
    _refreshBranding();
  }

  @override
  void dispose() {
    AuthSessionController.instance.removeListener(_handleSessionChanged);
    super.dispose();
  }

  void _handleSessionChanged() {
    if (!mounted) return;
    _refreshSubscription();
  }

  Future<void> _refreshSubscription() async {
    try {
      final data = await _billingRepository.fetchSubscription();
      if (!mounted) return;
      setState(() => _subscription = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _subscription = null);
    }
  }

  Future<void> _refreshBranding() async {
    try {
      final data = await _brandingRepository.fetchBranding();
      if (!mounted) return;
      final logo = data['logo'] as Map?;
      setState(() => _hasClientLogo = logo != null);
    } catch (_) {
      // Non-fatal — fallback to Orchestrate logo
    }
  }

  String _subscriptionLabel(AuthSessionController session) {
    final service = (_subscription?['serviceName'] ??
            _subscription?['service'] ??
            session.selectedPlan ??
            'Not set')
        .toString()
        .trim();
    final tier = (_subscription?['tierName'] ??
            _subscription?['tier'] ??
            session.selectedTier ??
            '')
        .toString()
        .trim();
    String cap(String s) =>
        s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
    return [service, tier].where((e) => e.isNotEmpty).map(cap).join(' · ');
  }

  String _billingLabel(AuthSessionController session) {
    final raw = (_subscription?['status'] ?? session.subscriptionStatus)
        .toString()
        .trim();
    if (raw.isEmpty) return 'Unknown';
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

  String _topTitle() {
    switch (widget.currentPath) {
      case '/client/overview':
        return 'Home';
      case '/client/setup':
        return 'Setup';
      case '/client/representation':
      case '/client/business-identity':
      case '/client/campaign':
      case '/client/campaign/targeting':
        return 'Representation';
      case '/client/relationships':
      case '/client/contacts':
        return 'Relationships';
      case '/client/opportunities':
      case '/client/leads':
        return 'Opportunities';
      case '/client/operations':
      case '/client/outreach':
        return 'Operations';
      case '/client/replies':
        return 'Replies';
      case '/client/meetings':
        return 'Meetings';
      case '/client/infrastructure':
      case '/client/mailbox':
        return 'Infrastructure';
      case '/client/invoices':
      case '/client/receipts':
      case '/client/records':
      case '/client/agreements':
      case '/client/statements':
      case '/client/reminders':
        return 'Records';
      case '/client/billing':
        return 'Billing';
      case '/client/notifications':
        return 'Notifications';
      case '/client/support':
        return 'Support';
      case '/client/settings':
        return 'Settings';
      case '/app/contacts':
        return 'Contacts';
      case '/app/campaigns':
        return 'Representation';
      case '/app/activity':
        return 'Activity';
      case '/app/mailbox':
        return 'Infrastructure';
      case '/app/newsletter':
        return 'Newsletter';
      case '/app/branding':
        return 'Branding';
      case '/app/billing':
        return 'Billing';
      case '/app/account':
        return 'Account';
      default:
        return 'Home';
    }
  }

  String _topStateLine(AuthSessionController session) {
    if (!session.emailVerified) {
      return 'Confirm your email to continue.';
    }
    if (!session.hasSetupCompleted) {
      return 'Complete setup to begin your operation.';
    }
    if (session.normalizedSubscriptionStatus != 'active') {
      return 'Activate billing to start your operation.';
    }

    switch (widget.currentPath) {
      case '/client/overview':
        return 'Overview of your operation.';
      case '/client/setup':
        return 'Business profile, market, and authorization.';
      case '/client/representation':
      case '/client/business-identity':
      case '/client/campaign':
      case '/client/campaign/targeting':
        return 'Identity, ICP, voice, and authorization.';
      case '/client/relationships':
      case '/client/contacts':
        return 'People you communicate with.';
      case '/client/opportunities':
      case '/client/leads':
        return 'Qualified B2B opportunities.';
      case '/client/operations':
      case '/client/outreach':
        return 'Outreach momentum and engagement.';
      case '/client/replies':
        return 'Inbound conversations.';
      case '/client/meetings':
        return 'Meetings from conversations.';
      case '/client/infrastructure':
      case '/client/mailbox':
        return 'Sending mailbox and domain.';
      case '/client/billing':
      case '/client/invoices':
      case '/client/receipts':
      case '/client/agreements':
      case '/client/statements':
      case '/client/reminders':
        return 'Service standing and billing records.';
      case '/client/notifications':
        return 'Account notices.';
      case '/client/support':
        return 'Human support.';
      case '/client/settings':
        return 'Account details and authorization.';
      case '/app/contacts':
        return 'Sourced contacts and readiness.';
      case '/app/campaigns':
        return 'Market, geography, and ICP scope.';
      case '/app/activity':
        return 'Replies, meetings, and engagement.';
      case '/app/mailbox':
        return 'Sending mailbox and domain.';
      case '/app/newsletter':
        return 'Update controls for your account.';
      case '/app/branding':
        return 'Brand controls for your account.';
      case '/app/billing':
        return 'Service standing and billing.';
      case '/app/account':
        return 'Profile, password, and account controls.';
      default:
        return 'Overview of your operation.';
    }
  }

  bool _isSelected(String path) {
    if (widget.currentPath == path) return true;
    // Representation captures the old business-identity + campaign
    // paths so deep links keep the right sidebar entry highlighted
    // while redirects propagate.
    if (path == '/client/representation' &&
        const {
          '/client/representation',
          '/client/business-identity',
          '/client/campaign',
          '/client/campaign/targeting',
          '/client/campaigns',
        }.contains(widget.currentPath)) {
      return true;
    }
    if (path == '/client/operations' &&
        widget.currentPath == '/client/outreach') {
      return true;
    }
    if (path == '/client/opportunities' &&
        widget.currentPath == '/client/leads') {
      return true;
    }
    if (path == '/client/infrastructure' &&
        widget.currentPath == '/client/mailbox') {
      return true;
    }
    if (path == '/client/records' &&
        const {
          '/client/records',
          '/client/agreements',
          '/client/invoices',
          '/client/receipts',
          '/client/statements',
          '/client/reminders',
        }.contains(widget.currentPath)) {
      return true;
    }
    return false;
  }

  Future<void> _signOut(BuildContext context) async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await _authRepository.logout();
    } catch (_) {
      // Sign out must still clear local session when server logout is unavailable.
    } finally {
      await AuthSessionController.instance.clear();
      if (context.mounted) context.go('/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;
    final name = session.workspaceName.trim().isNotEmpty
        ? session.workspaceName.trim()
        : 'Client workspace';
    final email = session.email.trim();

    // Client workspace content is selectable by default — outcome
    // detail, readiness explanations, message previews, and IDs must
    // be copyable. The sidebar / top chrome stays outside this area.
    final content = SelectionArea(child: widget.child);

    return Theme(
      data: AppTheme.lightTheme,
      child: LayoutBuilder(builder: (context, constraints) {
        final mobile = constraints.maxWidth < WorkspaceBreakpoints.mobile;
        return Scaffold(
          backgroundColor: AppTheme.publicBackground,
          drawer: mobile
              ? Drawer(
                  child: _SidebarContent(
                      name: name,
                      email: email,
                      hasClientLogo: _hasClientLogo,
                      isSelected: _isSelected,
                      signingOut: _signingOut,
                      onSignOut: () => _signOut(context)))
              : null,
          appBar: mobile
              ? AppBar(
                  title: Text(_topTitle()),
                  backgroundColor: AppTheme.publicBackground,
                  foregroundColor: AppTheme.publicText,
                  elevation: 0,
                )
              : null,
          body: mobile
              ? _ContentArea(
                  session: session,
                  title: _topTitle(),
                  stateLine: _topStateLine(session),
                  plan: _subscriptionLabel(session),
                  billing: _billingLabel(session),
                  horizontalPadding: 16,
                  // On mobile the AppBar already shows the page title.
                  // Suppressing the title block here removes ~88 px of
                  // duplicated chrome so content starts sooner.
                  hideTitleBlock: true,
                  child: content,
                )
              : Row(
                  children: [
                    SizedBox(
                      width: _sidebarWidth,
                      child: _SidebarContent(
                        name: name,
                        email: email,
                        hasClientLogo: _hasClientLogo,
                        isSelected: _isSelected,
                        signingOut: _signingOut,
                        onSignOut: () => _signOut(context),
                      ),
                    ),
                    Expanded(
                      child: _ContentArea(
                        session: session,
                        title: _topTitle(),
                        stateLine: _topStateLine(session),
                        plan: _subscriptionLabel(session),
                        billing: _billingLabel(session),
                        horizontalPadding: 28,
                        child: content,
                      ),
                    ),
                  ],
                ),
        );
      }),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  const _SidebarContent({
    required this.name,
    required this.email,
    required this.isSelected,
    required this.signingOut,
    required this.onSignOut,
    required this.hasClientLogo,
  });

  final String name;
  final String email;
  final bool hasClientLogo;
  final bool Function(String path) isSelected;
  final bool signingOut;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => context.go('/client/overview'),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    hasClientLogo
                        ? Image.network(
                            '${AppConfig.normalizedApiBaseUrl}/clients/me/branding/logo/logo_primary',
                            headers: {'Authorization': 'Bearer ${AuthSessionController.instance.token}'},
                            height: 30,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => BrandAssets.logo(context, height: 30),
                          )
                        : BrandAssets.logo(context, height: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.separated(
                  itemCount: _ClientShellState._primaryItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = _ClientShellState._primaryItems[index];
                    return _NavButton(
                      item: item,
                      selected: isSelected(item.path),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: signingOut ? null : onSignOut,
                icon: signingOut
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout, size: 18),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                label: Text(signingOut ? 'Signing out' : 'Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentArea extends StatelessWidget {
  const _ContentArea({
    required this.session,
    required this.title,
    required this.stateLine,
    required this.plan,
    required this.billing,
    required this.child,
    required this.horizontalPadding,
    this.hideTitleBlock = false,
  });

  final AuthSessionController session;
  final String title;
  final String stateLine;
  final String plan;
  final String billing;
  final Widget child;
  final double horizontalPadding;
  final bool hideTitleBlock;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: AppTheme.publicBackground,
            border: Border(bottom: BorderSide(color: AppTheme.publicLine)),
          ),
          child: SafeArea(
            bottom: false,
            left: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 18, horizontalPadding, 18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: _ClientShellState._maxContentWidth),
                  child: Builder(
                    builder: (context) {
                      final titleBlock = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.publicText,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(stateLine,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      );
                      final utility = Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _Pill(
                            label: 'Account',
                            value: session.hasSetupCompleted
                                ? 'Onboarded'
                                : 'Onboarding in progress',
                          ),
                          _Pill(label: 'Plan', value: plan),
                          _Pill(label: 'Billing', value: billing),
                        ],
                      );
                      // Mobile: the AppBar already shows the page title.
                      // Show only the utility pills.
                      if (hideTitleBlock) {
                        return utility;
                      }
                      // Always use a Row on desktop — titleBlock is Expanded
                      // and utility is a Wrap, both handle narrow widths
                      // without forcing a column stack.
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: titleBlock),
                          const SizedBox(width: 20),
                          utility,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                horizontalPadding, 24, horizontalPadding, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                    maxWidth: _ClientShellState._maxContentWidth),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected});

  final _ClientNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.publicAccentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: () => context.go(item.path),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 19,
                color: selected ? AppTheme.publicAccent : AppTheme.publicMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: selected
                            ? AppTheme.publicAccent
                            : AppTheme.publicText,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(
        value,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ClientNavItem {
  const _ClientNavItem({
    required this.label,
    required this.path,
    required this.icon,
  });

  final String label;
  final String path;
  final IconData icon;
}
