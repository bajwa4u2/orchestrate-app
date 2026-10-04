import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/commercial/client_capabilities.dart';
import 'package:orchestrate_app/core/theme/workspace_theme.dart';
import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/core/ui/ob_widgets.dart';
import 'package:orchestrate_app/features/client/widgets/commercial_boundary.dart';
import 'package:orchestrate_app/features/client/screens/client_authorised_people_screen.dart';
import 'package:orchestrate_app/data/repositories/auth_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';
import 'package:orchestrate_app/core/navigation/workspace_map.dart';
import 'package:orchestrate_app/core/platform/billing_gate.dart';
import 'package:orchestrate_app/core/commercial/commercial_model.dart';
import 'package:orchestrate_app/data/repositories/client/client_billing_repository.dart';
import 'package:orchestrate_app/features/client/widgets/account_actions.dart';
import 'package:orchestrate_app/features/client/widgets/store_subscribe_panel.dart';
import 'package:url_launcher/url_launcher.dart';

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
    return _AccountFrame(
      title: 'People & authority',
      context_: 'Who your business recognises as able to decide for it.',
      // In the design Setup and Support use (founder, 2 Oct 2026).
      child: Theme(data: Ob.theme(), child: const ClientAuthorisedPeopleScreen(embedded: true)),
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

  bool _openingPortal = false;
  String? _portalError;

  /// Whether a plan can be bought at all, from the one commercial authority.
  CommercialActivation? _activation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_activation != null) return;
    ClientBillingRepository().fetchCommercialModel().then((m) {
      if (mounted) setState(() => _activation = m.activation);
    }, onError: (Object _) {});
  }

  // ACTIVATION AND MANAGEMENT ARE DIFFERENT ACTIONS (from the retired Billing
  // page, DD-34). Nothing is offered until the entitlement is known: offer a
  // purchase before the answer and a subscriber can buy twice; offer nothing
  // after a failed read and someone who wants to pay cannot.
  bool get _entitlementKnown => _capabilities.hasAnswer;
  bool _holdsPlatform() => _capabilities.entitlement?.state.operating ?? false;
  OwningRail? _owningRail() => _capabilities.entitlement?.ownedByRail;

  Future<void> _openPortal() async {
    setState(() {
      _openingPortal = true;
      _portalError = null;
    });
    try {
      final url = await ClientBillingRepository().createBillingPortalSession();
      final uri = Uri.tryParse(url.trim());
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _portalError = 'The payment page could not be opened. It opens once a '
          'plan has been paid for by card.';
    } finally {
      if (mounted) setState(() => _openingPortal = false);
    }
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
          // On a phone, the only place a plan can be bought; renders nothing
          // on web, where the payment provider's own page is used instead.
          const StoreSubscribePanel(),
          _Band(
            title: 'PAYMENT AND RECORDS',
            children: [
              if (externalPurchaseAllowed &&
                  _entitlementKnown &&
                  !_holdsPlatform() &&
                  (_activation?.open ?? false))
                _Row(
                  title: 'Choose a plan',
                  detail: 'Setting up is free. A plan finds and checks businesses, sends notes, '
                      'follows replies and runs your money.',
                  onTap: () => context.go('/client/setup?step=plan'),
                  action: const Icon(Icons.chevron_right,
                      size: 18, color: Ws.inkSubtle),
                ),
              // Closed is not a dead end: the server says why, and the
              // conversation that sets terms is offered.
              if (externalPurchaseAllowed &&
                  _entitlementKnown &&
                  !_holdsPlatform() &&
                  _activation != null &&
                  !_activation!.open)
                _Row(
                  title: 'Talk to us about commercial terms',
                  detail: [_activation!.says, _activation!.resolution]
                      .where((s) => s.isNotEmpty)
                      .join(' '),
                  onTap: () => context.go('/client/support'),
                  action: const Icon(Icons.chevron_right,
                      size: 18, color: Ws.inkSubtle),
                ),
              // MANAGE IT WHERE IT IS BILLED, OR NOT AT ALL. The portal is
              // Stripe's: offered to a store subscriber or a granted business
              // it is a page about somebody else's money, or it fails.
              // App Store 3.1.1: never on a store build.
              if (externalPurchaseAllowed &&
                  _holdsPlatform() &&
                  _owningRail() == OwningRail.stripe)
                _Row(
                  title: 'Payment method and receipts',
                  detail: _portalError ??
                      'Change the card, download receipts or cancel, on the '
                          'payment provider\'s own page.',
                  tone: _portalError == null ? RowTone.neutral : RowTone.attention,
                  onTap: _openingPortal ? null : _openPortal,
                  action: _openingPortal
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.open_in_new, size: 18, color: Ws.inkSubtle),
                ),
              _Row(
                title: 'Your record with Orchestrate',
                detail: 'Service agreement, invoices and statements from '
                    'Orchestrate. Separate from invoices you issue to your own '
                    'customers.',
                onTap: () => context.go('/account/record'),
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
      // THIS DEVICE'S OWN TRUST IS NOT CLEARED HERE.
      //
      // The old code cleared the local trusted-device token on every revoke,
      // whichever device was ended — so tidying up a stale sign-in from
      // another machine made THIS machine ask for an email code next time,
      // for no reason a person could see.
      //
      // The token is a cache and the server is the authority. If the device
      // just ended was this one, the token is already dead server-side and
      // the next sign-in asks for a code, which is exactly right. Clearing it
      // locally only ever broke the other case.
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
          _Band(
            title: 'YOU',
            children: [
              _Row(
                title: 'Your name',
                detail: session.fullName.isNotEmpty
                    ? session.fullName
                    : 'Not set. It signs every note sent for you.',
                onTap: () async {
                  if (await showOwnNameEditor(context) && mounted) setState(() {});
                },
                action: const Icon(Icons.edit_outlined,
                    size: 18, color: Ws.inkSubtle),
              ),
              // WHO YOU ARE. Nothing more, and it must not imply more.
              //
              // This row used to end "…before you can be recognised as
              // authorised for the business", which reads as a promise that
              // confirming an address produces authority. It does not.
              _Row(
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
          _Band(
            title: 'WHAT THE BUSINESS PERMITS',
            children: [
              _Row(
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
          // LEAVING. Reachable inside the app, as the app stores require.
          _Band(
            title: 'LEAVING ORCHESTRATE',
            children: [
              _Row(
                title: 'Deactivate account',
                detail: 'Close your access. Your business\'s records are kept.',
                onTap: () => showDeactivateAccount(context),
                action: const Icon(Icons.chevron_right,
                    size: 18, color: Ws.inkSubtle),
              ),
              _Row(
                title: 'Delete account',
                detail: 'Permanently delete your sign-in and personal profile. '
                    'This cannot be undone.',
                tone: RowTone.attention,
                onTap: () => showDeleteAccount(context),
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
class _TrustedDevices extends StatefulWidget {
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
  State<_TrustedDevices> createState() => _TrustedDevicesState();
}

class _TrustedDevicesState extends State<_TrustedDevices> {
  bool _showEnded = false;

  Future<Map<String, dynamic>>? get devices => widget.devices;
  bool get revoking => widget.revoking;
  Future<void> Function(String deviceId) get onRevoke => widget.onRevoke;
  VoidCallback get onRetry => widget.onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: devices,
      builder: (context, snapshot) {
        final children = <Widget>[];

        if (snapshot.connectionState == ConnectionState.waiting) {
          children.add(const _Row(
            title: 'Trusted devices',
            detail: 'Checking where this account is signed in.',
          ));
        } else if (snapshot.hasError) {
          // AN UNREACHABLE ANSWER IS NOT AN EMPTY ONE.
          //
          // Reporting "no trusted devices" when the request failed would tell
          // somebody their account is trusted nowhere, which is the opposite
          // of what a failure means.
          children.add(_Row(
            title: 'Trusted devices could not be read',
            detail: 'This is not the same as having none. Nothing has changed '
                'about where you are signed in.',
            tone: RowTone.attention,
            action: TextButton(onPressed: onRetry, child: const Text('Retry')),
          ));
        } else {
          final list = (snapshot.data?['devices'] as List?) ?? const [];
          if (list.isEmpty) {
            children.add(const _Row(
              title: 'No trusted devices',
              detail: 'Every sign-in asks for an email code. After entering '
                  'one you can trust that device for 60 days.',
            ));
          } else {
            // Active sign-ins first; ended ones are history, folded away.
            final all = [for (final raw in list) Map<String, dynamic>.from(raw as Map)];
            final active = all.where((d) => d['active'] == true).toList();
            final ended = all.where((d) => d['active'] != true).toList();
            for (final d in active) {
              children.add(_TrustedDeviceRow(device: d, busy: revoking, onRevoke: onRevoke));
            }
            if (ended.isNotEmpty) {
              children.add(_Row(
                title: _showEnded
                    ? 'Hide ended sign-ins'
                    : 'Show ${ended.length} ended ${ended.length == 1 ? 'sign-in' : 'sign-ins'}',
                onTap: () => setState(() => _showEnded = !_showEnded),
                action: Icon(_showEnded ? Icons.expand_less : Icons.expand_more,
                    size: 18, color: Ob.inkMuted),
              ));
              if (_showEnded) {
                for (final d in ended) {
                  children.add(_TrustedDeviceRow(device: d, busy: revoking, onRevoke: onRevoke));
                }
              }
            }
          }
        }

        return _Band(
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

    // SIX ROWS READING 'Current device - Active' AND NOTHING ELSE.
    //
    // Every device carried the same hardcoded name, so the list answered
    // 'where am I signed in?' six identical times and nobody could tell which
    // Revoke ended which session. New sign-ins now carry a real name; devices
    // trusted before this still do not, so the dates are shown too — they are
    // what separates one old row from another.
    final created = _plainWhen(device['createdAt']);
    final expires = _plainWhen(device['expiresAt']);
    final parts = <String>[
      active ? 'Signed in' : 'Ended',
      if (lastUsed.isNotEmpty)
        'last used ${_plainWhen(lastUsed)}'
      else if (created.isNotEmpty)
        'trusted $created',
      if (active && expires.isNotEmpty) 'until $expires',
    ];
    // "Current device" was a placeholder every early sign-in carried; the
    // platform says more.
    final named = name.isEmpty || name == 'Current device'
        ? (platform.isNotEmpty ? _platformName(platform) : 'A browser')
        : name;

    return _Row(
      title: named,
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

/// "2 Oct 2026 · 12:56 PM", or "today · 12:56 PM".
String _plainWhen(dynamic value) {
  final at = DateTime.tryParse('${value ?? ''}')?.toLocal();
  if (at == null) return '';
  final now = DateTime.now();
  final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final time = '$h:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'AM' : 'PM'}';
  if (at.year == now.year && at.month == now.month && at.day == now.day) return 'today · $time';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${at.day} ${months[at.month - 1]} ${at.year} · $time';
}

String _platformName(String platform) => switch (platform.toLowerCase()) {
      'web' => 'A web browser',
      'ios' => 'An iPhone or iPad',
      'android' => 'An Android phone',
      'windows' => 'A Windows computer',
      'macos' => 'A Mac',
      _ => platform,
    };

/// A titled group on the Account pages, in the design Setup and Support use.
class _Band extends StatelessWidget {
  const _Band({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title.toUpperCase(), style: Ob.eyebrow()),
        const SizedBox(height: 10),
        ObCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Ob.line),
              children[i],
            ],
          ]),
        ),
      ]),
    );
  }
}

/// One line in a group: what it is, what it says, and the one thing to do.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.detail,
    this.action,
    this.onTap,
    this.tone = RowTone.neutral,
  });

  final String title;
  final String? detail;
  final Widget? action;
  final VoidCallback? onTap;
  final RowTone tone;

  @override
  Widget build(BuildContext context) {
    final mark = switch (tone) {
      RowTone.attention || RowTone.problem => Ob.refused,
      RowTone.good => Ob.ink,
      _ => null,
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (mark != null) ...[
            Container(width: 3, height: 36, color: mark),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Ob.strong(15)),
              if (detail != null && detail!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(detail!, style: Ob.body(14, color: Ob.inkSoft)),
              ],
            ]),
          ),
          if (action != null) ...[const SizedBox(width: 10), action!],
        ]),
      ),
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

    final phone = Workspace.sizeOf(context, MediaQuery.sizeOf(context).width).isPhone;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Ob.inkMuted),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back'),
          // THE TWO RETURNS DISAGREED.
          //
          // This arrow went to Today while Android's Back went to the
          // semantic parent — People & authority, the roof these three tabs
          // sit under. Proven on a Pixel: the same gesture meant two things
          // depending on whether a thumb landed on the screen or the
          // navigation bar.
          //
          // Both now ask the same map, so they cannot drift apart again.
            onPressed: () => context.go(
              semanticParentOf(GoRouterState.of(context).uri.path) ??
                  canonicalWorkspaceHome,
            ),
          ),
        ),
        const SizedBox(height: 6),
        ObHeadline(title, size: phone ? 30 : 40),
        const SizedBox(height: 6),
        Text(context_, style: Ob.body(16, color: Ob.inkSoft)),
        const SizedBox(height: 18),
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
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: child),
        ),
        const SizedBox(height: 32),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Ob.ink : Colors.transparent,
            border: Border.all(color: selected ? Ob.ink : Ob.line, width: 1.2),
            borderRadius: BorderRadius.circular(Ob.radiusPill),
          ),
          child: Text(label, style: Ob.body(14, color: selected ? Ob.onInk : Ob.ink)),
        ),
      ),
    );
  }
}
