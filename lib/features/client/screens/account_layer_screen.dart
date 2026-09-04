import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/commercial/client_capabilities.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/client/widgets/commercial_boundary.dart';
import 'package:orchestrate_app/features/client/screens/client_authorised_people_screen.dart';

/// THE ACCOUNT LAYER — OUTSIDE THE OPERATIONAL WORKSPACE.
///
/// Three reasons this is not a fourth destination in the sidebar.
///
///   It describes the business's relationship with Orchestrate, not the work
///   being done today. Plan, billing and authority are visited when something
///   changes, and putting them beside Relationships gave lifecycle state the
///   same weight as the actual operation.
///
///   Authority is a property of the BUSINESS. It governs what the workspace
///   may do, so it cannot sit inside the thing it governs.
///
///   Most importantly: the workspace gates on completed setup and subscription
///   status. Authority placed inside those gates bounced exactly the people
///   being invited to establish it — an invited representative whose business
///   had not finished setup could not reach the page they had been emailed
///   about. This layer is deliberately reachable without either gate.
///
/// The Business/Account split is also where `platform commerce ≠ client-
/// counterparty commerce` becomes structural. Orchestrate's invoices to the
/// client live here. The client's invoices to their counterparties live in an
/// Engagement. They no longer share a screen.
class AccountLayerScreen extends StatelessWidget {
  const AccountLayerScreen({super.key, required this.section});

  final AccountSection section;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      AccountSection.people => const _PeopleAndAuthority(),
      AccountSection.plan => const _PlanAndBilling(),
      AccountSection.security => const _AccountAndSecurity(),
    };
  }
}

enum AccountSection { people, plan, security }

/// Who the business recognises as able to decide for it.
///
/// The designation experience itself is reused unchanged — its wording comes
/// from the backend artifact, its hash is submitted as shown, and capability
/// separation is preserved. What changed is where it lives and what it is
/// gated behind.
class _PeopleAndAuthority extends StatelessWidget {
  const _PeopleAndAuthority();

  @override
  Widget build(BuildContext context) {
    return const _AccountFrame(
      title: 'People & authority',
      context_: 'Who your business recognises as able to decide for it.',
      child: ClientAuthorisedPeopleScreen(embedded: true),
    );
  }
}

class _PlanAndBilling extends StatefulWidget {
  const _PlanAndBilling();

  @override
  State<_PlanAndBilling> createState() => _PlanAndBillingState();
}

class _PlanAndBillingState extends State<_PlanAndBilling> {
  final ClientCapabilities _capabilities = ClientCapabilities.instance;

  @override
  void initState() {
    super.initState();
    _capabilities.addListener(_onChanged);
    _askIfUnanswered();
  }

  /// Asked on build as well as on mount.
  ///
  /// Asking only in `initState` was not enough: the session settles after the
  /// screen appears, which invalidates the first answer, and a screen that only
  /// ever asks once then waits forever for a reply that will not come.
  ///
  /// Scheduled after the frame rather than run inside it. Anything that can
  /// notify listeners must not be started mid-build, and this is called from
  /// `build` by design.
  void _askIfUnanswered() {
    if (_capabilities.hasAnswer ||
        _capabilities.isLoading ||
        _capabilities.error != null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_capabilities.hasAnswer ||
          _capabilities.isLoading ||
          _capabilities.error != null) {
        return;
      }
      _capabilities.load().catchError((Object error) => throw error);
    });
  }

  @override
  void dispose() {
    _capabilities.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _askIfUnanswered();
    return _AccountFrame(
      title: 'Plan & billing',
      context_: 'Your commercial relationship with Orchestrate.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The entitlement, derived by the server, with the reason it came
          // out that way. This replaced a "Plan" row reading a plan name off
          // the session — a stored word that could not tell an expired
          // subscription from a live one, and had no idea a grant was not a
          // purchase.
          const EntitlementSummary(),

          const SizedBox(height: 24),
          WorkspaceRow(
            title: 'Subscription and payment',
            detail: 'Manage the subscription, payment method and receipts.',
            onTap: () => context.go('/client/billing'),
            action: const Icon(Icons.chevron_right,
                size: 18, color: AppTheme.publicMuted),
          ),
          WorkspaceRow(
            title: "Orchestrate's invoices to you",
            detail: 'Service agreement, invoices and statements from '
                'Orchestrate. Separate from invoices you issue to your own '
                'customers.',
            onTap: () => context.go('/client/records'),
            action: const Icon(Icons.chevron_right,
                size: 18, color: AppTheme.publicMuted),
          ),
        ],
      ),
    );
  }
}

class _AccountAndSecurity extends StatelessWidget {
  const _AccountAndSecurity();

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;
    return _AccountFrame(
      title: 'Account & security',
      context_: session.email,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceRow(
            title: 'Your account',
            detail: session.fullName.isNotEmpty ? session.fullName : session.email,
            onTap: () => context.go('/client/account'),
            action: const Icon(Icons.chevron_right,
                size: 18, color: AppTheme.publicMuted),
          ),
          WorkspaceRow(
            title: 'Email confirmed',
            detail: session.emailVerified
                ? 'This address has been confirmed.'
                : 'Not confirmed yet. Confirming it is required before you can '
                    'be recognised as authorised for the business.',
            tone: session.emailVerified ? RowTone.good : RowTone.attention,
          ),
          WorkspaceRow(
            title: 'Workspace settings',
            detail: 'Preferences for this workspace.',
            onTap: () => context.go('/client/settings'),
            action: const Icon(Icons.chevron_right,
                size: 18, color: AppTheme.publicMuted),
          ),
        ],
      ),
    );
  }
}

/// A compact frame with lateral movement between the three account areas.
/// Not a fourth sidebar — you arrive here from the avatar and leave again.
class _AccountFrame extends StatelessWidget {
  const _AccountFrame({
    required this.title,
    required this.context_,
    required this.child,
  });

  final String title;
  final String context_;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const areas = [
      ('People & authority', '/account/people'),
      ('Plan & billing', '/account/plan'),
      ('Account & security', '/account/security'),
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        WorkspaceHeader(
          title: title,
          context_: context_,
          onBack: () => context.go('/client/today'),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final a in areas)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _AreaChip(
                    label: a.$1,
                    selected: a.$2.endsWith(title.split(' ').first.toLowerCase()) ||
                        a.$1 == title,
                    onTap: () => context.go(a.$2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        child,
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppTheme.publicAccentSoft : Colors.transparent,
            border: Border.all(
                color: selected ? AppTheme.publicAccent : AppTheme.publicLine),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? AppTheme.publicAccent : AppTheme.publicMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
