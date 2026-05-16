import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:orchestrate_app/data/repositories/client/client_mailbox_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_outreach_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

/// Mailbox is the one infrastructure surface where the client genuinely
/// owns an action: connecting and verifying the sending identity Orchestrate
/// will send outreach from. Everything else (campaign lifecycle, dispatch,
/// recovery) is Orchestrate's responsibility.
///
/// This screen frames mailbox state as identity readiness, not as a console
/// of operational toggles. There is at most one client CTA at a time — the
/// next concrete identity step Orchestrate needs from the client.
class ClientMailboxScreen extends StatefulWidget {
  const ClientMailboxScreen({super.key});

  @override
  State<ClientMailboxScreen> createState() => _ClientMailboxScreenState();
}

class _ClientMailboxScreenState extends State<ClientMailboxScreen> {
  final ClientMailboxRepository _mailboxRepository = ClientMailboxRepository();
  final ClientOutreachRepository _outreachRepository =
      ClientOutreachRepository();
  late Future<_MailboxViewData> _future = _load();
  String? _oauthInflightProvider;
  bool _verifyingDomain = false;
  String? _resultMessage;

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
            'browser. Approve the request — Orchestrate will finish the connection.';
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
            : 'Verification did not pass yet. Make sure each record is published and try again — DNS can take time to propagate.';
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
            eyebrow: 'Mailbox',
            label: 'Loading sending identity status',
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Mailbox is temporarily unavailable',
            onRetry: _refresh,
          );
        }
        final data = snapshot.data!;
        return ClientPage(
          eyebrow: 'Sending identity',
          title: data.headline,
          subtitle: data.subtitle,
          banner: ClientStatusBanner(
            tone: data.bannerTone,
            title: data.bannerTitle,
            message: data.bannerMessage,
          ),
          actions: _buildActions(data),
          children: [
            if (_resultMessage != null) ...[
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
            ClientPanel(
              title: 'Identity readiness',
              subtitle:
                  'Orchestrate sends from this mailbox on your behalf. Each item below must be completed before outreach can run.',
              children: [
                for (final step in data.identitySteps)
                  ClientInfoRow(
                    title: step.label,
                    primary: step.description,
                    trailing: ClientBadge(
                      label: step.complete ? 'Ready' : 'Needs you',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _SendingIdentityPanel(
              identity: data.sendingIdentity,
              verifying: _verifyingDomain,
              onVerify: _checkSendingIdentity,
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
                              'No outbound dispatches yet. Once identity is ready, Orchestrate will begin sending automatically.')
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
    widgets.add(
      OutlinedButton.icon(
        onPressed: _refresh,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Refresh status'),
      ),
    );
    return widgets;
  }

  Future<_MailboxViewData> _load() async {
    final dispatches = await _outreachRepository.fetchEmailDispatches();
    final replies = await _outreachRepository.fetchReplies();
    final notices = await _outreachRepository.fetchNotifications();
    final readiness = await _mailboxRepository.fetchMailbox();
    final sendingDomain = await _mailboxRepository.fetchSendingDomain();

    final mailbox = asMap(readiness['mailbox']);
    final blockers = asList(readiness['blockers']).map(asMap).toList();
    final ready = readiness['ready'] == true;

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

    final identitySteps = <_IdentityStep>[
      _IdentityStep(
        label: 'Mailbox connected',
        complete: mailbox.isNotEmpty,
        description: mailbox.isNotEmpty
            ? 'Connected: ${readText(mailbox, 'address', fallback: readText(mailbox, 'fromEmail'))}.'
            : 'No mailbox is connected yet. Orchestrate cannot send without one.',
      ),
      _IdentityStep(
        label: 'Connection authorized',
        complete: readText(mailbox, 'connected').toLowerCase() == 'true',
        description: readText(mailbox, 'connected').toLowerCase() == 'true'
            ? 'The mailbox is connected and authorized for sending.'
            : 'The mailbox lost authorization. Reconnect to resume sending.',
      ),
      _IdentityStep(
        label: 'Sending identity verified',
        complete: readText(mailbox, 'verified').toLowerCase() == 'true',
        description: readText(mailbox, 'verified').toLowerCase() == 'true'
            ? 'Your sending identity has been verified for outbound delivery.'
            : 'Verify the sending identity so Orchestrate can deliver on your behalf.',
      ),
    ];

    final primaryActions = _primaryActionsFor(
      blockers: blockers,
      mailbox: mailbox,
      ready: ready,
    );

    final hero = _heroFor(
      ready: ready,
      hasMailbox: mailbox.isNotEmpty,
      blockers: blockers,
    );

    final sendingIdentity = _readSendingDomain(sendingDomain);

    return _MailboxViewData(
      dispatchCount: dispatches.length,
      replyCount: replies.length,
      noticeCount: notices.length,
      headline: hero.headline,
      subtitle: hero.subtitle,
      bannerTitle: hero.bannerTitle,
      bannerMessage: hero.bannerMessage,
      bannerTone: hero.bannerTone,
      dispatchRows: dispatchRows,
      identitySteps: identitySteps,
      primaryActions: primaryActions,
      sendingIdentity: sendingIdentity,
    );
  }

  _SendingIdentity _readSendingDomain(Map<String, dynamic> map) {
    if (map.isEmpty) {
      return const _SendingIdentity(
        present: false,
        domain: '',
        status: 'no_domain',
        ready: false,
        verifiedAt: null,
        lastCheckedAt: null,
        records: <_DnsRecord>[],
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
      records: records,
    );
  }

  /// Determines the OAuth connect / reconnect actions to surface as the
  /// page CTAs. Mailbox-missing offers Gmail and Microsoft 365 side by
  /// side; an existing mailbox's reconnect button uses its own provider
  /// so the user re-grants the same scopes against the same account.
  List<_MailboxPrimaryAction> _primaryActionsFor({
    required List<Map<String, dynamic>> blockers,
    required Map<String, dynamic> mailbox,
    required bool ready,
  }) {
    if (ready) return const <_MailboxPrimaryAction>[];

    final byCode = <String, Map<String, dynamic>>{
      for (final blocker in blockers) readText(blocker, 'code'): blocker,
    };
    final hasMailbox = mailbox.isNotEmpty;
    final providerRaw = readText(mailbox, 'provider').toUpperCase();
    final mailboxId =
        readText(mailbox, 'id').isEmpty ? null : readText(mailbox, 'id');

    // Mailbox provider configuration is Orchestrate-side. No client CTA.
    if (byCode.containsKey('MAILBOX_PROVIDER_ERROR')) {
      return const <_MailboxPrimaryAction>[];
    }

    if (byCode.containsKey('MAILBOX_MISSING') || !hasMailbox) {
      return const <_MailboxPrimaryAction>[
        _MailboxPrimaryAction(
          code: 'connect_google',
          label: 'Connect Gmail',
          icon: Icons.alternate_email,
          oauthProvider: 'google',
        ),
        _MailboxPrimaryAction(
          code: 'connect_microsoft',
          label: 'Connect Microsoft 365',
          icon: Icons.business_center_outlined,
          oauthProvider: 'microsoft',
        ),
      ];
    }

    if (byCode.containsKey('MAILBOX_DISCONNECTED') ||
        byCode.containsKey('MAILBOX_UNVERIFIED')) {
      final provider = providerRaw == 'GOOGLE' || providerRaw == 'MICROSOFT'
          ? providerRaw.toLowerCase()
          : null;
      if (provider != null) {
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
      // Unknown provider — show both as a fallback so the client can
      // re-grant via whichever they originally used.
      return const <_MailboxPrimaryAction>[
        _MailboxPrimaryAction(
          code: 'connect_google',
          label: 'Connect Gmail',
          icon: Icons.alternate_email,
          oauthProvider: 'google',
        ),
        _MailboxPrimaryAction(
          code: 'connect_microsoft',
          label: 'Connect Microsoft 365',
          icon: Icons.business_center_outlined,
          oauthProvider: 'microsoft',
        ),
      ];
    }

    return const <_MailboxPrimaryAction>[];
  }

  _MailboxHero _heroFor({
    required bool ready,
    required bool hasMailbox,
    required List<Map<String, dynamic>> blockers,
  }) {
    if (ready) {
      return const _MailboxHero(
        headline: 'Sending identity is ready',
        subtitle:
            'Orchestrate is using your verified mailbox to send outreach on your behalf.',
        bannerTitle: 'Ready to send',
        bannerMessage:
            'You do not need to do anything here unless your mailbox provider asks you to re-authorize.',
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
            'Sending will resume automatically once provider configuration is restored. Contact support if this persists.',
        bannerTone: ClientBannerTone.warning,
      );
    }
    if (!hasMailbox) {
      return const _MailboxHero(
        headline: 'Connect your sending mailbox',
        subtitle:
            'Orchestrate sends outreach on your behalf from the mailbox you connect. Pick Gmail or Microsoft 365 — Orchestrate handles the OAuth handshake and stores no credentials in your browser.',
        bannerTitle: 'A mailbox is required to start',
        bannerMessage:
            'Use the buttons above to grant Orchestrate access to Gmail or Microsoft 365. You will be redirected to your provider to approve.',
        bannerTone: ClientBannerTone.warning,
      );
    }
    return const _MailboxHero(
      headline: 'Finish verifying your sending identity',
      subtitle:
          'A mailbox is connected but one identity step is still pending. Complete it so Orchestrate can begin sending.',
      bannerTitle: 'One identity step remaining',
      bannerMessage:
          'Resolve the pending identity step. Orchestrate will start outreach automatically as soon as it clears.',
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
  });

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
}

class _SendingIdentity {
  const _SendingIdentity({
    required this.present,
    required this.domain,
    required this.status,
    required this.ready,
    required this.verifiedAt,
    required this.lastCheckedAt,
    required this.records,
  });

  final bool present;
  final String domain;
  final String status;
  final bool ready;
  final String? verifiedAt;
  final String? lastCheckedAt;
  final List<_DnsRecord> records;
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
  });

  final String label;
  final bool complete;
  final String description;
}

class _SendingIdentityPanel extends StatelessWidget {
  const _SendingIdentityPanel({
    required this.identity,
    required this.verifying,
    required this.onVerify,
  });

  final _SendingIdentity identity;
  final bool verifying;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!identity.present) {
      return ClientPanel(
        title: 'Sending domain (SPF / DKIM / DMARC)',
        subtitle:
            'A sending domain is the public identity Orchestrate uses to send for you. We will set this up automatically once a mailbox is connected.',
        children: const [
          ClientEmptyState(
              message:
                  'No sending domain is attached yet. Connect a mailbox to start sending-identity setup.'),
        ],
      );
    }
    final subtitleParts = <String>[
      'Domain: ${identity.domain}',
      identity.ready ? 'Verified' : 'Needs verification',
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
            trailing: ClientBadge(label: record.matched ? 'Found' : 'Missing'),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 0, bottom: 4),
            child: Text(
              record.explanation,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
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
          ],
        ),
      ],
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
