import 'package:flutter/material.dart';

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
  bool _provisioning = false;
  String? _resultMessage;

  Future<void> _provisionDefaultMailbox() async {
    setState(() => _provisioning = true);
    try {
      final result = await _mailboxRepository.activateMailbox();
      final ready = result['ready'] == true;
      final blockers = asList(result['blockers']).map(asMap).toList();
      final firstBlocker = blockers.isEmpty ? const <String, dynamic>{} : blockers.first;
      setState(() {
        _resultMessage = ready
            ? 'Sending identity is ready.'
            : readText(firstBlocker, 'message',
                fallback:
                    'We could not provision a mailbox automatically. Contact support so we can help.');
        _future = _load();
      });
    } catch (error) {
      setState(() {
        _resultMessage = ClientErrorView.classifyError(error);
        _future = _load();
      });
    } finally {
      if (mounted) setState(() => _provisioning = false);
    }
  }

  void _refresh() {
    setState(() {
      _resultMessage = null;
      _future = _load();
    });
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
    final primary = data.primaryAction;
    if (primary != null) {
      final isProvision = primary.code == 'provision_mailbox';
      final isInflight = isProvision && _provisioning;
      widgets.add(
        FilledButton.icon(
          onPressed: isInflight
              ? null
              : isProvision
                  ? _provisionDefaultMailbox
                  : null,
          icon: isInflight
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(primary.icon, size: 18),
          label: Text(isInflight ? 'Provisioning' : primary.label),
        ),
      );
      if (!isProvision) {
        // Non-provision flows (reconnect/verify) need a backend OAuth or
        // domain verification path that this build does not yet expose.
        // Surface the contact path so the client is never stuck.
        widgets.add(
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.support_agent_outlined, size: 18),
            label: const Text('Contact support to complete'),
          ),
        );
      }
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

    final primaryAction = _primaryActionFor(
      blockers: blockers,
      hasMailbox: mailbox.isNotEmpty,
      ready: ready,
    );

    final hero = _heroFor(
      ready: ready,
      hasMailbox: mailbox.isNotEmpty,
      blockers: blockers,
    );

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
      primaryAction: primaryAction,
    );
  }

  _MailboxPrimaryAction? _primaryActionFor({
    required List<Map<String, dynamic>> blockers,
    required bool hasMailbox,
    required bool ready,
  }) {
    if (ready) return null;

    final byCode = <String, Map<String, dynamic>>{
      for (final blocker in blockers)
        readText(blocker, 'code'): blocker,
    };

    if (byCode.containsKey('MAILBOX_MISSING') || !hasMailbox) {
      return const _MailboxPrimaryAction(
        code: 'provision_mailbox',
        label: 'Let Orchestrate set up a mailbox',
        icon: Icons.outgoing_mail,
      );
    }
    if (byCode.containsKey('MAILBOX_DISCONNECTED')) {
      return const _MailboxPrimaryAction(
        code: 'reconnect_mailbox',
        label: 'Reconnect mailbox',
        icon: Icons.link,
      );
    }
    if (byCode.containsKey('MAILBOX_UNVERIFIED')) {
      return const _MailboxPrimaryAction(
        code: 'verify_mailbox',
        label: 'Verify sending identity',
        icon: Icons.verified_user_outlined,
      );
    }
    if (byCode.containsKey('AUTHORIZATION_MISSING')) {
      return const _MailboxPrimaryAction(
        code: 'complete_representation_authorization',
        label: 'Authorize Orchestrate',
        icon: Icons.assignment_turned_in_outlined,
      );
    }
    // MAILBOX_PROVIDER_ERROR or anything else is Orchestrate-side; no client
    // CTA. Banner already explains that we are recovering.
    return null;
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
        headline: 'Connect a sending mailbox',
        subtitle:
            'Orchestrate needs one mailbox to send outreach from. We can provision a managed mailbox or you can connect your own.',
        bannerTitle: 'A mailbox is required to start',
        bannerMessage:
            'Use the action above to let Orchestrate provision a sending mailbox for your account.',
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
    required this.primaryAction,
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
  final _MailboxPrimaryAction? primaryAction;
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

class _MailboxPrimaryAction {
  const _MailboxPrimaryAction({
    required this.code,
    required this.label,
    required this.icon,
  });

  final String code;
  final String label;
  final IconData icon;
}
