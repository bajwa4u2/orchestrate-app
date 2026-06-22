import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

/// Dedicated OAuth return result surface. Parses the query params the
/// backend redirect carries (`status` = success | error, `provider`,
/// `reason`, `email`, `mailboxId`) and renders an explained outcome
/// with operation-scoped mailbox handling reinforced. Continues
/// progression with explicit next-action CTAs rather than dumping the
/// user on a generic page.
///
/// Backed by `MailboxOAuthService.completeCallback` — the backend always
/// 302-redirects with safe (no-secret) query params so the failure modes
/// covered here are: provider denial, missing code/state, upstream
/// provider error, and successful connect.
class OAuthReturnScreen extends StatelessWidget {
  const OAuthReturnScreen({
    super.key,
    required this.status,
    this.provider,
    this.reason,
    this.email,
    this.mailboxId,
  });

  /// `success` | `error` | empty when the user navigated here directly.
  final String status;
  final String? provider;
  final String? reason;
  final String? email;
  final String? mailboxId;

  bool get _isGoogleContacts =>
      (provider ?? '').toLowerCase() == 'google_contacts';

  String get _providerLabel {
    switch ((provider ?? '').toLowerCase()) {
      case 'google':
        return 'Google Workspace';
      case 'google_contacts':
        return 'Google Contacts';
      case 'microsoft':
        return 'Microsoft 365';
      default:
        return 'the provider';
    }
  }

  String get _readableReason {
    final raw = (reason ?? '').trim();
    if (raw.isEmpty) return '';
    // Common provider error codes the backend echoes through.
    switch (raw) {
      case 'access_denied':
      case 'user_denied':
        return 'The consent screen was declined. You can retry from Infrastructure when ready.';
      case 'missing_code_or_state':
        return 'The provider redirect arrived without the expected handshake parameters. This usually happens when a tab is closed mid-consent. Retry from Infrastructure.';
      case 'oauth_callback_failed':
        return 'The provider accepted consent but the credential exchange did not complete. Orchestrate has not stored anything; retry from Infrastructure.';
      default:
        return raw;
    }
  }

  bool get _isSuccess => status.toLowerCase() == 'success';
  bool get _isError => status.toLowerCase() == 'error';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClientPage(
      eyebrow: _isGoogleContacts ? 'Relationship sources' : 'Mailbox transport',
      title: _isSuccess
          ? 'Connected $_providerLabel'
          : _isError
              ? '$_providerLabel did not connect'
              : 'OAuth result',
      subtitle: _isGoogleContacts
          ? (_isSuccess
              ? 'Google Contacts is now authorized. Sync your contacts from the Relationships page.'
              : 'Authorization did not complete. No credentials were stored; you can retry from Relationships.')
          : (_isSuccess
              ? 'Credentials are sealed in the vault. The transport is now part of the readiness chain. See Infrastructure for the next step.'
              : _isError
                  ? 'No credentials were stored. The mailbox row is still in its previous state; retry the connect flow whenever you are ready.'
                  : 'This page renders the result of a mailbox-OAuth return redirect.'),
      banner: ClientStatusBanner(
        tone: _isSuccess
            ? ClientBannerTone.success
            : ClientBannerTone.warning,
        title: _isSuccess
            ? 'Authorization complete'
            : _isError
                ? 'Authorization did not complete'
                : 'No OAuth result on this URL',
        message: _isSuccess
            ? (_isGoogleContacts
                ? 'Google Contacts is authorized. Orchestrate can now read your contact list for relationship intelligence. Token never touched this browser.'
                : 'Orchestrate runs OAuth backend-side; tokens never touched this browser. The sending transport is now connected.')
            : _isError
                ? (_readableReason.isEmpty
                    ? 'No detailed reason was returned.'
                    : _readableReason)
                : (_isGoogleContacts
                    ? 'Navigate to Relationships to connect Google Contacts.'
                    : 'Navigate to Infrastructure to connect or reconnect a mailbox transport.'),
      ),
      actions: [
        if (_isGoogleContacts) ...[
          FilledButton.icon(
            onPressed: () => context.go('/client/relationships'),
            icon: const Icon(Icons.people_outline, size: 18),
            label: Text(_isSuccess ? 'Go to Relationships' : 'Open Relationships'),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: () => context.go('/client/infrastructure'),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(_isSuccess
                ? 'Continue to Infrastructure'
                : 'Open Infrastructure'),
          ),
          if (!_isSuccess)
            OutlinedButton.icon(
              onPressed: () => context.go('/client/operations'),
              icon: const Icon(Icons.timeline_outlined, size: 18),
              label: const Text('View operational state'),
            ),
        ],
      ],
      children: [
        if (_isSuccess && (email ?? '').isNotEmpty)
          ClientPanel(
            title: 'Connected mailbox',
            children: [
              ClientInfoRow(
                title: 'Address',
                primary: email ?? '',
              ),
              ClientInfoRow(
                title: 'Provider',
                primary: _providerLabel,
              ),
              if ((mailboxId ?? '').isNotEmpty)
                ClientInfoRow(
                  title: 'Mailbox ID',
                  primary: mailboxId ?? '',
                  secondary:
                      'Use this when working with operator support; it does not expose credentials.',
                ),
            ],
          ),
        const SizedBox(height: 18),
        ClientPanel(
          title: 'What Orchestrate can and cannot access',
          subtitle:
              'OAuth scopes are minimum-required by design. This is the operational boundary regardless of which provider you connected.',
          children: [
            ClientInfoRow(
              title: 'Outbound dispatch',
              primary: _isSuccess
                  ? 'Authorized. Orchestrate can dispatch messages on behalf of your business via $_providerLabel.'
                  : 'Not authorized. The consent flow did not complete.',
              trailing:
                  ClientBadge(label: _isSuccess ? 'Granted' : 'Not granted'),
            ),
            const ClientInfoRow(
              title: 'Inbox read access',
              primary:
                  'Send-only scope on OAuth transports. Orchestrate does NOT request broad mailbox read access. Reply continuity on OAuth providers is not part of this deployment today.',
              trailing: ClientBadge(label: 'Not requested'),
            ),
            const ClientInfoRow(
              title: 'Inbox content stored',
              primary:
                  'None. Orchestrate does not behave as a general inbox reader on any transport. For SMTP+IMAP transports the inbound poll inspects headers first and only fetches bodies for messages matched to an Orchestrate operation.',
              trailing: ClientBadge(label: 'Op-scoped'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ClientPanel(
          title: 'Next step',
          children: [
            ClientInfoRow(
              title: _isSuccess ? 'Verify sending identity' : 'Retry connect',
              primary: _isSuccess
                  ? 'The transport is connected. The readiness chain still needs the sending domain attached and SPF / DKIM / DMARC verified before dispatch eligibility flips.'
                  : 'No state was changed. Reopen the consent flow from Infrastructure when you are ready.',
              trailing: FilledButton.tonal(
                onPressed: () => context.go(_isSuccess
                    ? '/client/infrastructure?focus=domain'
                    : '/client/infrastructure'),
                child: Text(_isSuccess ? 'Open domain panel' : 'Open Infrastructure'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Tokens for $_providerLabel are sealed by the encrypted vault adapter and never appear in API responses, browser state, or logs. Audit log entries record the connect event with metadata only, no credential contents.',
          style:
              theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
