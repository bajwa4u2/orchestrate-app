import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_account_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_mailbox_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_outreach_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';
import 'package:orchestrate_app/features/client/widgets/imap_connect_dialog.dart';
import 'package:orchestrate_app/features/client/widgets/smtp_connect_dialog.dart';
import 'package:orchestrate_app/features/guidance/guidance_drawer.dart';
import 'package:orchestrate_app/features/guidance/widgets/why_affordance.dart';

/// Mailbox is the one infrastructure surface where the client genuinely
/// owns an action: connecting and verifying the sending identity Orchestrate
/// will send outreach from. Everything else (campaign lifecycle, dispatch,
/// recovery) is Orchestrate's responsibility.
///
/// This screen frames mailbox state as identity readiness, not as a console
/// of operational toggles. There is at most one client CTA at a time — the
/// next concrete identity step Orchestrate needs from the client.
class ClientMailboxScreen extends StatefulWidget {
  const ClientMailboxScreen({super.key, this.focus});

  /// Optional deep-link hint. `focus=domain` scrolls the page to the
  /// Sending domain panel on first build so "Verify sending identity"
  /// from Operations lands directly on DNS, not on the transport
  /// section.
  final String? focus;

  @override
  State<ClientMailboxScreen> createState() => _ClientMailboxScreenState();
}

class _ClientMailboxScreenState extends State<ClientMailboxScreen> {
  final ClientMailboxRepository _mailboxRepository = ClientMailboxRepository();
  final ClientOutreachRepository _outreachRepository =
      ClientOutreachRepository();
  final ClientAccountRepository _accountRepository = ClientAccountRepository();
  late Future<_MailboxViewData> _future = _load();
  final GlobalKey _sendingDomainAnchor = GlobalKey();
  final TextEditingController _domainAttachController = TextEditingController();
  String? _oauthInflightProvider;
  bool _verifyingDomain = false;
  bool _attachingDomain = false;
  String? _resultMessage;
  bool _focusHandled = false;

  @override
  void dispose() {
    _domainAttachController.dispose();
    super.dispose();
  }

  Future<void> _attachDomain(String domain) async {
    final trimmed = domain.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _attachingDomain = true;
      _resultMessage = null;
    });
    try {
      await _mailboxRepository.attachSendingDomain(trimmed);
      if (!mounted) return;
      setState(() {
        _resultMessage =
            'Sending domain $trimmed attached. Publish SPF and DMARC at your registrar, then check verification.';
        _future = _load();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resultMessage = 'Could not attach $trimmed: $error';
      });
    } finally {
      if (mounted) setState(() => _attachingDomain = false);
    }
  }

  void _scrollToSendingDomain() {
    final ctx = _sendingDomainAnchor.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  /// Open the backend-owned OAuth flow for [provider] (`google` or
  /// `microsoft`). The backend returns an authorize URL; the app opens
  /// it in the system browser. Tokens never touch the app. Pass
  /// [mailboxId] when re-authorizing an existing REQUIRES_REAUTH mailbox.
  Future<void> _startOAuth(String provider, {String? mailboxId}) async {
    setState(() => _oauthInflightProvider = provider);
    try {
      final response = await _mailboxRepository.startMailboxOAuth(
        provider: provider,
        mailboxId: mailboxId,
      );
      final authorizeUrl = readText(response, 'authorizeUrl');
      if (authorizeUrl.isEmpty) {
        throw const FormatException('Backend did not return an authorize URL');
      }
      final uri = Uri.tryParse(authorizeUrl);
      if (uri == null) {
        throw FormatException('Authorize URL is not a valid URI: $authorizeUrl');
      }
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw StateError(
          'Could not open the consent page in a browser on this device.',
        );
      }
      setState(() {
        _resultMessage = 'Opened ${_providerLabel(provider)} consent in your '
            'browser. Approve the request. Orchestrate will finish the connection.';
        _future = _load();
      });
    } catch (error) {
      setState(() {
        _resultMessage = ClientErrorView.classifyError(error);
        _future = _load();
      });
    } finally {
      if (mounted) setState(() => _oauthInflightProvider = null);
    }
  }

  String _providerLabel(String provider) {
    switch (provider.toLowerCase()) {
      case 'google':
        return 'Gmail';
      case 'microsoft':
        return 'Microsoft 365';
      default:
        return provider;
    }
  }

  void _refresh() {
    setState(() {
      _resultMessage = null;
      _future = _load();
    });
  }

  Future<void> _checkSendingIdentity() async {
    setState(() => _verifyingDomain = true);
    try {
      final result = await _mailboxRepository.verifySendingDomain();
      final ready = result['ready'] == true;
      setState(() {
        _resultMessage = ready
            ? 'Sending domain verified. Orchestrate can send on your behalf.'
            : 'Verification did not pass. DNS can take time to propagate. Publish each record and try again.';
        _future = _load();
      });
    } catch (error) {
      setState(() {
        _resultMessage = ClientErrorView.classifyError(error);
        _future = _load();
      });
    } finally {
      if (mounted) setState(() => _verifyingDomain = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MailboxViewData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(
            eyebrow: 'Infrastructure',
            label: 'Loading mailbox + sending-identity infrastructure',
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Infrastructure is temporarily unavailable',
            onRetry: _refresh,
          );
        }
        final data = snapshot.data!;
        // First time we land with focus=domain, scroll to the sending
        // domain panel once the layout settles. This is what makes
        // "Verify sending identity" from Operations route directly to
        // DNS instead of looping through transport.
        if (!_focusHandled && widget.focus == 'domain') {
          _focusHandled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToSendingDomain();
          });
        }
        return ClientPage(
          eyebrow: 'Infrastructure',
          title: data.headline,
          subtitle: data.subtitle,
          banner: ClientStatusBanner(
            tone: data.bannerTone,
            title: data.bannerTitle,
            message: data.bannerMessage,
          ),
          actions: _buildActions(data),
          children: [
            // ─────────────────────────────────────────────────────
            //  Primary status card — the ONE truth above the fold.
            //  Derived from snapshot.primaryAction. Everything else
            //  on this page is demoted to "Details" below.
            // ─────────────────────────────────────────────────────
            _PrimaryStatusCard(snapshot: data.snapshot),
            const SizedBox(height: 18),
            // "Latest result" is demoted to a thin transient line
            // and ONLY appears for ~3 seconds of "Last action: …"
            // copy. It does not compete with the primary card.
            if (_resultMessage != null && data.snapshot.isNotEmpty) ...[
              _LastActionLine(message: _resultMessage!),
              const SizedBox(height: 12),
            ] else if (_resultMessage != null) ...[
              // No canonical snapshot loaded — fall back to the
              // legacy result panel so the user still sees what
              // happened.
              ClientPanel(
                title: 'Latest result',
                children: [
                  ClientInfoRow(
                    title: 'Status',
                    primary: _resultMessage!,
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            _OperationalIdentityPanel(
              identity: data.operationalIdentity,
              providerAvailability: data.providerAvailability,
            ),
            const SizedBox(height: 18),
            _TransportAuthorityPanel(
              clientTransportAuthorized: data.clientTransportAuthorized,
              platformTransportAvailable: data.platformTransportAvailable,
            ),
            const SizedBox(height: 18),
            if (data.mailboxProvider == 'SMTP') ...[
              _ReplyMonitoringPanel(
                onAttach: () => _openImapDialog(data, data.mailboxId),
              ),
              const SizedBox(height: 18),
            ],
            // Sending-identity panel. A PERSONAL_PROVIDER mailbox
            // (gmail.com, …) cannot own DNS, so the DNS-records panel is
            // replaced by the personal-mailbox panel — the page never
            // renders an impossible "publish SPF / DKIM / DMARC" task.
            KeyedSubtree(
              key: _sendingDomainAnchor,
              child: data.isPersonalProvider
                  ? _PersonalMailboxPanel(
                      mailboxAddress:
                          data.operationalIdentity.mailboxAddress,
                      upgradePath: data.upgradePath,
                    )
                  : _SendingDomainPanel(
                      identity: data.sendingIdentity,
                      inferredDomain: data.operationalIdentity.domain,
                      inferredDomainSource:
                          data.operationalIdentity.domainSource,
                      attaching: _attachingDomain,
                      verifying: _verifyingDomain,
                      onAttach: _attachDomain,
                      onVerify: _checkSendingIdentity,
                      domainController: _domainAttachController,
                    ),
            ),
            const SizedBox(height: 18),
            _TransportChoicesPanel(
              providerAvailability: data.providerAvailability,
              hasMailbox: data.operationalIdentity.mailboxAddress.isNotEmpty,
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Readiness chain',
              subtitle:
                  'Each layer depends on the one above. Waiting rows unblock automatically.',
              children: [
                for (final step in data.identitySteps)
                  ClientInfoRow(
                    title: step.label,
                    primary: step.description,
                    trailing: ClientBadge(label: step.badge),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Recent sending activity',
              subtitle:
                  'Outbound dispatches from your mailbox. Orchestrate manages the cadence; this is here so you can verify what was sent.',
              children: data.dispatchRows.isEmpty
                  ? const [
                      ClientEmptyState(
                          message:
                              'No outbound dispatches yet. Dispatch eligibility is granted once every identity layer above is verified.')
                    ]
                  : [
                      for (final row in data.dispatchRows)
                        ClientInfoRow(
                          title: row.title,
                          primary: row.primary,
                          secondary: row.secondary,
                        ),
                    ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Activity summary',
              children: [
                ClientInfoRow(
                  title: 'Dispatches',
                  primary: '${data.dispatchCount} outbound message(s) recorded.',
                ),
                ClientInfoRow(
                  title: 'Replies',
                  primary: '${data.replyCount} inbound reply event(s) recorded.',
                ),
                ClientInfoRow(
                  title: 'Account notices',
                  primary:
                      '${data.noticeCount} account notice(s) open in your workspace.',
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildActions(_MailboxViewData data) {
    final widgets = <Widget>[];
    for (var i = 0; i < data.primaryActions.length; i++) {
      final action = data.primaryActions[i];
      final inflight = _oauthInflightProvider == action.oauthProvider;
      final isPrimary = i == 0;
      final button = isPrimary
          ? FilledButton.icon(
              onPressed: inflight
                  ? null
                  : () => _startOAuth(action.oauthProvider, mailboxId: action.mailboxId),
              icon: inflight
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(action.icon, size: 18),
              label: Text(inflight ? 'Opening consent…' : action.label),
            )
          : OutlinedButton.icon(
              onPressed: inflight
                  ? null
                  : () => _startOAuth(action.oauthProvider, mailboxId: action.mailboxId),
              icon: inflight
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(action.icon, size: 18),
              label: Text(inflight ? 'Opening consent…' : action.label),
            );
      widgets.add(button);
    }
    // SMTP / custom transport is a first-class connect path. It does
    // not depend on operator-side OAuth env, so the CTA is always
    // visible when the workspace has no connected transport.
    final smtpAvailable = data.providerAvailability['smtp']?.available ?? true;
    if (smtpAvailable && data.operationalIdentity.mailboxAddress.isEmpty) {
      widgets.add(
        OutlinedButton.icon(
          onPressed: () => _openSmtpDialog(data),
          icon: const Icon(Icons.dns_outlined, size: 18),
          label: const Text('Connect custom mail transport'),
        ),
      );
    }
    widgets.add(
      OutlinedButton.icon(
        onPressed: _refresh,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Refresh status'),
      ),
    );
    return widgets;
  }

  Future<void> _openSmtpDialog(_MailboxViewData data) async {
    final inferred = data.operationalIdentity.domain;
    final initial = inferred.isNotEmpty ? 'you@$inferred' : null;
    final saved = await SmtpConnectDialog.show(
      context,
      initialFromAddress: initial,
    );
    if (saved && mounted) {
      setState(() {
        // CRITICAL: neutral "Last action" text. Do NOT prescribe
        // a next step here — the canonical snapshot's
        // primaryAction decides what (if anything) the user must
        // do next. Hard-coding "Publish the DKIM TXT record" was
        // the source of the live setup loop: when DNS was
        // already verified, this message contradicted reality.
        _resultMessage = 'SMTP credentials saved';
        _future = _load();
      });
    }
  }

  Future<void> _openImapDialog(_MailboxViewData data, String mailboxId) async {
    final saved = await ImapConnectDialog.show(
      context,
      mailboxId: mailboxId,
      initialUsername: data.operationalIdentity.mailboxAddress,
    );
    if (saved && mounted) {
      setState(() {
        _resultMessage =
            'IMAP inbound monitoring attached. The poll worker will ingest new replies on the next sweep and suppress pending follow-ups against the same lead.';
        _future = _load();
      });
    }
  }

  Future<_MailboxViewData> _load() async {
    final dispatches = await _outreachRepository.fetchEmailDispatches();
    final replies = await _outreachRepository.fetchReplies();
    final notices = await _outreachRepository.fetchNotifications();
    final readiness = await _mailboxRepository.fetchMailbox();
    final sendingDomain = await _mailboxRepository.fetchSendingDomain();
    final providers = await _mailboxRepository.fetchProviderAvailability();
    // Canonical Infrastructure-page snapshot. Every panel state
    // below MUST source from this when it is non-empty. The snapshot
    // is the single backend authority on transport / DNS / dispatch /
    // banner / header — there are no independent panel derivations.
    Map<String, dynamic> snapshot = const <String, dynamic>{};
    try {
      snapshot = await _mailboxRepository.fetchInfrastructureSnapshot();
    } catch (_) {
      // Snapshot endpoint failure must not blank the page. The
      // panels fall back to the legacy derivations below; the next
      // pull-to-refresh recovers.
      snapshot = const <String, dynamic>{};
    }
    Map<String, dynamic> profile = const <String, dynamic>{};
    try {
      profile = await _accountRepository.fetchClientProfile();
      final inner = asMap(profile['profile']);
      if (inner.isNotEmpty) profile = inner;
    } catch (_) {
      profile = const <String, dynamic>{};
    }

    // The canonical snapshot is the authority. Legacy `readiness`
    // fields stay as fallback ONLY when the snapshot endpoint
    // could not be reached.
    final snapTransport = asMap(snapshot['transport']);
    final snapMailbox = asMap(snapTransport['mailbox']);
    final snapDomain = asMap(snapshot['domain']);
    final snapDispatch = asMap(snapshot['dispatch']);
    final snapBanner = asMap(snapshot['banner']);
    final snapAvailable = snapshot.isNotEmpty;

    final mailbox = snapAvailable && snapMailbox.isNotEmpty
        ? <String, dynamic>{
            'address': snapMailbox['address'],
            'fromEmail': snapMailbox['address'],
            'provider': snapMailbox['provider'],
            'connected': snapMailbox['connected'] == true ? 'true' : 'false',
            'verified': snapMailbox['verified'] == true ? 'true' : 'false',
            'isClientOwned': snapMailbox['isClientOwned'] == true,
            'isPlatformBootstrap': snapMailbox['isPlatformBootstrap'] == true,
          }
        : asMap(readiness['mailbox']);
    final blockers = asList(readiness['blockers']).map(asMap).toList();
    final ready = snapAvailable
        ? snapDispatch['eligible'] == true
        : readiness['ready'] == true;

    // Transport authority distinction — Phase 3 of runtime truthfulness.
    // `clientTransportAuthorized` is the only correct answer to "does
    // the tenant have an authorized sending mailbox?" — a platform/
    // bootstrap mailbox can NEVER satisfy it.
    final clientTransportAuthorized = snapAvailable
        ? snapTransport['clientAuthorized'] == true
        : readiness['clientTransportAuthorized'] == true;
    final platformTransport = asMap(readiness['platformTransport']);
    final platformTransportAvailable = snapAvailable
        ? snapTransport['platformAvailable'] == true
        : platformTransport['available'] == true;
    final mailboxIsClientOwned = mailbox['isClientOwned'] == true;
    final mailboxIsPlatformBootstrap =
        mailbox['isPlatformBootstrap'] == true;

    final dispatchRows = dispatches.take(8).map((raw) {
      final m = asMap(raw);
      return _MailboxRow(
        title: readText(m, 'subject',
            fallback:
                readText(m, 'recipientEmail', fallback: 'Outbound dispatch')),
        primary: [
          titleCase(readText(m, 'status')),
          readText(m, 'recipientEmail'),
        ].where((value) => value.isNotEmpty).join(' · '),
        secondary: [
          dateLabel(m['sentAt']),
          dateLabel(m['createdAt']),
        ].where((value) => value.isNotEmpty).join(' · '),
      );
    }).toList();

    // Build a dependency-aware readiness chain. The directive forbids
    // "lost authorization" language when no mailbox was ever connected
    // and forbids downstream steps showing "Needs you" when they are
    // actually waiting on a prerequisite. The chain order:
    //   1. Sending domain attached
    //   2. Transport / mailbox connected
    //   3. Connection authorized
    //   4. Sending identity verified (DNS)
    final domainAttached = sendingDomain.isNotEmpty &&
        readText(sendingDomain, 'domain').trim().isNotEmpty &&
        readText(sendingDomain, 'status').toLowerCase() != 'no_domain';
    // CRITICAL: `hasMailbox` here means "has a CLIENT-authorized sending
    // mailbox." A platform/bootstrap mailbox that happens to be present
    // does NOT count — even if the backend echoes a mailbox object,
    // we treat it as missing for client transport readiness purposes.
    final hasMailbox = clientTransportAuthorized ||
        (mailbox.isNotEmpty && mailboxIsClientOwned && !mailboxIsPlatformBootstrap);
    final connectedFlag = readText(mailbox, 'connected').toLowerCase() == 'true';
    final verifiedFlag = readText(mailbox, 'verified').toLowerCase() == 'true';
    final dnsVerified = sendingDomain['ready'] == true;

    final identitySteps = <_IdentityStep>[
      _IdentityStep(
        label: 'Sending domain attached',
        complete: domainAttached,
        badge: domainAttached ? 'Attached' : 'Needs you',
        description: domainAttached
            ? 'Sending domain: ${readText(sendingDomain, 'domain')}.'
            : 'Confirm or attach the domain Orchestrate will dispatch from. Use the panel above.',
      ),
      _IdentityStep(
        label: 'Sending transport connected',
        complete: hasMailbox,
        badge: hasMailbox
            ? 'Connected'
            : domainAttached
                ? 'Needs you'
                : 'Waiting for domain',
        description: hasMailbox
            ? 'Connected: ${readText(mailbox, 'address', fallback: readText(mailbox, 'fromEmail'))}.'
            : domainAttached
                ? 'Choose a sending transport: Google, Microsoft 365, or custom SMTP.'
                : 'Attach a sending domain first; the transport layer plugs into it.',
      ),
      _IdentityStep(
        label: 'Connection authorized',
        complete: connectedFlag,
        // Critical truthfulness fix: only report "lost authorization"
        // if a mailbox actually exists. Without one, this step is
        // waiting on the transport, not on a re-grant.
        badge: connectedFlag
            ? 'Authorized'
            : hasMailbox
                ? 'Reconnect required'
                : 'Waiting for transport',
        description: connectedFlag
            ? 'The transport is connected and authorized for sending.'
            : hasMailbox
                ? 'The connected transport is no longer authorized. Reconnect to resume.'
                : 'No transport is connected yet, so there is no OAuth grant to maintain.',
      ),
      _IdentityStep(
        label: 'Sending identity verified (SPF / DKIM / DMARC)',
        complete: dnsVerified || verifiedFlag,
        badge: (dnsVerified || verifiedFlag)
            ? 'Verified'
            : domainAttached
                ? 'DNS pending'
                : 'Waiting for domain',
        description: (dnsVerified || verifiedFlag)
            ? 'SPF, DKIM, and DMARC all matched at the last DNS check.'
            : domainAttached
                ? 'Publish the SPF / DKIM / DMARC records shown in the Sending domain panel above, then check verification.'
                : 'Attach a sending domain to see the SPF / DKIM / DMARC records to publish.',
      ),
    ];

    final providerAvailability = _readProviderAvailability(providers);

    final primaryActions = _primaryActionsFor(
      blockers: blockers,
      mailbox: mailbox,
      ready: ready,
      availability: providerAvailability,
      clientTransportAuthorized: clientTransportAuthorized,
    );

    final hero = _heroFor(
      ready: ready,
      hasMailbox: hasMailbox,
      platformTransportAvailable: platformTransportAvailable,
      blockers: blockers,
    );

    final sendingIdentity = _readSendingDomain(sendingDomain);

    final operationalIdentity = _buildOperationalIdentity(
      profile: profile,
      mailbox: mailbox,
      sendingIdentity: sendingIdentity,
      ready: ready,
    );

    // Snapshot-driven banner overrides. When the snapshot is
    // present, it dictates header label / banner title / banner
    // message — the legacy hero composer is only a fallback.
    final effectiveBannerTitle = snapAvailable
        ? (snapBanner['title']?.toString() ?? hero.bannerTitle)
        : hero.bannerTitle;
    final effectiveBannerMessage = snapAvailable
        ? (snapBanner['message']?.toString() ?? hero.bannerMessage)
        : hero.bannerMessage;
    final effectiveBannerTone = snapAvailable
        ? _bannerToneFrom(snapBanner['tone']?.toString())
        : hero.bannerTone;
    final effectiveHeadline = snapAvailable
        ? (snapshot['headerStateLabel']?.toString() ?? hero.headline)
        : hero.headline;
    final effectiveSubtitle = snapAvailable
        ? (snapDispatch['blockerMessage']?.toString() ?? hero.subtitle)
        : hero.subtitle;

    final mailboxId = readText(mailbox, 'id');
    final mailboxProvider = readText(mailbox, 'provider').toUpperCase();
    return _MailboxViewData(
      dispatchCount: dispatches.length,
      replyCount: replies.length,
      noticeCount: notices.length,
      headline: effectiveHeadline,
      subtitle: effectiveSubtitle,
      bannerTitle: effectiveBannerTitle,
      bannerMessage: effectiveBannerMessage,
      bannerTone: effectiveBannerTone,
      dispatchRows: dispatchRows,
      identitySteps: identitySteps,
      primaryActions: primaryActions,
      sendingIdentity: sendingIdentity,
      providerAvailability: providerAvailability,
      operationalIdentity: operationalIdentity,
      mailboxId: mailboxId,
      mailboxProvider: mailboxProvider,
      clientTransportAuthorized: clientTransportAuthorized,
      platformTransportAvailable: platformTransportAvailable,
      snapshot: snapshot,
    );
  }

  /// Map the snapshot's `banner.tone` string to the ClientBannerTone
  /// enum. Defaults to warning when the value is unrecognised.
  ClientBannerTone _bannerToneFrom(String? tone) {
    switch (tone) {
      case 'success':
        return ClientBannerTone.success;
      case 'error':
        return ClientBannerTone.warning; // error tone maps to warning in this design
      default:
        return ClientBannerTone.warning;
    }
  }

  /// Maps the backend availability list into a `{providerKey: state}`
  /// lookup. Missing keys default to `unknown`, which the UI renders
  /// as a neutral "Provider availability is unknown" — never as a
  /// Connect button that would dead-end.
  Map<String, _ProviderAvailabilityEntry> _readProviderAvailability(
    List<Map<String, dynamic>> list,
  ) {
    final out = <String, _ProviderAvailabilityEntry>{};
    for (final raw in list) {
      final key = readText(raw, 'key').toLowerCase();
      if (key.isEmpty) continue;
      final reason = readText(raw, 'reason');
      out[key] = _ProviderAvailabilityEntry(
        key: key,
        label: readText(raw, 'label', fallback: _providerLabel(key)),
        available: raw['available'] == true,
        reason: reason.isEmpty ? null : reason,
      );
    }
    return out;
  }

  /// Domain-first operational identity composition. The five-layer
  /// hierarchy the directive prescribes — business → domain → mailbox
  /// → provider → trust → dispatch — derived from real fields with
  /// honest inference where direct data is absent.
  _OperationalIdentity _buildOperationalIdentity({
    required Map<String, dynamic> profile,
    required Map<String, dynamic> mailbox,
    required _SendingIdentity sendingIdentity,
    required bool ready,
  }) {
    final business = readText(profile, 'legalName',
        fallback: readText(profile, 'displayName'));
    final websiteUrl = readText(profile, 'websiteUrl');
    final mailboxAddress = readText(mailbox, 'address',
        fallback: readText(mailbox, 'fromEmail'));

    // Domain inference: prefer the configured sending domain, then the
    // mailbox address domain (after @), then the representation website
    // host. Each fallback is honest — we label the source.
    String domain = sendingIdentity.present ? sendingIdentity.domain : '';
    String domainSource = sendingIdentity.present && domain.isNotEmpty
        ? 'configured'
        : '';
    if (domain.isEmpty && mailboxAddress.contains('@')) {
      domain = mailboxAddress.split('@').last.trim();
      if (domain.isNotEmpty) domainSource = 'inferred_from_mailbox';
    }
    if (domain.isEmpty && websiteUrl.isNotEmpty) {
      final uri = Uri.tryParse(websiteUrl);
      final host = uri?.host ?? '';
      if (host.isNotEmpty) {
        domain = host.replaceFirst(RegExp(r'^www\.'), '');
        domainSource = 'inferred_from_representation';
      }
    }

    final providerCode = readText(mailbox, 'provider').toUpperCase();
    // PROVIDER CODES ARE IDENTIFIERS, NOT NAMES. IMAP_SMTP was rendering to
    // customers exactly like that, underscore and all, in the row that tells
    // them who carries their mail.
    final providerLabel = _providerName(providerCode);
    final authorized = readText(mailbox, 'connected').toLowerCase() == 'true';

    return _OperationalIdentity(
      businessName: business,
      domain: domain,
      domainSource: domainSource,
      mailboxAddress: mailboxAddress,
      providerLabel: providerLabel,
      authorized: authorized,
      sendingIdentityReady: sendingIdentity.ready,
      sendingIdentityStatus: sendingIdentity.status,
      dispatchEligible: ready,
    );
  }

  _SendingIdentity _readSendingDomain(Map<String, dynamic> map) {
    // Treat both an empty payload and the backend's explicit no_domain
    // sentinel (returned when no SendingDomain row exists) as "not
    // attached" so downstream UI surfaces the empty-state path instead
    // of rendering "Domain: not yet attached" with a blank value.
    final status = readText(map, 'status').toLowerCase();
    final domainValue = readText(map, 'domain').trim();
    if (map.isEmpty || status == 'no_domain' || domainValue.isEmpty) {
      return const _SendingIdentity(
        present: false,
        domain: '',
        status: 'no_domain',
        ready: false,
        verifiedAt: null,
        lastCheckedAt: null,
        failedReason: null,
        records: <_DnsRecord>[],
        history: <_VerificationCheck>[],
      );
    }
    final rawRecords = asList(map['records']);
    final records = rawRecords
        .map(asMap)
        .where((entry) => entry.isNotEmpty)
        .map(
          (entry) => _DnsRecord(
            purpose: readText(entry, 'purpose'),
            type: readText(entry, 'type'),
            host: readText(entry, 'host'),
            expectedValue: readText(entry, 'expectedValue'),
            explanation: readText(entry, 'explanation'),
            matched: entry['matched'] == true,
            errorMessage: readText(entry, 'errorMessage'),
          ),
        )
        .toList();
    final history = asList(map['verificationHistory'])
        .map(asMap)
        .where((entry) => entry.isNotEmpty)
        .map(
          (entry) => _VerificationCheck(
            id: readText(entry, 'id'),
            checkedAt: readText(entry, 'checkedAt'),
            allMatched: entry['allMatched'] == true,
            status: readText(entry, 'status'),
            failedReason: readText(entry, 'failedReason'),
            perRecord: asList(entry['checks'])
                .map(asMap)
                .map(
                  (raw) => _VerificationCheckRow(
                    purpose: readText(raw, 'purpose'),
                    matched: raw['matched'] == true,
                    errorMessage: readText(raw, 'errorMessage'),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
    return _SendingIdentity(
      present: true,
      domain: readText(map, 'domain'),
      status: readText(map, 'status', fallback: 'pending'),
      ready: map['ready'] == true,
      verifiedAt: readText(map, 'verifiedAt').isEmpty
          ? null
          : readText(map, 'verifiedAt'),
      lastCheckedAt: readText(map, 'lastCheckedAt').isEmpty
          ? null
          : readText(map, 'lastCheckedAt'),
      failedReason: readText(map, 'failedReason').isEmpty
          ? null
          : readText(map, 'failedReason'),
      records: records,
      history: history,
    );
  }

  /// Determines the OAuth connect / reconnect actions to surface as the
  /// page CTAs. Only providers reported as `available: true` by the
  /// backend get a Connect button — providers without configured OAuth
  /// credentials (Microsoft when MICROSOFT_MAILBOX_CLIENT_ID is unset,
  /// for example) are rendered as a neutral "Provider setup pending"
  /// row by the Operational identity panel and not as a CTA. No fake
  /// provider parity.
  List<_MailboxPrimaryAction> _primaryActionsFor({
    required List<Map<String, dynamic>> blockers,
    required Map<String, dynamic> mailbox,
    required bool ready,
    required Map<String, _ProviderAvailabilityEntry> availability,
    required bool clientTransportAuthorized,
  }) {
    if (ready) return const <_MailboxPrimaryAction>[];

    final byCode = <String, Map<String, dynamic>>{
      for (final blocker in blockers) readText(blocker, 'code'): blocker,
    };
    // Critical: "hasMailbox" for action visibility purposes means
    // "has a CLIENT-authorized transport." Bootstrap rows are not
    // counted — even if the readiness response echoes a mailbox
    // object, that object may be a platform/bootstrap row. Connect
    // actions must remain visible until the tenant authorizes its
    // own transport.
    final mailboxIsClientOwned = mailbox['isClientOwned'] == true;
    final mailboxIsPlatformBootstrap =
        mailbox['isPlatformBootstrap'] == true;
    final hasMailbox = clientTransportAuthorized ||
        (mailbox.isNotEmpty &&
            mailboxIsClientOwned &&
            !mailboxIsPlatformBootstrap);
    final providerRaw = readText(mailbox, 'provider').toUpperCase();
    final mailboxId =
        readText(mailbox, 'id').isEmpty ? null : readText(mailbox, 'id');

    bool isAvailable(String key) {
      final entry = availability[key];
      // If the backend signal is missing entirely, fall back to optimistic
      // visibility so the experience does not regress when the new
      // endpoint is not yet deployed. Only suppress a button when the
      // backend explicitly reports `available: false`.
      if (entry == null) return availability.isEmpty;
      return entry.available;
    }

    List<_MailboxPrimaryAction> connectActions({String? mailboxId}) {
      final actions = <_MailboxPrimaryAction>[];
      if (isAvailable('google')) {
        actions.add(_MailboxPrimaryAction(
          code: 'connect_google',
          label: mailboxId == null
              ? 'Connect a Google mailbox'
              : 'Reconnect Google mailbox',
          icon: Icons.alternate_email,
          oauthProvider: 'google',
          mailboxId: mailboxId,
        ));
      }
      if (isAvailable('microsoft')) {
        actions.add(_MailboxPrimaryAction(
          code: 'connect_microsoft',
          label: mailboxId == null
              ? 'Connect a Microsoft 365 mailbox'
              : 'Reconnect Microsoft 365 mailbox',
          icon: Icons.business_center_outlined,
          oauthProvider: 'microsoft',
          mailboxId: mailboxId,
        ));
      }
      return actions;
    }

    // Mailbox provider configuration is Orchestrate-side. No client CTA.
    if (byCode.containsKey('MAILBOX_PROVIDER_ERROR')) {
      return const <_MailboxPrimaryAction>[];
    }

    if (byCode.containsKey('MAILBOX_MISSING') || !hasMailbox) {
      return connectActions();
    }

    if (byCode.containsKey('MAILBOX_DISCONNECTED') ||
        byCode.containsKey('MAILBOX_UNVERIFIED')) {
      final provider = providerRaw == 'GOOGLE' || providerRaw == 'MICROSOFT'
          ? providerRaw.toLowerCase()
          : null;
      if (provider != null && isAvailable(provider)) {
        return <_MailboxPrimaryAction>[
          _MailboxPrimaryAction(
            code: 'reconnect_$provider',
            label: 'Reconnect ${_providerLabel(provider)}',
            icon: Icons.link,
            oauthProvider: provider,
            mailboxId: mailboxId,
          ),
        ];
      }
      // Either the original provider is now unavailable, or we never
      // recorded one. Offer whichever providers are currently available.
      return connectActions(mailboxId: mailboxId);
    }

    return const <_MailboxPrimaryAction>[];
  }

  _MailboxHero _heroFor({
    required bool ready,
    required bool hasMailbox,
    required bool platformTransportAvailable,
    required List<Map<String, dynamic>> blockers,
  }) {
    if (ready) {
      return const _MailboxHero(
        headline: 'Client-authorized transport active',
        subtitle:
            'Your sending mailbox is authorised and replies come back to it. '
            'Orchestrate sends from here on your behalf.',
        bannerTitle: 'Dispatch eligibility granted',
        bannerMessage:
            'No action required here unless your provider asks you to re-authorize the OAuth grant.',
        bannerTone: ClientBannerTone.success,
      );
    }
    final providerError = blockers
        .any((b) => readText(b, 'code') == 'MAILBOX_PROVIDER_ERROR');
    if (providerError) {
      return const _MailboxHero(
        headline: 'Orchestrate is restoring outbound delivery',
        subtitle:
            'Our outbound provider configuration is being repaired. No client action is required.',
        bannerTitle: 'Orchestrate is handling this',
        bannerMessage:
            'Dispatch eligibility resumes once provider configuration is restored. Contact support if this persists.',
        bannerTone: ClientBannerTone.warning,
      );
    }
    if (!hasMailbox) {
      if (platformTransportAvailable) {
        return const _MailboxHero(
          headline: 'Authorize your sending mailbox',
          subtitle:
              'Platform transport handles Orchestrate correspondence only. Connect Google, Microsoft 365, or SMTP+IMAP to enable managed dispatch.',
          bannerTitle: 'Client transport authorization required',
          bannerMessage:
              'Platform transport cannot send on your behalf. Connect your mailbox to enable dispatch.',
          bannerTone: ClientBannerTone.warning,
        );
      }
      return const _MailboxHero(
        headline: 'Attach sending infrastructure',
        subtitle:
            'Orchestrate dispatches from your domain. Attach the sending domain first; SPF and DMARC are available immediately. The transport layer plugs in beneath.',
        bannerTitle: 'Sending infrastructure is incomplete',
        bannerMessage:
            'Attach a sending domain in the panel below, then choose a transport. Dispatch eligibility is granted once both layers and DNS verification clear.',
        bannerTone: ClientBannerTone.warning,
      );
    }
    return const _MailboxHero(
      headline: 'Finish verifying your sending identity',
      subtitle:
          'A client transport is connected but one identity layer is still pending. Resolve it to unlock dispatch eligibility.',
      bannerTitle: 'One identity layer remaining',
      bannerMessage:
          'Resolve the pending identity layer. Dispatch eligibility is granted as soon as it clears.',
      bannerTone: ClientBannerTone.warning,
    );
  }
}

class _MailboxViewData {
  const _MailboxViewData({
    required this.dispatchCount,
    required this.replyCount,
    required this.noticeCount,
    required this.headline,
    required this.subtitle,
    required this.bannerTitle,
    required this.bannerMessage,
    required this.bannerTone,
    required this.dispatchRows,
    required this.identitySteps,
    required this.primaryActions,
    required this.sendingIdentity,
    required this.providerAvailability,
    required this.operationalIdentity,
    required this.mailboxId,
    required this.mailboxProvider,
    required this.clientTransportAuthorized,
    required this.platformTransportAvailable,
    required this.snapshot,
  });

  /// Raw canonical snapshot map — the SINGLE source of truth for
  /// every panel. Empty when the snapshot endpoint was unreachable.
  final Map<String, dynamic> snapshot;

  final int dispatchCount;
  final int replyCount;
  final int noticeCount;
  final String headline;
  final String subtitle;
  final String bannerTitle;
  final String bannerMessage;
  final ClientBannerTone bannerTone;
  final List<_MailboxRow> dispatchRows;
  final List<_IdentityStep> identitySteps;
  final List<_MailboxPrimaryAction> primaryActions;
  final _SendingIdentity sendingIdentity;
  final Map<String, _ProviderAvailabilityEntry> providerAvailability;
  final _OperationalIdentity operationalIdentity;
  final String mailboxId;
  final String mailboxProvider;
  /// True only when a CLIENT-owned, AUTHORIZED transport row exists.
  /// Platform/bootstrap availability does NOT flip this.
  final bool clientTransportAuthorized;
  /// True when a platform/bootstrap transport is reachable. Surfaced
  /// for UI disclosure only — never as a substitute for client
  /// transport authorization.
  final bool platformTransportAvailable;

  /// True when the mailbox is on a provider-owned consumer domain
  /// (gmail.com, …). DNS sending-identity verification does not apply —
  /// the Infrastructure page renders the personal-mailbox panel instead
  /// of impossible SPF / DKIM / DMARC tasks.
  bool get isPersonalProvider =>
      (snapshot['identityClass']?.toString() ?? '') == 'PERSONAL_PROVIDER';

  /// Optional upgrade-path descriptor — present only for personal
  /// mailboxes. Empty map otherwise.
  Map<String, dynamic> get upgradePath {
    final raw = snapshot['upgradePath'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((k, v) => MapEntry('$k', v));
    return const <String, dynamic>{};
  }
}

/// Sending-identity panel for PERSONAL_PROVIDER mailboxes (gmail.com,
/// outlook.com, …). The client does not control DNS for a provider-owned
/// consumer domain, so SPF / DKIM / DMARC verification is impossible —
/// this panel fully replaces the DNS-records panel and never shows a DNS
/// task. It states the truthful readiness: transport authorized, limited
/// dispatch eligible, business sending identity not configured — plus an
/// optional upgrade path to a verified domain identity.
class _PersonalMailboxPanel extends StatelessWidget {
  const _PersonalMailboxPanel({
    required this.mailboxAddress,
    required this.upgradePath,
  });

  final String mailboxAddress;
  final Map<String, dynamic> upgradePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = (upgradePath['steps'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final upgradeHeadline = (upgradePath['headline'] ?? '').toString();
    final upgradeDetail = (upgradePath['detail'] ?? '').toString();
    return ClientPanel(
      title: 'Personal mailbox',
      subtitle:
          'This mailbox is on a provider-owned consumer domain. You do not '
          'control its DNS, so SPF / DKIM / DMARC verification does not apply '
          'and is never required here.',
      children: [
        ClientInfoRow(
          title: 'Personal mailbox connected',
          primary: 'OAuth transport authorization completed successfully.',
          secondary:
              'Provider reputation is inherited from the mailbox provider.',
          trailing: const ClientBadge(label: 'Connected'),
        ),
        ClientInfoRow(
          title: 'Transport authorized',
          primary: mailboxAddress.trim().isEmpty
              ? 'Mailbox transport is authorized for sending.'
              : 'Authorized for $mailboxAddress.',
        ),
        ClientInfoRow(
          title: 'Limited dispatch eligible',
          primary:
              'Managed execution can dispatch at the limited personal-mailbox '
              'tier with conservative throughput and pacing.',
          secondary:
              'Suitable for onboarding, small operators, and early-stage use.',
          trailing: const ClientBadge(label: 'Limited tier'),
        ),
        const ClientInfoRow(
          title: 'Business sending identity not configured',
          primary:
              'No verified business domain is attached. A verified sending '
              'identity is optional for a personal mailbox.',
        ),
        if (upgradeHeadline.isNotEmpty || steps.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.publicSurfaceSoft,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upgradeHeadline.isEmpty
                      ? 'Upgrade to a verified domain identity'
                      : upgradeHeadline,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (upgradeDetail.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(upgradeDetail, style: theme.textTheme.bodyMedium),
                ],
                if (steps.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final step in steps)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '•  $step',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ProviderAvailabilityEntry {
  const _ProviderAvailabilityEntry({
    required this.key,
    required this.label,
    required this.available,
    required this.reason,
  });

  final String key;
  final String label;
  final bool available;
  final String? reason;
}

class _OperationalIdentity {
  const _OperationalIdentity({
    required this.businessName,
    required this.domain,
    required this.domainSource,
    required this.mailboxAddress,
    required this.providerLabel,
    required this.authorized,
    required this.sendingIdentityReady,
    required this.sendingIdentityStatus,
    required this.dispatchEligible,
  });

  final String businessName;
  final String domain;
  /// 'configured' | 'inferred_from_mailbox' | 'inferred_from_representation' | ''
  final String domainSource;
  final String mailboxAddress;
  final String providerLabel;
  final bool authorized;
  final bool sendingIdentityReady;
  final String sendingIdentityStatus;
  final bool dispatchEligible;
}

class _SendingIdentity {
  const _SendingIdentity({
    required this.present,
    required this.domain,
    required this.status,
    required this.ready,
    required this.verifiedAt,
    required this.lastCheckedAt,
    required this.failedReason,
    required this.records,
    required this.history,
  });

  final bool present;
  final String domain;
  final String status;
  final bool ready;
  final String? verifiedAt;
  final String? lastCheckedAt;
  final String? failedReason;
  final List<_DnsRecord> records;
  final List<_VerificationCheck> history;
}

class _VerificationCheck {
  const _VerificationCheck({
    required this.id,
    required this.checkedAt,
    required this.allMatched,
    required this.status,
    required this.failedReason,
    required this.perRecord,
  });

  final String id;
  final String checkedAt;
  final bool allMatched;
  final String status;
  final String failedReason;
  final List<_VerificationCheckRow> perRecord;
}

class _VerificationCheckRow {
  const _VerificationCheckRow({
    required this.purpose,
    required this.matched,
    required this.errorMessage,
  });

  final String purpose;
  final bool matched;
  final String errorMessage;
}

class _DnsRecord {
  const _DnsRecord({
    required this.purpose,
    required this.type,
    required this.host,
    required this.expectedValue,
    required this.explanation,
    required this.matched,
    required this.errorMessage,
  });

  final String purpose;
  final String type;
  final String host;
  final String expectedValue;
  final String explanation;
  final bool matched;
  final String errorMessage;
}

class _MailboxHero {
  const _MailboxHero({
    required this.headline,
    required this.subtitle,
    required this.bannerTitle,
    required this.bannerMessage,
    required this.bannerTone,
  });

  final String headline;
  final String subtitle;
  final String bannerTitle;
  final String bannerMessage;
  final ClientBannerTone bannerTone;
}

class _MailboxRow {
  const _MailboxRow({
    required this.title,
    required this.primary,
    required this.secondary,
  });

  final String title;
  final String primary;
  final String secondary;
}

class _IdentityStep {
  const _IdentityStep({
    required this.label,
    required this.complete,
    required this.description,
    required this.badge,
  });

  final String label;
  final bool complete;
  final String description;
  final String badge;
}

/// Explicit panel that names the platform-bootstrap transport vs the
/// client-authorized transport. The bootstrap transport exists for
/// Orchestrate-owned correspondence and platform operations only —
/// it cannot send on behalf of any client tenant. This panel makes
/// the distinction visible so users do not mistake "platform
/// reachable" for "client dispatch authorized."
class _TransportAuthorityPanel extends StatelessWidget {
  const _TransportAuthorityPanel({
    required this.clientTransportAuthorized,
    required this.platformTransportAvailable,
  });

  final bool clientTransportAuthorized;
  final bool platformTransportAvailable;

  @override
  Widget build(BuildContext context) {
    return ClientPanel(
      title: 'Transport authority',
      subtitle:
          'Platform transport handles Orchestrate correspondence only. Client dispatch requires your mailbox.',
      children: [
        ClientInfoRow(
          title: 'Platform transport (Orchestrate-owned)',
          primary: platformTransportAvailable
              ? 'Available. Handles platform/system correspondence only.'
              : 'Not detected.',
          trailing: ClientBadge(
            label: platformTransportAvailable ? 'Available' : 'Not detected',
          ),
        ),
        ClientInfoRow(
          title: 'Client-authorized transport (tenant-owned)',
          primary: clientTransportAuthorized
              ? 'Authorized. Managed dispatch and reply continuity are eligible.'
              : 'Not authorized. Managed dispatch is held until a client-owned mailbox is connected (Google, Microsoft 365, or SMTP+IMAP).',
          trailing: ClientBadge(
            label:
                clientTransportAuthorized ? 'Authorized' : 'Authorization required',
          ),
        ),
        ClientInfoRow(
          title: 'Dispatch eligibility',
          primary: clientTransportAuthorized
              ? 'Eligible. The runtime line on Home reports whether dispatch is in flight right now.'
              : (platformTransportAvailable
                  ? 'Blocked. Managed dispatch requires a client-authorized mailbox.'
                  : 'Blocked. Neither client transport nor platform transport is currently authoritative.'),
          trailing: ClientBadge(
            label: clientTransportAuthorized ? 'Eligible' : 'Blocked',
          ),
        ),
      ],
    );
  }
}

/// Single primary-status card. Above-the-fold authority on the
/// Infrastructure page. Derives from `snapshot.primaryAction` and
/// `snapshot.dispatch.blockerMessage`. No competing copy.
class _PrimaryStatusCard extends StatelessWidget {
  const _PrimaryStatusCard({required this.snapshot});

  final Map<String, dynamic> snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (snapshot.isEmpty) return const SizedBox.shrink();
    final primaryAction = (snapshot['primaryAction'] ?? 'none').toString();
    final primaryActionLabel =
        (snapshot['primaryActionLabel'] ?? '').toString();
    final dispatch = _asMap(snapshot['dispatch']);
    final transport = _asMap(snapshot['transport']);
    final domain = _asMap(snapshot['domain']);
    final blockerMessage = (dispatch['blockerMessage'] ?? '').toString();
    final ready = dispatch['eligible'] == true;
    final headlineLabel =
        (snapshot['headerStateLabel'] ?? '').toString();
    final mailboxAddress = (_asMap(transport['mailbox'])['address'] ?? '')
        .toString();
    final dnsVerified = domain['dnsVerified'] == true;

    Color borderColor;
    Color iconColor;
    IconData icon;
    if (ready) {
      borderColor = Colors.green.shade400;
      iconColor = Colors.green.shade700;
      icon = Icons.check_circle;
    } else if (primaryAction == 'resolve_runtime_egress') {
      borderColor = Colors.red.shade400;
      iconColor = Colors.red.shade700;
      icon = Icons.cloud_off_outlined;
    } else if (primaryAction == 'reauthorize_provider' ||
        primaryAction == 'connect_mailbox') {
      borderColor = Colors.orange.shade400;
      iconColor = Colors.orange.shade800;
      icon = Icons.email_outlined;
    } else if (primaryAction == 'publish_dns' || primaryAction == 'verify_dns') {
      borderColor = Colors.orange.shade400;
      iconColor = Colors.orange.shade800;
      icon = Icons.dns_outlined;
    } else {
      borderColor = Colors.orange.shade400;
      iconColor = Colors.orange.shade800;
      icon = Icons.info_outline;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headlineLabel.isEmpty
                          ? (ready ? 'Dispatch ready' : 'Action required')
                          : headlineLabel,
                      style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (primaryAction != 'none' &&
                        primaryActionLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Next: $primaryActionLabel',
                        style: theme.textTheme.bodyMedium?.copyWith(
                              color: iconColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (blockerMessage.isNotEmpty && !ready) ...[
            const SizedBox(height: 12),
            Text(
              blockerMessage,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (ready && mailboxAddress.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Operational mailbox: $mailboxAddress'
              '${dnsVerified ? '  ·  SPF / DKIM / DMARC verified' : ''}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, x) => MapEntry('$k', x));
    return const <String, dynamic>{};
  }
}

/// Thin one-line "Last action" indicator. Replaces the previous
/// "Latest result" panel that visually competed with canonical
/// state for primacy.
class _LastActionLine extends StatelessWidget {
  const _LastActionLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.history, size: 14, color: Colors.blueGrey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Last action: $message',
              style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blueGrey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SendingDomainPanel extends StatelessWidget {
  const _SendingDomainPanel({
    required this.identity,
    required this.inferredDomain,
    required this.inferredDomainSource,
    required this.attaching,
    required this.verifying,
    required this.onAttach,
    required this.onVerify,
    required this.domainController,
  });

  final _SendingIdentity identity;
  /// Domain inferred from representation or mailbox identity. Used
  /// when no SendingDomain row exists yet so the empty state still
  /// names a concrete domain rather than reading as blank.
  final String inferredDomain;
  final String inferredDomainSource;
  final bool attaching;
  final bool verifying;
  final Future<void> Function(String domain) onAttach;
  final VoidCallback onVerify;
  final TextEditingController domainController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!identity.present) {
      // Domain identity is primary. The user must be able to attach a
      // domain BEFORE selecting a transport. Prefill the text field
      // with the inferred domain (from Representation or mailbox)
      // when available so the action is one tap.
      final inferred = inferredDomain.trim();
      if (inferred.isNotEmpty && domainController.text.isEmpty) {
        domainController.text = inferred;
      }
      final sourceLabel = inferredDomainSource == 'inferred_from_mailbox'
          ? 'your connected mailbox'
          : inferredDomainSource == 'inferred_from_representation'
              ? 'your Representation profile'
              : null;
      return ClientPanel(
        title: 'Sending domain',
        subtitle:
            'The domain Orchestrate dispatches from. SPF and DMARC are available immediately after attaching. DKIM keys are generated when you connect a transport.',
        children: [
          if (inferred.isNotEmpty && sourceLabel != null) ...[
            Text(
              'Detected $inferred from $sourceLabel.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: domainController,
                  decoration: const InputDecoration(
                    labelText: 'Sending domain',
                    hintText: 'e.g. outreach.company.com',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  enabled: !attaching,
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: attaching
                    ? null
                    : () => onAttach(domainController.text),
                icon: attaching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link, size: 18),
                label: Text(attaching ? 'Attaching' : 'Attach domain'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Examples: auraplatform.org, outreach.company.com, mail.company.com. Any apex or subdomain you control.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    }
    final hasDomain = identity.domain.trim().isNotEmpty;
    final subtitleParts = <String>[
      hasDomain ? 'Domain: ${identity.domain}' : 'Domain: not yet attached',
      identity.ready ? 'Verified at last DNS check' : 'Verification pending',
      if (identity.verifiedAt != null && identity.verifiedAt!.isNotEmpty)
        'Verified ${dateLabel(identity.verifiedAt)}',
      if (identity.lastCheckedAt != null && identity.lastCheckedAt!.isNotEmpty)
        'Last checked ${dateLabel(identity.lastCheckedAt)}',
    ];
    return ClientPanel(
      title: identity.ready
          ? 'Sending domain verified'
          : 'Publish these DNS records to verify your sending domain',
      subtitle: subtitleParts.join(' · '),
      children: [
        for (final record in identity.records) ...[
          ClientInfoRow(
            title: '${record.purpose.toUpperCase()} · ${record.type}',
            primary: 'Host: ${record.host}',
            secondary:
                'Expected: ${record.expectedValue}${record.errorMessage.isNotEmpty ? ' · ${record.errorMessage}' : ''}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClientBadge(label: record.matched ? 'Found' : 'Missing'),
                const SizedBox(width: 6),
                _CopyRecordButton(host: record.host, value: record.expectedValue),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 0, bottom: 4),
            child: Text(
              record.explanation,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
        if (identity.failedReason != null && identity.failedReason!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              identity.failedReason!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.icon(
              onPressed: verifying ? null : onVerify,
              icon: verifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined, size: 18),
              label: Text(verifying ? 'Checking' : 'Check verification'),
            ),
            const SizedBox(width: 8),
            WhyAffordance(
              target: identity.ready
                  ? GuidanceTarget.sendingIdentity
                  : GuidanceTarget.dnsVerificationPending,
              surface: 'client_mailbox_sending_identity_panel',
              label: 'Explain this state',
            ),
          ],
        ),
        if (identity.history.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Recent verification checks',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Orchestrate re-checks pending domains automatically. This is the recent history so you can watch DNS propagation.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 8),
          for (final check in identity.history)
            _VerificationCheckTile(check: check),
        ],
      ],
    );
  }
}

class _VerificationCheckTile extends StatelessWidget {
  const _VerificationCheckTile({required this.check});

  final _VerificationCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final breakdown = check.perRecord
        .map((row) => '${row.purpose.toUpperCase()}: ${row.matched ? 'OK' : 'missing'}')
        .join(' · ');
    final secondary = [
      breakdown,
      if (!check.allMatched && check.failedReason.isNotEmpty)
        check.failedReason,
    ].where((s) => s.isNotEmpty).join(' · ');
    return ClientInfoRow(
      title: dateLabel(check.checkedAt),
      primary: check.allMatched
          ? 'All DNS records found'
          : 'Verification did not pass',
      secondary: secondary,
      trailing: ClientBadge(label: check.allMatched ? 'Pass' : 'Pending'),
    );
  }
}

class _MailboxPrimaryAction {
  const _MailboxPrimaryAction({
    required this.code,
    required this.label,
    required this.icon,
    required this.oauthProvider,
    this.mailboxId,
  });

  final String code;
  final String label;
  final IconData icon;
  /// "google" | "microsoft" — passed to /client/mailbox/oauth/{provider}/start.
  final String oauthProvider;
  /// Set when reauthing an existing REQUIRES_REAUTH / DISCONNECTED mailbox.
  final String? mailboxId;
}

/// Domain-first operational identity. Renders the five-layer hierarchy
/// the directive prescribes — business → domain → mailbox → provider →
/// trust → dispatch — so the client domain identity is the conceptual
/// center, not the provider. Each row reports the truthful current
/// state; missing layers render as explicit "not yet" rather than
/// blank or optimistic.
class _OperationalIdentityPanel extends StatelessWidget {
  const _OperationalIdentityPanel({
    required this.identity,
    required this.providerAvailability,
  });

  final _OperationalIdentity identity;
  final Map<String, _ProviderAvailabilityEntry> providerAvailability;

  @override
  Widget build(BuildContext context) {
    final domainPrimary = identity.domain.isNotEmpty
        ? identity.domain
        : 'No sending domain configured';
    final domainSecondary = _domainSourceLabel(identity.domainSource);
    final mailboxPrimary = identity.mailboxAddress.isNotEmpty
        ? identity.mailboxAddress
        : 'No operational mailbox connected';
    final providerPrimary = identity.providerLabel.isNotEmpty
        ? identity.providerLabel
        : 'No provider connected';
    final providerSecondary = _providerSecondary();
    final trustPrimary = identity.sendingIdentityReady
        ? 'SPF / DKIM / DMARC matched at the last DNS check'
        : 'SPF / DKIM / DMARC verification pending';
    final trustBadge =
        identity.sendingIdentityReady ? 'Verified' : 'Pending';
    final dispatchPrimary = identity.dispatchEligible
        ? 'Dispatch eligibility granted'
        : 'Dispatch eligibility pending. Each layer above must be verified.';
    final dispatchBadge =
        identity.dispatchEligible ? 'Eligible' : 'Blocked';

    return ClientPanel(
      title: 'Operational identity',
      subtitle:
          'Orchestrate operates against your domain identity. Provider infrastructure is interchangeable beneath it.',
      children: [
        ClientInfoRow(
          title: 'Business',
          primary: identity.businessName.isNotEmpty
              ? identity.businessName
              : 'Business identity not yet recorded',
        ),
        ClientInfoRow(
          title: 'Sending domain',
          primary: domainPrimary,
          secondary: domainSecondary,
        ),
        ClientInfoRow(
          title: 'Operational mailbox',
          primary: mailboxPrimary,
        ),
        ClientInfoRow(
          title: 'Provider',
          primary: providerPrimary,
          secondary: providerSecondary,
          trailing: identity.providerLabel.isEmpty
              ? null
              : ClientBadge(
                  label: identity.authorized ? 'Authorized' : 'Not authorized',
                ),
        ),
        ClientInfoRow(
          title: 'Trust (SPF · DKIM · DMARC)',
          primary: trustPrimary,
          trailing: ClientBadge(label: trustBadge),
        ),
        ClientInfoRow(
          title: 'Dispatch eligibility',
          primary: dispatchPrimary,
          trailing: ClientBadge(label: dispatchBadge),
        ),
        if (_unavailableProviders().isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final entry in _unavailableProviders())
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${entry.label}: setup pending. Not yet operational.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }

  String _domainSourceLabel(String source) {
    switch (source) {
      case 'configured':
        return 'Configured sending domain.';
      case 'inferred_from_mailbox':
        return 'Inferred from the connected mailbox address.';
      case 'inferred_from_representation':
        return 'Inferred from the website on your Representation profile.';
      default:
        return '';
    }
  }

  String _providerSecondary() {
    if (identity.providerLabel.isEmpty) {
      final available = providerAvailability.values
          .where((entry) => entry.available)
          .map((entry) => entry.label)
          .toList();
      if (available.isEmpty) return '';
      return 'Available providers: ${available.join(' · ')}';
    }
    return identity.authorized
        ? 'OAuth grant active.'
        : 'OAuth grant required.';
  }

  List<_ProviderAvailabilityEntry> _unavailableProviders() {
    return providerAvailability.values
        .where((entry) => !entry.available)
        .toList();
  }
}

/// Reply monitoring affordance shown when an SMTP transport is
/// connected but IMAP inbound is not yet attached. Surfaces the
/// truthful state ("Outbound only — reply monitoring pending") and
/// the inline CTA that opens the IMAP onboarding dialog.
class _ReplyMonitoringPanel extends StatelessWidget {
  const _ReplyMonitoringPanel({required this.onAttach});

  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return ClientPanel(
      title: 'Reply monitoring',
      subtitle:
          'Outbound dispatch is connected. Reply ingestion needs IMAP credentials so Orchestrate can match inbound mail to outbound sends, persist replies into the Replies workspace, and suppress pending follow-ups against the same lead automatically.',
      children: [
        ClientInfoRow(
          title: 'IMAP inbound',
          primary:
              'Not attached. Custom transport is operating outbound-only until IMAP credentials are provided.',
          trailing: FilledButton.tonal(
            onPressed: onAttach,
            child: const Text('Attach IMAP inbound'),
          ),
        ),
      ],
    );
  }
}

/// Copy-to-clipboard affordance on each DNS record row. Without this
/// "Check verification" is diagnostic only — clients still have to
/// hand-type SPF / DKIM / DMARC values into their registrar. Copying
/// the host + expected value puts the verification workflow within
/// reach without leaving Infrastructure.
class _CopyRecordButton extends StatefulWidget {
  const _CopyRecordButton({required this.host, required this.value});

  final String host;
  final String value;

  @override
  State<_CopyRecordButton> createState() => _CopyRecordButtonState();
}

class _CopyRecordButtonState extends State<_CopyRecordButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _copy,
      icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
      label: Text(_copied ? 'Copied' : 'Copy value'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 32),
      ),
    );
  }
}

/// Sending transport choices. Providers sit beneath the domain layer:
/// the domain is identity, the transport is interchangeable infrastructure.
/// Connect buttons for Google / Microsoft / SMTP live in the page actions;
/// this panel exists so the client sees the full transport landscape and
/// understands no provider monopolises operational identity.
class _TransportChoicesPanel extends StatelessWidget {
  const _TransportChoicesPanel({
    required this.providerAvailability,
    required this.hasMailbox,
  });

  final Map<String, _ProviderAvailabilityEntry> providerAvailability;
  final bool hasMailbox;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final google = providerAvailability['google'];
    final microsoft = providerAvailability['microsoft'];
    final smtp = providerAvailability['smtp'];
    Widget tile({
      required String title,
      required String body,
      required String badge,
    }) {
      return ClientInfoRow(
        title: title,
        primary: body,
        trailing: ClientBadge(label: badge),
      );
    }

    return ClientPanel(
      title: 'Sending transport',
      subtitle:
          'Transport is interchangeable infrastructure beneath your domain identity. Google, Microsoft 365, and SMTP are all first-class paths.',
      children: [
        tile(
          title: 'Google Workspace mailbox',
          body: google == null
              ? 'OAuth-based connection. Tap "Connect a Google mailbox" in the page header.'
              : google.available
                  ? 'OAuth-based connection. Use the Connect action in the page header.'
                  : 'Provider setup pending. Use SMTP if your infrastructure is ready.',
          badge: google?.available == true ? 'Available' : 'Setup pending',
        ),
        tile(
          title: 'Microsoft 365 mailbox',
          body: microsoft == null
              ? 'OAuth-based connection. Tap "Connect a Microsoft 365 mailbox" in the page header.'
              : microsoft.available
                  ? 'OAuth-based connection. Use the Connect action in the page header.'
                  : 'Provider setup pending. Use SMTP if your infrastructure is ready.',
          badge: microsoft?.available == true ? 'Available' : 'Setup pending',
        ),
        tile(
          title: 'Custom mail transport (SMTP + IMAP)',
          body: smtp?.available == false
              ? 'Provider setup pending.'
              : 'One guided setup configures outbound SMTP and inbound IMAP together. Use any SMTP-capable infrastructure: your own server, SES, Mailgun, SendGrid, Postfix, Zoho, or a regional provider. Orchestrate validates against both hosts before persisting, vaults the credentials, generates DKIM, dispatches with full signing, and matches replies only to operations Orchestrate sent. Tap "Connect custom mail transport" in the page header.',
          badge: smtp?.available == false ? 'Setup pending' : 'Available',
        ),
        if (!hasMailbox) ...[
          const SizedBox(height: 8),
          Text(
            'No transport connected. Domain and DNS setup can happen in parallel with transport selection.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}


/// WHO CARRIES THE MAIL, IN A NAME A PERSON RECOGNISES.
///
/// An unknown code is still shown rather than hidden — knowing it is something
/// beats knowing nothing — but spelled as words rather than as an identifier.
String _providerName(String code) {
  final key = code.trim().toUpperCase();
  if (key.isEmpty) return '';
  const known = {
    'GOOGLE': 'Google Workspace / Gmail',
    'MICROSOFT': 'Microsoft 365',
    'IMAP_SMTP': 'SMTP and IMAP',
    'SMTP': 'SMTP',
    'IMAP': 'IMAP',
  };
  final match = known[key];
  if (match != null) return match;
  return key
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0] + w.substring(1).toLowerCase())
      .join(' ');
}
