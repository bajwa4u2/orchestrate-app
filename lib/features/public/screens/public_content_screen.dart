import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';

class PublicContentScreen extends StatelessWidget {
  const PublicContentScreen({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.sections,
    this.sideNote,
    this.sideActions = const [],
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<ContentSection> sections;
  final String? sideNote;
  final List<ContentAction> sideActions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.publicSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppTheme.publicLine),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 940;
                    final lead = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.publicAccentSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            eyebrow,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppTheme.publicAccent,
                                ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                  // Responsive cap: desktop is held at 44,
                                  // narrow widths scale down (not up).
                                  fontSize: stacked ? 34 : 44,
                                  height: 1.1,
                                  letterSpacing: 0,
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Text(
                            subtitle,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppTheme.publicMuted,
                                    ),
                          ),
                        ),
                      ],
                    );

                    final aside = _SidePanel(
                      note: sideNote,
                      actions: sideActions,
                    );

                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          lead,
                          if (sideNote != null || sideActions.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            aside,
                          ],
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: lead),
                        if (sideNote != null || sideActions.isNotEmpty) ...[
                          const SizedBox(width: 24),
                          Expanded(flex: 4, child: aside),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              for (final section in sections) ...[
                _SectionCard(section: section),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ContentSection {
  const ContentSection({
    required this.title,
    required this.body,
    this.points = const [],
    this.highlight,
  });

  final String title;
  final String body;
  final List<String> points;
  final String? highlight;
}

class ContentAction {
  const ContentAction({
    required this.label,
    required this.path,
    this.filled = false,
  });

  final String label;
  final String path;
  final bool filled;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final ContentSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            section.body,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (section.highlight != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.publicAccentSoft,
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: Text(
                section.highlight!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.publicText,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
          if (section.points.isNotEmpty) ...[
            const SizedBox(height: 18),
            for (final point in section.points) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: AppTheme.publicAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      point,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.note, required this.actions});

  final String? note;
  final List<ContentAction> actions;

  @override
  Widget build(BuildContext context) {
    final primaryAction = actions.isNotEmpty ? actions.first : null;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note != null) ...[
            Text(
              note!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
            if (primaryAction != null) const SizedBox(height: 18),
          ],
          if (primaryAction != null)
            FilledButton(
              onPressed: () => context.go(primaryAction.path),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppTheme.publicText,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
              ),
              child: Text(primaryAction.label),
            ),
        ],
      ),
    );
  }
}

// Note: buildHowItWorksScreen / buildPricingScreen / buildContactScreen
// were removed. The router renders inline PublicContentScreens for those
// routes with the current category-coherent copy. Leaving the old
// builders here let outreach-tinted fallback copy drift back in if any
// future edit re-wired them. Legal builders below remain in use.

PublicContentScreen buildTermsScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Terms of use',
      subtitle:
          'These terms govern access to the public site, operator workspace, client access areas, and related services provided through Orchestrate.',
      sections: [
        ContentSection(
          title: 'Use of the service',
          body:
              'Use of Orchestrate is conditioned on lawful use, truthful account information, payment of agreed fees, and compliance with the service boundaries presented publicly or contractually.',
        ),
        ContentSection(
          title: 'Account posture',
          body:
              'Operator access may be provisioned directly and may be limited, suspended, or revoked where misuse, non-payment, risk, or policy breaches create operational or legal concern. Client access may be limited to review functions appropriate to the service relationship.',
        ),
        ContentSection(
          title: 'Service boundaries',
          body:
              'Orchestrate provides managed execution infrastructure for outbound business communication, follow-up continuity, meeting handoff, billing administration, reminders, records, and related service functions. It does not guarantee recipient response, booked meetings, customer payment, or uninterrupted third-party system behavior.',
          highlight:
              'External systems, recipient behavior, data quality, and client responsiveness remain variables outside direct control.',
        ),
        ContentSection(
          title: 'Suspension and termination',
          body:
              'Service may be suspended or ended where use creates abuse risk, legal exposure, security issues, payment failure, misuse of sender identity, harassment, fraud, or other misuse inconsistent with the purpose of the system.',
        ),
      ],
    );

PublicContentScreen buildPrivacyScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Privacy policy',
      subtitle:
          'Orchestrate handles business contact information, communication records, billing records, service metadata, and a strictly-scoped subset of mailbox content in order to operate the service responsibly.',
      sideActions: [
        ContentAction(
            label: 'Mailbox access policy', path: '/legal/mailbox-access'),
        ContentAction(label: 'AI usage disclosure', path: '/legal/ai-usage'),
        ContentAction(
            label: 'Credential handling', path: '/legal/credentials'),
      ],
      sections: [
        ContentSection(
          title: 'Information handled',
          body:
              'The system may handle business names, contact details, lead and customer records, communication history, payment status information, agreements, statements, and basic usage logs needed for account security and service continuity.',
        ),
        ContentSection(
          title: 'Mailbox content processed',
          body:
              'Orchestrate does not behave as a general inbox reader. Inbound mail is inspected at the header level only; message bodies are fetched and stored exclusively when the message matches a known Orchestrate-managed outbound operation (via In-Reply-To / References headers or the X-Orchestrate-Operation-Id fingerprint). Unrelated mailbox content is not stored, classified, surfaced in the UI, or fed to AI systems. See the dedicated Mailbox access policy for the full scope description.',
          highlight:
              'Headers are inspected first. Bodies are fetched only for messages that resolve to an Orchestrate operation.',
        ),
        ContentSection(
          title: 'Credentials handling',
          body:
              'Mailbox transport credentials (OAuth refresh tokens, SMTP / IMAP passwords, DKIM private keys) are sealed in a vault adapter (encrypted-DB or HashiCorp Vault) and never appear in API responses, logs, telemetry, or the browser. See the Credential handling disclosure for the storage model and rotation behavior.',
        ),
        ContentSection(
          title: 'AI processing scope',
          body:
              'AI-assisted systems operate against operation-scoped data only: Orchestrate-generated outbound content and operation-matched replies. Unrelated mailbox content never enters an AI pipeline. AI assists managed execution; it does not act autonomously as an impersonated human. See the AI usage disclosure for boundaries.',
        ),
        ContentSection(
          title: 'Purpose of collection and use',
          body:
              'Information is used to operate managed execution, preserve records, support billing workflows, maintain account access, provide client visibility, protect the service, and respond to support, contractual, or legal needs.',
        ),
        ContentSection(
          title: 'Sharing posture',
          body:
              'Information is not shared casually. It may be shared with infrastructure vendors (database, vault, deliverability transport providers the client themselves selects), payment providers, or legal authorities where necessary to operate the system, enforce agreements, process payments, or meet legal obligations.',
        ),
        ContentSection(
          title: 'Retention and control',
          body:
              'Records may be retained for operational continuity, legal compliance, financial accountability, dispute handling, and service history. Account deletion requests are honored per the Account deletion page; deletion may be limited where retention is reasonably required for the purposes listed above.',
        ),
      ],
    );

PublicContentScreen buildMailboxAccessPolicyScreen() =>
    const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Mailbox access policy',
      subtitle:
          'Orchestrate does not behave as a general inbox reader. This document defines the exact scope under which mailbox content is read, stored, classified, or fed to AI.',
      sections: [
        ContentSection(
          title: 'Operation-scoped processing',
          body:
              'Inbound mail is processed only when it can be attributed to a known Orchestrate-managed outbound operation. Attribution is established through one of: (1) In-Reply-To header matching an OutreachMessage external Message-ID; (2) References header containing such an ID; (3) the X-Orchestrate-Operation-Id header Orchestrate stamps on its own outbound. Messages without any of these signals are not attributed and not processed.',
        ),
        ContentSection(
          title: 'Header-first / body-on-match-only',
          body:
              'For IMAP transports, the platform fetches envelope plus a narrow set of headers (Message-ID, In-Reply-To, References, From, To, Subject, X-Orchestrate-Operation-Id, X-Orchestrate-Thread-Id) before any matching decision. Message bodies are only requested after a successful attribution. Unattributed messages never have their body read by Orchestrate.',
          highlight:
              'No body is ever fetched, stored, or processed for a message that fails attribution.',
        ),
        ContentSection(
          title: 'No historical backfill on connect',
          body:
              'When an IMAP transport is connected, the polling cursor is initialized to the current highest UID at connection time. The first sweep after connect inspects only messages that arrive AFTER the connect moment. Historical inbox content from before the connection is never inspected unless the operator explicitly requests a bounded backfill (which is not exposed as a one-click default).',
        ),
        ContentSection(
          title: 'OAuth transports (Google / Microsoft)',
          body:
              'Where Orchestrate connects to Google Workspace or Microsoft 365 via OAuth, the consent screen requests minimum required scopes (send-only on this deployment). When inbound monitoring is implemented for these providers in the future, it will be scope-restricted to thread / metadata reads tied to operations, never broad mailbox read access.',
        ),
        ContentSection(
          title: 'Sent folder scope',
          body:
              'Orchestrate does not mirror or ingest the Sent folder. Only outbound messages that Orchestrate itself generated are persisted in the platform.',
        ),
        ContentSection(
          title: 'What this means for shared mailboxes',
          body:
              'A dedicated sending mailbox is strongly recommended. If you connect a personal or shared mailbox, the operation-scoped rules above still apply. Unrelated personal mail is not stored, but a dedicated mailbox keeps the operational scope unambiguous.',
        ),
      ],
    );

PublicContentScreen buildAiUsagePolicyScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'AI usage disclosure',
      subtitle:
          'Orchestrate uses AI-assisted systems to support managed execution. This document defines what AI does, what AI does not do, and how the boundary is enforced.',
      sections: [
        ContentSection(
          title: 'What AI assists',
          body:
              'AI systems support: signal-qualification scoring against the client business identity, outbound message generation tied to a known recipient and operation, reply intent classification on operation-matched replies, and operator-side analysis surfaces. Every AI invocation is tied to an audited decision record.',
        ),
        ContentSection(
          title: 'What AI does not do',
          body:
              'AI does not autonomously create accounts, impersonate the client in human-discretionary domains, ingest unrelated mailbox content, read the body of a mailbox message that has not been operation-attributed, or send to recipients without a governed dispatch decision.',
          highlight:
              'AI processing is bounded by the same operation-scoped attribution that governs the rest of the platform.',
        ),
        ContentSection(
          title: 'Transparency and traceability',
          body:
              'AI-generated or AI-assisted outbound content carries a stored traceability record (decision id, model identifier, input scope). Operators and clients can request the trail for any AI-assisted output that affected their workspace.',
        ),
        ContentSection(
          title: 'Human ownership of execution boundaries',
          body:
              'The client owns the operational boundaries: representation authorization, business identity, sending identity, and opt-out posture. AI operates within those boundaries; it does not override them. Where a recipient response indicates opt-out, suppression, or intent change, the governance layer halts further AI-assisted dispatch against that recipient.',
        ),
        ContentSection(
          title: 'No human impersonation claims',
          body:
              'Orchestrate does not claim that AI-assisted messages are written by a human individual. Outbound content is sent on behalf of the client business under their authorized representation, with attribution that complies with applicable commercial-communication rules.',
        ),
      ],
    );

PublicContentScreen buildCredentialHandlingScreen() =>
    const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Credential handling disclosure',
      subtitle:
          'Mailbox transport credentials never appear in API responses, logs, telemetry, the browser, or unencrypted database storage. This document defines the storage model and the access path.',
      sections: [
        ContentSection(
          title: 'Storage model',
          body:
              'Credentials are sealed by a vault adapter selected at deployment time. Supported adapters: an encrypted-DB adapter (AES-256-GCM, key held outside the database row, suitable for managed-Postgres deployments) and a HashiCorp Vault adapter (for deployments that maintain their own vault infrastructure). An in-memory adapter exists for tests and local development; the production runtime refuses to boot if the in-memory adapter is selected with NODE_ENV=production.',
        ),
        ContentSection(
          title: 'Access path',
          body:
              'Service code never imports a vault adapter directly. Every read, write, rotation, or revocation passes through a single credential-vault service whose audit trail captures the action, actor, organization, mailbox, and outcome, but never the credential contents.',
        ),
        ContentSection(
          title: 'What is sealed',
          body:
              'OAuth refresh tokens (Google Workspace, Microsoft 365), SMTP passwords, IMAP passwords, DKIM private keys generated by Orchestrate, and IMAP poll cursors (`lastSeenUid`) are all sealed by the vault adapter. The application database holds only opaque references and non-sensitive metadata (granted scopes, provider account email, last refresh timestamp).',
        ),
        ContentSection(
          title: 'Rotation and revocation',
          body:
              'Credentials can be rotated in place (used when re-authorizing a mailbox or attaching IMAP onto an existing SMTP transport). Revocation removes the vault entry; the cross-vault audit trail preserves the action record. Where the upstream provider supports remote revocation, the platform issues the revoke call alongside the local delete.',
        ),
        ContentSection(
          title: 'Out of scope',
          body:
              'Credentials are not propagated to third-party deliverability vendors, analytics platforms, or logging systems. They are not present in error messages or stack traces. Audit log entries deliberately capture metadata only (host, port, encryption mode, folder, outcome), never password content, refresh-token strings, or message bodies.',
          highlight:
              'Audit-log-is-metadata-only is a structural property of the emission code, not a runtime check.',
        ),
      ],
    );

PublicContentScreen buildReplyMonitoringDisclosureScreen() =>
    const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Reply monitoring disclosure',
      subtitle:
          'When inbound reply monitoring is wired (via IMAP attached to a custom SMTP transport, or via a future scope-restricted OAuth inbound path), the platform behaves under the rules described below.',
      sections: [
        ContentSection(
          title: 'When monitoring runs',
          body:
              'Monitoring runs only against transports where the client has explicitly connected an inbound credential. SMTP outbound without IMAP inbound produces an outbound-only transport. Replies arrive in the recipient mailbox unobserved by the platform until inbound credentials are attached.',
        ),
        ContentSection(
          title: 'How matching works',
          body:
              'Each inbound message is matched against the client\'s outbound corpus via In-Reply-To, References, or the X-Orchestrate-Operation-Id header. The first match path is the operation-id header, which Orchestrate stamps on every supported outbound and which survives relays that strip standard threading headers.',
        ),
        ContentSection(
          title: 'What happens to matched mail',
          body:
              'A matched message is persisted as a Reply row scoped to the matching lead, campaign, and outbound message. Pending follow-up jobs against the same lead are cancelled. The reply surfaces in the client\'s Replies workspace and may be classified by an AI reply-intent worker.',
        ),
        ContentSection(
          title: 'What happens to unmatched mail',
          body:
              'Unmatched messages remain in the upstream mailbox untouched. The platform does not download their body, does not store them, does not classify them, and does not feed them to AI. A header-level "unmatched" count may be recorded as non-content telemetry.',
        ),
        ContentSection(
          title: 'Deduplication',
          body:
              'Matching is keyed by the upstream message-id, and the IMAP UID cursor (`lastSeenUid`) advances monotonically. The same inbound message cannot be ingested twice across restarts or re-attaches.',
        ),
        ContentSection(
          title: 'Follow-up suppression',
          body:
              'A matched reply against a lead automatically cancels queued FOLLOWUP_SEND jobs and any QUEUED / SCHEDULED OutreachMessage rows targeting that lead, so the platform does not continue dispatching after a recipient has responded.',
        ),
      ],
    );

PublicContentScreen buildSuppressionPolicyScreen() =>
    const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Suppression and opt-out policy',
      subtitle:
          'Recipients have the right to stop receiving outbound communication. The platform enforces this in two complementary ways: an explicit suppression list and reply-triggered automatic suppression.',
      sections: [
        ContentSection(
          title: 'Suppression list',
          body:
              'The platform maintains a suppression list scoped per organization and per client. Entries may be created from inbound opt-out signals, manual operator action, or imported lists. The list supports per-email and per-domain entries. Dispatch checks suppression before every FIRST_SEND and FOLLOWUP_SEND; a matching entry blocks the send and marks the lead as SUPPRESSED.',
        ),
        ContentSection(
          title: 'Reply-triggered suppression',
          body:
              'When an inbound reply is classified as an opt-out intent, the recipient is automatically added to the suppression list with the source recorded. No further outbound is dispatched to that recipient by the platform unless an operator explicitly removes the entry.',
        ),
        ContentSection(
          title: 'Suppression categories',
          body:
              'Entries carry one of four canonical categories: UNSUBSCRIBE (explicit recipient opt-out), HARD_BOUNCE (recipient address unreachable), COMPLAINT (recipient reported as spam), MANUAL_BLOCK (operator-applied block). Each category carries the same dispatch-blocking effect.',
        ),
        ContentSection(
          title: 'No bypass',
          body:
              'There is no UI affordance, API endpoint, or operator tool that lets a dispatch path skip suppression check. Suppression check is in the FIRST_SEND code path, the FOLLOWUP_SEND code path, and the direct-email send path.',
          highlight:
              'No code path dispatches to a suppressed recipient.',
        ),
        ContentSection(
          title: 'Visibility',
          body:
              'Suppressed recipients appear in the operator-side suppression view with the source, category, and timestamp. Clients see suppression as a transparent operational state on the affected leads.',
        ),
      ],
    );

PublicContentScreen buildProviderResponsibilityScreen() =>
    const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Provider responsibility boundaries',
      subtitle:
          'Outbound and inbound mail transport is provider-agnostic infrastructure beneath the client domain identity. This document defines what Orchestrate is responsible for and what each provider remains responsible for.',
      sections: [
        ContentSection(
          title: 'Client domain identity is primary',
          body:
              'The conceptual center of operational identity is the client\'s sending domain (SPF, DKIM, DMARC). Transport providers (Google Workspace, Microsoft 365, custom SMTP / IMAP) are interchangeable infrastructure beneath that identity. Changing providers does not change the operational identity.',
        ),
        ContentSection(
          title: 'Google Workspace / Microsoft 365 (OAuth)',
          body:
              'OAuth transports use the provider\'s consent screen to grant Orchestrate scope-restricted access (send-only on this deployment). The provider remains the underlying mail-relay infrastructure and applies its own deliverability, throttling, and policy enforcement. Where the provider expires or revokes the OAuth grant, the platform detects this and surfaces a reconnect prompt; it does not retry against an invalid grant.',
        ),
        ContentSection(
          title: 'Custom SMTP transport',
          body:
              'For custom SMTP, the client supplies the host, port, encryption mode, credentials, and from-address. Orchestrate validates against the upstream host before persisting, vaults credentials, generates a per-transport DKIM keypair, and signs every outbound message inside its process before handing it to the relay. The underlying SMTP server\'s deliverability behavior remains the client\'s contractual relationship with that provider.',
        ),
        ContentSection(
          title: 'Custom IMAP transport',
          body:
              'For custom IMAP, the client supplies the inbound credentials and a folder. Orchestrate polls the folder header-first, fetches bodies only for operation-matched messages, and persists the cursor in the vault. IMAP servers that do not return STATUS uidNext are supported but with a one-time degraded header-scan window on first connect.',
        ),
        ContentSection(
          title: 'DNS verification (SPF / DKIM / DMARC)',
          body:
              'DNS records are published by the client at their DNS provider. Orchestrate verifies them via live DNS lookups, surfaces propagation history, re-checks PENDING domains automatically, and gates dispatch eligibility on the verification state. The DNS host is the client\'s responsibility; the verification + dispatch-gating decisions are the platform\'s.',
        ),
        ContentSection(
          title: 'Trust classification',
          body:
              'The trust classification (pending / limited / warmup-allowed / full-trust) drives dispatch eligibility at the platform layer. It is informed by SPF / DKIM / DMARC verification results, mailbox health, and recent transport health events. Recipient-side inbox placement remains outside any platform\'s direct control.',
        ),
      ],
    );

PublicContentScreen buildAbusePolicyScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Abuse and complaint policy',
      subtitle:
          'Orchestrate is managed execution infrastructure for legitimate business communication. Abusive use creates risk for the platform, other clients, the recipient ecosystem, and the underlying provider relationships. This policy defines how abuse is handled.',
      sections: [
        ContentSection(
          title: 'Prohibited behavior',
          body:
              'Unsolicited bulk sending without a documented business relationship or applicable consent, fraudulent or deceptive content, impersonation of a third party, harassment of recipients, deliberate evasion of provider deliverability controls, and use of the system to deliver malware or phishing payloads are all prohibited.',
        ),
        ContentSection(
          title: 'Complaint handling',
          body:
              'Complaint signals (from recipient-side abuse reports, hard bounces with abuse codes, provider feedback loops, or direct reports to support) are routed to an operator queue. Confirmed complaints result in suppression entries (per the Suppression policy), potential transport reconfiguration, and account-level review.',
        ),
        ContentSection(
          title: 'Account consequences',
          body:
              'Repeated complaint patterns, hard-bounce rates above acceptable thresholds, or evidence of policy violation may result in dispatch pause, transport disconnection, account suspension, or termination of service. Where suspension is applied, the operational reason is recorded in the account audit trail.',
        ),
        ContentSection(
          title: 'Reporting abuse',
          body:
              'Recipients or third parties may report suspected abuse to support@orchestrateops.com. Reports are reviewed against the audit trail (which account dispatched, against what targeting, under what authorization) and acted on per the consequences above.',
        ),
      ],
    );

PublicContentScreen buildWhyOrchestrateExistsScreen() =>
    const PublicContentScreen(
      eyebrow: 'Why Orchestrate exists',
      title:
          'Businesses are forced to operate the infrastructure they should be running on.',
      subtitle:
          'Outbound revenue tooling today exposes operational burden as a feature surface. The operator becomes a deliverability engineer, a prompting expert, a credential manager, a reply triage worker, and a CRM hygienist. All of this is work for a job that should be infrastructure.',
      sideActions: [
        ContentAction(
            label: 'See how Orchestrate operates',
            path: '/how-it-works',
            filled: true),
        ContentAction(
            label: 'Trust architecture', path: '/trust-architecture'),
      ],
      sections: [
        ContentSection(
          title: 'The operational burden every outbound team is carrying',
          body:
              'Pick any week of running outbound through current SaaS and the operator is doing infrastructure work: chasing SPF / DKIM / DMARC at the registrar, watching mailbox reputation, debugging why dispatch stalled, rewriting sequences that triggered spam filters, copying replies between an inbox and a CRM, manually suppressing recipients who replied "stop", reconnecting mailboxes after a token expired, and prompting AI to draft messages that match their voice. None of that is the work the business is trying to do.',
          points: [
            'Deliverability: SPF, DKIM, DMARC at the registrar, then chasing propagation',
            'Mailbox operations: connecting, reconnecting, token expiry, warmup, throttling',
            'Sequencing: rebuilding cadence logic in someone else\'s sequence-builder',
            'Reply triage: copying responses from inbox to CRM, classifying by hand',
            'Suppression: manually marking opt-outs, hard bounces, complaints',
            'AI prompting: re-engineering prompts every time the tone drifts',
            'Recovery: figuring out what to do when a transport fails mid-send',
            'Monitoring: dashboards that show numbers but not operational state',
          ],
        ),
        ContentSection(
          title: 'Why current tooling does not absorb this',
          body:
              'Campaign-SaaS platforms expose the infrastructure surface because that is their architecture. They are sequence builders dressed up as automation. AI tools surface the prompting burden because they are language models behind a chat UI, not governed execution. CRMs surface fragmentation because they were never designed to operate revenue infrastructure; they are systems of record. Each tool optimizes its own surface; the operational burden falls in the gaps between them, on the operator.',
          highlight:
              'When the operator is the integration layer between tools, the operational burden is not reduced. It is hidden under multiple subscription lines.',
        ),
        ContentSection(
          title: 'What Orchestrate is, structurally',
          body:
              'Managed commercial execution infrastructure. The client provides the identity layer: business identity, mailbox transport, sending domain, and representation authorization. Orchestrate provides the operational layer beneath that: signal-driven discovery, qualification, governed dispatch, follow-up continuity, trust verification, reply ingestion, suppression enforcement, recovery, and audit. The boundary is intentional: identity is yours, operation is ours.',
        ),
        ContentSection(
          title: 'What changes for the operator',
          body:
              'The operator stops doing infrastructure work. No registrar trips for propagation chasing. DNS verification runs continuously. No sequence-builder UX. Orchestrate generates and paces governed dispatch under the readiness engine. No manual reply triage. Operation-scoped IMAP ingestion attaches matched replies to the right outbound and cancels follow-ups against responded leads. No prompt engineering. AI assists inside the governance layer, with traceability and operator oversight. No silent transport failures. Health checks surface degraded state with the next concrete action, ownership badge attached.',
        ),
        ContentSection(
          title: 'What does not change',
          body:
              'The client remains the legal and commercial author. Representation authorization is recorded explicitly; sender attribution is enforced on every outbound. Suppression entries from opt-outs are honored before every dispatch. The audit trail records what the system did and on whose behalf. Orchestrate is operational infrastructure; it is not autonomous impersonation.',
          highlight:
              'Identity belongs to the client. Operation belongs to Orchestrate. The boundary is the product.',
        ),
      ],
    );

PublicContentScreen buildHowOrchestrateOperatesScreen() =>
    const PublicContentScreen(
      eyebrow: 'How Orchestrate operates',
      title:
          'Identity → trust → transport → readiness → governed execution → continuity.',
      subtitle:
          'A linear walkthrough of what actually happens after a client connects identity to the platform. Every layer is operationally truthful, mapping to runtime behavior rather than feature copy.',
      sideActions: [
        ContentAction(
            label: 'Why Orchestrate exists',
            path: '/why-orchestrate',
            filled: true),
        ContentAction(label: 'Trust architecture', path: '/trust-architecture'),
        ContentAction(label: 'Pricing', path: '/pricing'),
      ],
      sections: [
        ContentSection(
          title: '1. Domain attached',
          body:
              'The client confirms or attaches their sending domain: auraplatform.org, outreach.company.com, mail.company.com, or any apex / subdomain they control. The domain is the operational identity center; transports plug in beneath. Orchestrate creates a SendingDomain row with status=PENDING and surfaces the SPF, DKIM, and DMARC records to publish.',
          points: [
            'Domain inferred from Representation profile when available',
            'Manual domain entry supported for clients with separate sending infrastructure',
            'No transport required to begin DNS verification',
          ],
        ),
        ContentSection(
          title: '2. DNS verified',
          body:
              'Orchestrate runs live DNS lookups against the published records. SPF, DKIM, and DMARC are checked individually; per-record propagation history is recorded so the client can watch the verification window land. A polling worker re-checks pending domains automatically. The operator does not chase the registrar.',
          points: [
            'Live DNS queries via node:dns (no third-party deliverability vendor)',
            'Per-record verification history kept for audit',
            'Trust classification: pending → limited → warmup → full-trust',
          ],
        ),
        ContentSection(
          title: '3. Transport connected',
          body:
              'Three first-class transports: Google Workspace OAuth, Microsoft 365 OAuth, or custom SMTP + IMAP. OAuth runs entirely backend-side. Tokens never touch the browser. Custom SMTP + IMAP is one guided dialog: outbound credentials, inbound credentials (optional), and Orchestrate generates a per-transport DKIM keypair, vaults everything, and seeds the IMAP cursor at the current highest UID so no historical inbox is ever inspected.',
          points: [
            'Google / Microsoft via OAuth (send-only scope)',
            'Custom SMTP + IMAP for SES, Mailgun, SendGrid, Postfix, regional providers',
            'Per-transport DKIM keypair on custom SMTP',
            'IMAP cursor seeded at current highest UID, no historical scan',
          ],
        ),
        ContentSection(
          title: '4. Readiness governed',
          body:
              'A single backend authority (ExecutionEligibilityService) evaluates the full dependency chain: subscription, representation, business identity, sending domain, trust classification, sending transport, reply monitoring, dispatch eligibility. Every client surface (Operations, Infrastructure, Settings, Home, guidance drawer) reads from this one authority. There is no per-screen readiness composition that can drift.',
          points: [
            '8-layer dependency chain with per-layer state (ready / pending / waiting / blocked)',
            'Single backend authority, no per-screen recomposition',
            'Owner tagging: client / Orchestrate / operator per layer',
            'Inline resolution CTA on every client-pending layer',
          ],
        ),
        ContentSection(
          title: '5. Outbound execution activated',
          body:
              'When every layer is ready, dispatch eligibility flips. Outbound messages are generated against the business identity, paced under a per-mailbox governor, signed via DKIM at the adapter layer, and stamped with a custom X-Orchestrate-Operation-Id header so reply matching survives relays that strip standard threading headers. Every send passes a suppression check, a governance check, and a readiness check before leaving the process.',
          points: [
            'Per-message DKIM signing inside Orchestrate',
            'Custom operation-fingerprint header on outbound',
            'Suppression check at every FIRST_SEND and FOLLOWUP_SEND',
            'Governed pacing under per-mailbox in-flight cap',
          ],
        ),
        ContentSection(
          title: '6. Replies matched',
          body:
              'Operation-scoped IMAP ingestion runs against custom SMTP+IMAP transports. Phase 1 fetches headers only; phase 2 matches inbound against this client\'s outbound by In-Reply-To, References, or the operation-id header; phase 3 fetches bodies ONLY for matched UIDs. Unmatched mail stays in the upstream mailbox. Bodies are never read, content is never stored, and AI is never reached. Matched replies land in the Replies workspace.',
          points: [
            'Header-first, body-on-match-only',
            'No general inbox reading, operation-scoped attribution required',
            'Deduplication keyed by upstream message-id',
            'Unmatched mail never persisted, classified, surfaced, or fed to AI',
          ],
        ),
        ContentSection(
          title: '7. Follow-ups governed',
          body:
              'A matched reply against a lead automatically cancels queued FOLLOWUP_SEND jobs and any QUEUED / SCHEDULED OutreachMessage rows targeting that lead. The platform stops dispatching the moment a recipient responds, with no operator action required and no race condition between inbox triage and the next-send timer.',
        ),
        ContentSection(
          title: '8. Suppression enforced',
          body:
              'Opt-out signals, hard bounces, complaints, and operator blocks create SuppressionEntry rows scoped per organization and per client. The dispatch path checks suppression before every FIRST_SEND, every FOLLOWUP_SEND, and every direct email. There is no code path that bypasses the suppression check.',
        ),
        ContentSection(
          title: '9. Operational continuity maintained',
          body:
              'When something degrades (OAuth grant revoked, SMTP host throttling, DNS regression on an ACTIVE domain), the readiness chain reports the dependency by name, with ownership and a concrete next action. Recovery is automatic where Orchestrate owns it (transient provider hiccups, deliverability re-checks); the client sees what is happening and who owns the next step. No fake "everything green" while a subsystem is degraded.',
          highlight:
              'The runtime reports operational truth. "Recovering" / "Degraded" / "Reconnect required" name the real dependency, not a marketing state.',
        ),
      ],
    );

PublicContentScreen buildTrustArchitectureScreen() =>
    const PublicContentScreen(
      eyebrow: 'Trust architecture',
      title:
          'Operation-scoped access, encrypted vault, governed dispatch, AI bounded by attribution.',
      subtitle:
          'A consolidated view of how trust is architected at runtime, not a list of legal pages but the structural design of the system. Each layer below maps to a dedicated policy page for the formal commitment.',
      sideActions: [
        ContentAction(
            label: 'Mailbox access policy',
            path: '/legal/mailbox-access',
            filled: true),
        ContentAction(label: 'Credential handling', path: '/legal/credentials'),
        ContentAction(label: 'AI usage', path: '/legal/ai-usage'),
        ContentAction(
            label: 'Reply monitoring', path: '/legal/reply-monitoring'),
        ContentAction(
            label: 'Provider boundaries', path: '/legal/providers'),
        ContentAction(
            label: 'Suppression / opt-out', path: '/legal/suppression'),
        ContentAction(label: 'Retention / deletion', path: '/legal/retention'),
        ContentAction(label: 'Abuse policy', path: '/legal/abuse'),
      ],
      sections: [
        ContentSection(
          title: 'Mailbox access is operation-scoped at the read layer',
          body:
              'Orchestrate is not a general inbox reader. For custom IMAP transports, the platform fetches envelope + a narrow header set (Message-ID, In-Reply-To, References, From, To, Subject, X-Orchestrate-Operation-Id) BEFORE any matching decision. Bodies are only fetched after a message resolves to an OutreachMessage Orchestrate sent. Unmatched mail stays in the upstream mailbox. Body is never read, content is never stored, and AI is never reached. The full disclosure is the Mailbox access policy.',
          points: [
            'Header-first fetch on every IMAP poll',
            'Body fetched only after operation attribution',
            'Initial IMAP connect seeds cursor at current highest UID, no historical scan',
            'OAuth transports today use send-only scopes',
          ],
        ),
        ContentSection(
          title: 'Credentials are sealed by an encrypted vault',
          body:
              'OAuth refresh tokens, SMTP passwords, IMAP passwords, and DKIM private keys live behind a vault adapter (encrypted-DB AES-256-GCM or HashiCorp Vault). Production runtime refuses to boot with the in-memory adapter. Service code never imports a vault adapter directly; every read, write, rotation, and revocation is auditable. Audit log entries are metadata-only by construction, no credential content, no message body.',
        ),
        ContentSection(
          title: 'AI is bounded to operation-attributed data',
          body:
              'AI workers consume OutreachMessage rows (Orchestrate-generated) and Reply rows (operation-matched only). They do not receive raw IMAP messages, unmatched inbound mail, or the contents of a mailbox outside what Orchestrate generated or matched. Every AI invocation produces a stored decision record.',
        ),
        ContentSection(
          title: 'Transport is provider-agnostic, domain identity is primary',
          body:
              'Google Workspace, Microsoft 365, and custom SMTP+IMAP are interchangeable transport layers beneath the client\'s sending domain. Changing providers does not change operational identity. The trust classification (pending / limited / warmup / full-trust) is informed by SPF / DKIM / DMARC verification, mailbox health, and recent transport events, and it gates dispatch eligibility at the platform layer.',
        ),
        ContentSection(
          title: 'Suppression is enforced at every dispatch path',
          body:
              'UNSUBSCRIBE / HARD_BOUNCE / COMPLAINT / MANUAL_BLOCK suppression entries block FIRST_SEND, FOLLOWUP_SEND, and direct email. There is no code path that skips the suppression check. Opt-out replies are auto-converted to UNSUBSCRIBE entries.',
        ),
        ContentSection(
          title: 'Dispatch is governed, not autonomous',
          body:
              'Every send passes a readiness check, a suppression check, and a governance check. The dispatch governor enforces a per-mailbox in-flight cap so sending posture stays stable. Recovery branches re-converge the readiness state without requiring client lifecycle controls.',
        ),
        ContentSection(
          title: 'Operational state is audited and explainable',
          body:
              'Connect, reconnect, disconnect, credential rotation, IMAP-inbound attached, reply ingested, follow-up suppressed by reply, readiness transitions, and dispatch decisions all leave append-only audit rows. Audit content is metadata only, never credentials, never message bodies. The readiness engine renders the same authoritative state across Operations, Infrastructure, Settings, and the guidance drawer.',
          highlight:
              'No screen recomputes readiness independently. One backend authority, one truth, multiple read surfaces.',
        ),
        ContentSection(
          title: 'Runtime reports operational truth',
          body:
              'The platform does not over-claim. "Ready" only appears when the underlying state proves it. "Recovering" / "Degraded" / "Reconnect required" name the real dependency. Trust classification distinguishes "full-trust" from "warmup-allowed" from "pending". Reply monitoring is reported as "outbound-only" until inbound is genuinely wired. Operator-owned and client-owned next actions are tagged explicitly.',
        ),
      ],
    );

PublicContentScreen buildRetentionPolicyScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Data retention and deletion',
      subtitle:
          'Records are retained only as long as required to operate the service, meet legal obligations, and preserve the audit trail. This document names the retention windows and deletion paths.',
      sections: [
        ContentSection(
          title: 'Operational records',
          body:
              'Account profiles, workspace state, business identity, representation authorization, mailboxes, sending domains, dispatched messages, replies, meetings, and invoices are retained for the active life of the account and a defined post-termination window required for dispute resolution, financial accountability, and audit traceability.',
        ),
        ContentSection(
          title: 'Mailbox credentials',
          body:
              'Mailbox credentials are retained as long as the mailbox is connected. On disconnect or revocation, the vault entry is deleted and the cross-vault audit log preserves the action record (action, actor, organization, mailbox, outcome) but never the credential contents.',
        ),
        ContentSection(
          title: 'Audit logs',
          body:
              'Audit logs (credential vault audit, application-layer audit events such as SMTP_MAILBOX_CONNECTED / IMAP_INBOUND_ATTACHED / REPLY_INGESTED / FOLLOWUP_SUPPRESSED_BY_REPLY) are retained for the longer of the account lifecycle and the period legally required for security and audit purposes. Audit log content is metadata-only by construction; bodies and credentials are not part of audit records.',
        ),
        ContentSection(
          title: 'Operation-attributed mailbox content',
          body:
              'Reply rows persisted from inbound mail are retained alongside the operational record they belong to. Unmatched inbound mail is never persisted in the first place (see the Mailbox access policy) and therefore has no retention question.',
        ),
        ContentSection(
          title: 'Account deletion',
          body:
              'Account deletion requests are honored per the Account deletion page. Eligible profile data, workspace access, and user-provided account data are deleted. A limited set of records may be retained where required for billing accountability, fraud prevention, audit logs, legal compliance, dispute resolution, or unpaid balances.',
        ),
      ],
    );

PublicContentScreen buildBillingPolicyScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Billing and subscription policy',
      subtitle:
          'This policy explains how service tiers, invoicing, subscriptions, reminders, and payment responsibilities are handled through Orchestrate.',
      sections: [
        ContentSection(
          title: 'Managed-execution scopes',
          body:
              'Orchestrate is structured around two managed-infrastructure scopes: Opportunity (signal discovery, qualification, governed dispatch, follow-up continuity, reply handling) and Revenue (Opportunity plus revenue continuity: billing administration, reminders, statements, agreements, and payment accountability records).',
        ),
        ContentSection(
          title: 'Billing cycle and charges',
          body:
              'Charges may be one-time, recurring, milestone-based, or contract-based depending on the service relationship. Applicable charges, due dates, and billing cadence should be stated in the governing service agreement or accepted proposal.',
        ),
        ContentSection(
          title: 'Late payment posture',
          body:
              'Late payment may result in reminder escalation, service pause, restricted access, or withholding of certain service functions until account status is brought current.',
          highlight:
              'Billing administration support does not erase the client’s own responsibility for payment obligations owed to Orchestrate.',
        ),
        ContentSection(
          title: 'Client billing support',
          body:
              'Where the Revenue tier includes billing support for the client’s customers, Orchestrate acts as a structured service intermediary. It does not become the underlying contractual counterparty between the client and the customer unless expressly agreed in writing.',
        ),
      ],
    );

PublicContentScreen buildRefundPolicyScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Refund policy',
      subtitle:
          'Refund posture should remain clear, restrained, and tied to actual service conditions rather than vague promises.',
      sections: [
        ContentSection(
          title: 'General rule',
          body:
              'Fees already earned for completed service, delivered work, used subscription periods, activated infrastructure, or executed dispatch are generally non-refundable unless otherwise stated in writing.',
        ),
        ContentSection(
          title: 'When review may be appropriate',
          body:
              'Refund review may be appropriate where duplicate charges, proven billing error, material non-delivery of agreed setup work, or other clear account mistakes are established.',
        ),
        ContentSection(
          title: 'What is not a refund trigger by itself',
          body:
              'Low reply rates, low meeting conversion, customer non-payment, spam filtering, slow client response, or recipient silence are not by themselves grounds for refund because they depend on variables outside direct platform control.',
        ),
      ],
    );

PublicContentScreen buildAcceptableUseScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Acceptable use policy',
      subtitle:
          'Orchestrate is managed execution infrastructure for legitimate business communication, governed dispatch, revenue continuity, and accountable client records. It is not a tool for unsolicited bulk sending or sender-identity manipulation.',
      sections: [
        ContentSection(
          title: 'Prohibited behavior',
          body:
              'Use of the service for fraud, harassment, impersonation, unlawful targeting, deceptive billing, abuse of sender identity, delivery of malware, or unlawful data handling is prohibited.',
        ),
        ContentSection(
          title: 'Sender and deliverability discipline',
          body:
              'Users may not deliberately degrade sender reputation, rotate identities deceptively, conceal origin, or use the platform in a manner likely to create systemic abuse or blacklisting risk.',
        ),
        ContentSection(
          title: 'Operational protection',
          body:
              'Access may be restricted where behavior threatens infrastructure stability, payment integrity, legal compliance, account security, or the integrity of other clients using the system.',
        ),
      ],
    );

PublicContentScreen buildServiceAgreementScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Service agreement',
      subtitle:
          'The service agreement defines the operational relationship between Orchestrate and the client once the managed-execution scope is accepted.',
      sections: [
        ContentSection(
          title: 'What the agreement should establish',
          body:
              'The agreement should state the managed-execution scope, plan, billing cadence, deliverables, account visibility, communication posture, reminder handling, records responsibility, and any limits or exclusions that shape the operational relationship.',
        ),
        ContentSection(
          title: 'Why it matters here',
          body:
              'Because Orchestrate runs both signal-driven opportunity detection and revenue continuity under the same infrastructure, the service agreement is the place where responsibilities stop being implied and become explicit: what Orchestrate operates, what the client owns (business identity, sending identity), and where the boundary sits.',
          highlight:
              'This page does not replace a signed agreement. It marks that the signed agreement is structurally required.',
        ),
      ],
    );

PublicContentScreen buildDeliverabilityScreen() => const PublicContentScreen(
      eyebrow: 'Legal framework',
      title: 'Deliverability notice',
      subtitle:
          'Deliverability is treated as a working responsibility, but no honest system can promise universal inbox placement, responses, or conversions.',
      sections: [
        ContentSection(
          title: 'What deliverability depends on',
          body:
              'Inbox placement and outbound performance depend on sender domain condition, mailbox health, recipient filtering systems, message quality, targeting discipline, list quality, complaint behavior, and broader third-party infrastructure conditions.',
        ),
        ContentSection(
          title: 'What Orchestrate operates',
          body:
              'Orchestrate runs verified sending-identity setup (live SPF / DKIM / DMARC verification + automated re-checks), backend-owned mailbox OAuth with vault-backed credentials, governed dispatch, and continuous mailbox-health monitoring. The infrastructure improves the variables Orchestrate controls.',
        ),
        ContentSection(
          title: 'What cannot be promised',
          body:
              'No representation is made that a message will reach the inbox, receive a reply, convert to a meeting, or result in customer payment in every case.',
          highlight:
              'Deliverability work improves posture. It does not remove the reality of external systems and recipient choice.',
        ),
      ],
    );
