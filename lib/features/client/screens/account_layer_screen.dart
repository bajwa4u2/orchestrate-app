import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/commercial/client_capabilities.dart';
import 'package:orchestrate_app/core/theme/workspace_theme.dart';
import 'package:orchestrate_app/features/client/widgets/commercial_boundary.dart';
import 'package:orchestrate_app/features/client/screens/client_authorised_people_screen.dart';
import 'package:orchestrate_app/data/repositories/auth_repository.dart';

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
      // Swallowed deliberately. The failure is already held on the state
      // holder and rendered as "we could not read your plan"; rethrowing it
      // here only throws into a frame callback, where nothing can catch it and
      // the person still learns nothing.
      _capabilities.load().then((_) {}, onError: (Object _) {});
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
          // Contained, like the other Account sections. Two rows in a bare
          // column read as leftovers under the summary rather than as the
          // places those questions are answered.
          WorkspaceBand(
            title: 'WHERE THIS IS MANAGED',
            children: [
              WorkspaceRow(
                title: 'Subscription and payment',
                detail: 'Manage the subscription, payment method and receipts.',
                onTap: () => context.go('/client/billing'),
                action: const Icon(Icons.chevron_right,
                    size: 18, color: Ws.inkSubtle),
              ),
              WorkspaceRow(
                title: "Orchestrate's invoices to you",
                detail: 'Service agreement, invoices and statements from '
                    'Orchestrate. Separate from invoices you issue to your own '
                    'customers.',
                onTap: () => context.go('/client/records'),
                action: const Icon(Icons.chevron_right,
                    size: 18, color: Ws.inkSubtle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountAndSecurity extends StatefulWidget {
  const _AccountAndSecurity();

  @override
  State<_AccountAndSecurity> createState() => _AccountAndSecurityState();
}

/// THE SECURITY SURFACE THAT HAD NO SECURITY CONTROLS.
///
/// This was three links pointing elsewhere, while the personal security
/// controls — the trusted devices and the revoke action — lived inside
/// Workspace settings, a screen the product describes as "Preferences for this
/// workspace". A person's sessions are not a workspace preference, and someone
/// asking where they are signed in had no reason to look there.
///
/// The controls moved here, where the question is asked. Nothing new was
/// invented to hold them: the same repository, the same endpoints, the same
/// revoke semantics.
class _AccountAndSecurityState extends State<_AccountAndSecurity> {
  final AuthRepository _authRepository = AuthRepository();

  Future<Map<String, dynamic>>? _devices;
  bool _revoking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    // Started outside setState, then assigned inside a block. An arrow body
    // here returns the assignment's value — a Future — and Flutter asserts on
    // a setState callback that returns one.
    final request = _authRepository.fetchTrustedDevices();
    setState(() {
      _devices = request;
    });
  }

  Future<void> _revoke(String deviceId) async {
    setState(() => _revoking = true);
    try {
      await _authRepository.revokeTrustedDevice(deviceId);
      await AuthSessionController.instance.clearTrustedDeviceToken(
        surface: 'client',
      );
      _load();
    } finally {
      if (mounted) setState(() => _revoking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;
    return _AccountFrame(
      title: 'Account & security',
      context_: session.email,
      // GROUPED BY WHAT A PERSON IS ACTUALLY ASKING.
      //
      // Four questions with four owners, and the ones people get wrong are the
      // middle two: being signed in is not authority, and ending a device is
      // neither of them.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceBand(
            title: 'YOU',
            children: [
              WorkspaceRow(
                title: 'Your account',
                detail: session.fullName.isNotEmpty
                    ? session.fullName
                    : session.email,
                onTap: () => context.go('/client/account'),
                action: const Icon(Icons.chevron_right,
                    size: 18, color: Ws.inkSubtle),
              ),
              // WHO YOU ARE. Nothing more, and it must not imply more.
              //
              // This row used to end "…before you can be recognised as
              // authorised for the business", which reads as a promise that
              // confirming an address produces authority. It does not.
              WorkspaceRow(
                title: 'Email confirmed',
                detail: session.emailVerified
                    ? 'This address has been confirmed. That establishes who '
                        'you are, and nothing about what the business permits.'
                    : 'Not confirmed yet. Confirming it establishes who you '
                        'are.',
                tone: session.emailVerified ? RowTone.good : RowTone.attention,
              ),
            ],
          ),
          _TrustedDevices(
            devices: _devices,
            revoking: _revoking,
            onRevoke: _revoke,
            onRetry: _load,
          ),
          // WHAT THE COMPANY PERMITS. A separate question with a separate
          // answer, and the only place the resolution actually lives.
          //
          // Its own band, because the distinction is the point. A person with
          // a confirmed address and no authority previously had nothing to
          // read except a green tick, and drew the obvious wrong conclusion.
          WorkspaceBand(
            title: 'WHAT THE BUSINESS PERMITS',
            children: [
              WorkspaceRow(
                title: 'Authority to act for the business',
                detail: 'Being signed in, and confirmed, is not the same as '
                    'the business having authorised you to act in its name. '
                    'That is recorded against the organisation, not against '
                    'you, and ending a device above does not touch it.',
                onTap: () => context.go('/account/people'),
                action: const Icon(Icons.chevron_right,
                    size: 18, color: Ws.inkSubtle),
              ),
            ],
          ),
          WorkspaceBand(
            title: 'THIS WORKSPACE',
            children: [
              WorkspaceRow(
                title: 'Workspace settings',
                detail: 'How this workspace behaves. Nothing about you or '
                    'your sign-in is decided there.',
                onTap: () => context.go('/client/settings'),
                action: const Icon(Icons.chevron_right,
                    size: 18, color: Ws.inkSubtle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Where this person is signed in, and what they can end.
class _TrustedDevices extends StatelessWidget {
  const _TrustedDevices({
    required this.devices,
    required this.revoking,
    required this.onRevoke,
    required this.onRetry,
  });

  final Future<Map<String, dynamic>>? devices;
  final bool revoking;
  final Future<void> Function(String deviceId) onRevoke;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: devices,
      builder: (context, snapshot) {
        final children = <Widget>[];

        if (snapshot.connectionState == ConnectionState.waiting) {
          children.add(const WorkspaceRow(
            title: 'Trusted devices',
            detail: 'Checking where this account is signed in.',
          ));
        } else if (snapshot.hasError) {
          // AN UNREACHABLE ANSWER IS NOT AN EMPTY ONE.
          //
          // Reporting "no trusted devices" when the request failed would tell
          // somebody their account is trusted nowhere, which is the opposite
          // of what a failure means.
          children.add(WorkspaceRow(
            title: 'Trusted devices could not be read',
            detail: 'This is not the same as having none. Nothing has changed '
                'about where you are signed in.',
            tone: RowTone.attention,
            action: TextButton(onPressed: onRetry, child: const Text('Retry')),
          ));
        } else {
          final list = (snapshot.data?['devices'] as List?) ?? const [];
          if (list.isEmpty) {
            children.add(const WorkspaceRow(
              title: 'No trusted devices',
              detail: 'Every sign-in asks for an email code. After entering '
                  'one you can trust that device for 60 days.',
            ));
          } else {
            for (final raw in list) {
              children.add(_TrustedDeviceRow(
                device: Map<String, dynamic>.from(raw as Map),
                busy: revoking,
                onRevoke: onRevoke,
              ));
            }
          }
        }

        return WorkspaceBand(
          title: 'WHERE YOU ARE SIGNED IN',
          children: children,
        );
      },
    );
  }
}

/// One trusted device, and the one thing that can be done to it.
class _TrustedDeviceRow extends StatelessWidget {
  const _TrustedDeviceRow({
    required this.device,
    required this.busy,
    required this.onRevoke,
  });

  final Map<String, dynamic> device;
  final bool busy;
  final Future<void> Function(String deviceId) onRevoke;

  String _text(String key) {
    final value = device[key];
    return value == null ? '' : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final active = device['active'] == true;
    final id = _text('id');
    final name = _text('deviceName');
    final platform = _text('platform');
    final lastUsed = _text('lastUsedAt');

    final parts = <String>[
      active ? 'Active' : 'Inactive',
      if (platform.isNotEmpty) platform,
      if (lastUsed.isNotEmpty) 'last used $lastUsed',
    ];

    return WorkspaceRow(
      title: name.isEmpty ? 'Trusted device' : name,
      detail: parts.join(' · '),
      // ENDING A DEVICE IS NOT DELETING ACCESS, AND MUST NOT LOOK LIKE IT.
      //
      // Four acts get confused here, and this is the mildest: it is not losing
      // a role, not leaving a business, and not deleting an account. It means
      // one machine has to enter an email code again, and trusting it
      // afterwards restores it.
      //
      // So no confirmation — ceremony where reversal is trivial trains people
      // to dismiss the dialogs that matter — but the consequence is stated,
      // because "Revoke" alone reads more final than it is.
      action: active && id.isNotEmpty
          ? Tooltip(
              message: 'This device will need an email code again next time. '
                  'Trusting it afterwards restores it. Your authority for the '
                  'business is not affected.',
              child: TextButton(
                onPressed: busy ? null : () => onRevoke(id),
                child: Text(busy ? 'Revoking' : 'Revoke'),
              ),
            )
          : null,
    );
  }
}

/// A compact frame with lateral movement between the three account areas.
/// Not a fourth sidebar — you arrive here from the avatar and leave again.
class _AccountFrame extends StatefulWidget {
  const _AccountFrame({
    required this.title,
    required this.context_,
    required this.child,
  });

  final String title;
  final String context_;
  final Widget child;

  @override
  State<_AccountFrame> createState() => _AccountFrameState();
}

class _AccountFrameState extends State<_AccountFrame> {
  /// THE CHIP FOR WHERE YOU ARE WAS OFF THE SIDE OF THE SCREEN.
  ///
  /// Three chips do not fit across a phone, and the row starts at the left, so
  /// arriving at Account & security — the third — showed it clipped at the
  /// screen edge. The row scrolls, so nothing overflowed and nothing looked
  /// broken; it just did not show you where you were until you dragged it.
  /// Found on a Pixel.
  final _selectedChip = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  void _revealSelected() {
    final ctx = _selectedChip.currentContext;
    if (ctx == null || !mounted) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  String get title => widget.title;
  String get context_ => widget.context_;
  Widget get child => widget.child;

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
                Builder(builder: (context) {
                  final selected =
                      a.$2.endsWith(title.split(' ').first.toLowerCase()) ||
                          a.$1 == title;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _AreaChip(
                      key: selected ? _selectedChip : null,
                      label: a.$1,
                      selected: selected,
                      onTap: () => context.go(a.$2),
                    ),
                  );
                }),
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
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

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
            color: selected ? Ws.accentSoft : Colors.transparent,
            border: Border.all(
                color: selected ? Ws.accent : Ws.hairlineStrong),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? Ws.accent : Ws.inkMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
