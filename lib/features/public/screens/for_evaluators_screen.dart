import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/system/widgets/trust_primitives.dart';

/// Public evaluator / procurement / security-review surface.
///
/// A curated path for a technical, security, or procurement evaluator
/// who needs to understand — without digging through ten legal pages
/// — exactly what Orchestrate accesses, what it does not, and how the
/// runtime is architected to keep those guarantees true.
///
/// Tone: calm, specific, infrastructural. Each section names the real
/// runtime behavior and links to the formal policy commitment.
class ForEvaluatorsScreen extends StatelessWidget {
  const ForEvaluatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(theme: theme),
              const SizedBox(height: 24),
              const _AccessSummary(),
              const SizedBox(height: 24),
              _ArchitectureLayers(theme: theme),
              const SizedBox(height: 24),
              _RuntimeToPolicyMapping(theme: theme),
              const SizedBox(height: 24),
              const _GuaranteeStrip(),
              const SizedBox(height: 24),
              _FurtherReading(theme: theme),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.publicAccentSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'For evaluators',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppTheme.publicAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'A short, specific account of what Orchestrate accesses, what it does not, and how the runtime is engineered to keep those guarantees true.',
            style:
                theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(
              'This is a curated path for security, procurement, and technical evaluators. Each section below maps the runtime behavior to the formal policy commitment. The full legal index is one link away; this page is the structural story underneath it.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.publicMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessSummary extends StatelessWidget {
  const _AccessSummary();

  @override
  Widget build(BuildContext context) {
    return TrustGuaranteePanel(
      title: 'What Orchestrate accesses — at a glance',
      subtitle:
          'Mailbox access is bounded at the read layer, not just by policy.',
      guarantees: [
        'Outbound dispatch via the transport the client connects (OAuth send-only scope, or custom SMTP with the client\'s own credentials).',
        'Inbound mail only when ingestion is wired (custom IMAP today). IMAP fetches headers first; bodies are fetched only for messages that match an outbound operation Orchestrate sent.',
        'Sending domain DNS records (live SPF / DKIM / DMARC lookups, no third-party deliverability vendor).',
        'Business identity, representation authorization, sending-domain rows, mailbox metadata, dispatched-message records, matched replies, audit logs — all in the platform database.',
      ],
    );
  }
}

class _ArchitectureLayers extends StatelessWidget {
  const _ArchitectureLayers({required this.theme});
  final ThemeData theme;

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
          Text(
            'Architecture layers',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Five operational layers, each with its own ownership and trust boundary. The boundary between them is the product — the client owns identity, the platform owns operation.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 880;
              final cards = [
                ReadinessBoundaryCard(
                  title: '1. Identity',
                  body:
                      'Business identity, representation authorization, sending domain, operational mailbox identity. The client is the legal and commercial author; Orchestrate stores the canonical record.',
                  state: TrustState.verified,
                  ownership: OperationalOwnership.client,
                ),
                ReadinessBoundaryCard(
                  title: '2. Authorization',
                  body:
                      'OAuth grant or SMTP credential authorization. Backend-owned consent flows for OAuth; encrypted vault for both. No credential ever appears in API responses, browser state, or logs.',
                  state: TrustState.verified,
                  ownership: OperationalOwnership.client,
                ),
                ReadinessBoundaryCard(
                  title: '3. Transport',
                  body:
                      'Google Workspace OAuth, Microsoft 365 OAuth, or custom SMTP + IMAP. Provider-agnostic by construction — domain identity is primary, transport is interchangeable infrastructure beneath it.',
                  state: TrustState.verified,
                  ownership: OperationalOwnership.client,
                ),
                ReadinessBoundaryCard(
                  title: '4. Trust',
                  body:
                      'SPF, DKIM, DMARC verified via live DNS; per-transport DKIM keypair generated for custom SMTP. Trust classification (pending → limited → warmup → full) gates dispatch at the platform layer.',
                  state: TrustState.verified,
                  ownership: OperationalOwnership.orchestrate,
                ),
                ReadinessBoundaryCard(
                  title: '5. Execution',
                  body:
                      'Governed dispatch under per-mailbox pacing, DKIM signing inside Orchestrate, operation-scoped IMAP reply ingestion, follow-up suppression on matched reply, suppression-list enforcement on every send. All audited.',
                  state: TrustState.verified,
                  ownership: OperationalOwnership.orchestrate,
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i < cards.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final card in cards)
                    SizedBox(
                      width: (constraints.maxWidth - 28) / 2,
                      child: card,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RuntimeToPolicyMapping extends StatelessWidget {
  const _RuntimeToPolicyMapping({required this.theme});
  final ThemeData theme;

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
          Text(
            'Runtime → policy mapping',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Each runtime guarantee maps to a formal policy commitment. Click through for the binding statement.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 18),
          for (final m in _mappings) ...[
            _MappingRow(mapping: m, theme: theme),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  static final _mappings = <_Mapping>[
    const _Mapping(
      runtime:
          'IMAP polling fetches envelope + selected headers only; bodies are fetched solely after a message resolves to an OutreachMessage Orchestrate sent.',
      policy: 'Mailbox access policy',
      path: '/legal/mailbox-access',
    ),
    const _Mapping(
      runtime:
          'On initial IMAP connect, lastSeenUid is seeded to the current highest UID via STATUS uidNext. No historical inbox is inspected by default.',
      policy: 'Mailbox access policy',
      path: '/legal/mailbox-access',
    ),
    const _Mapping(
      runtime:
          'Outbound messages stamp X-Orchestrate-Operation-Id at the SMTP adapter so reply matching survives relays that strip standard threading headers.',
      policy: 'Reply monitoring disclosure',
      path: '/legal/reply-monitoring',
    ),
    const _Mapping(
      runtime:
          'AI workers consume OutreachMessage rows (Orchestrate-generated) and Reply rows (operation-matched). Raw IMAP messages and unmatched inbound mail never enter an AI pipeline.',
      policy: 'AI usage disclosure',
      path: '/legal/ai-usage',
    ),
    const _Mapping(
      runtime:
          'CredentialVaultService is the single access path for OAuth refresh tokens, SMTP passwords, IMAP passwords, and DKIM private keys. Production refuses to boot with the in-memory adapter.',
      policy: 'Credential handling disclosure',
      path: '/legal/credentials',
    ),
    const _Mapping(
      runtime:
          'SuppressionEntry check runs in the FIRST_SEND code path, the FOLLOWUP_SEND code path, and the direct-email send path. There is no code path that bypasses the check.',
      policy: 'Suppression and opt-out policy',
      path: '/legal/suppression',
    ),
    const _Mapping(
      runtime:
          'A matched reply against a lead automatically cancels queued FOLLOWUP_SEND jobs and QUEUED/SCHEDULED OutreachMessage rows for the same lead.',
      policy: 'Reply monitoring disclosure',
      path: '/legal/reply-monitoring',
    ),
    const _Mapping(
      runtime:
          'Audit rows (SMTP_MAILBOX_CONNECTED, IMAP_INBOUND_ATTACHED, REPLY_INGESTED, FOLLOWUP_SUPPRESSED_BY_REPLY, vault store/read/rotate/revoke) capture metadata only — never credentials, never message bodies.',
      policy: 'Retention and deletion policy',
      path: '/legal/retention',
    ),
  ];
}

class _Mapping {
  const _Mapping({
    required this.runtime,
    required this.policy,
    required this.path,
  });
  final String runtime;
  final String policy;
  final String path;
}

class _MappingRow extends StatelessWidget {
  const _MappingRow({required this.mapping, required this.theme});

  final _Mapping mapping;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final runtimeBlock = Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.publicSurfaceSoft,
            borderRadius: BorderRadius.circular(AppTheme.radius - 6),
            border: Border.all(color: AppTheme.publicLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Runtime',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.publicMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mapping.runtime,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicText,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
        final policyBlock = Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.publicSurface,
            borderRadius: BorderRadius.circular(AppTheme.radius - 6),
            border: Border.all(color: AppTheme.publicLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Policy',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.publicMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mapping.policy,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicText,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton(
                onPressed: () => context.go(mapping.path),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Read policy →'),
              ),
            ],
          ),
        );
        if (narrow) {
          return Column(
            children: [
              runtimeBlock,
              const SizedBox(height: 8),
              policyBlock,
            ],
          );
        }
        // IntrinsicHeight is required because stretch + Row + Expanded
        // inside a scroll view (PublicShell wraps the body in a
        // SingleChildScrollView) needs a bounded vertical extent to
        // compute the stretch. Without it the Row layout fails silently
        // on release builds and blanks the body.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 7, child: runtimeBlock),
              const SizedBox(width: 12),
              Expanded(flex: 4, child: policyBlock),
            ],
          ),
        );
      },
    );
  }
}

class _GuaranteeStrip extends StatelessWidget {
  const _GuaranteeStrip();

  @override
  Widget build(BuildContext context) {
    return TrustGuaranteePanel(
      title: 'Negative guarantees',
      subtitle:
          'What the runtime will not do, by construction. These are not policy promises — they are structural properties of the implementation.',
      guarantees: [
        'Will not read the body of an inbox message that does not resolve to a known Orchestrate operation.',
        'Will not dispatch to a recipient with a matching SuppressionEntry.',
        'Will not return a credential in any API response, log entry, or browser-accessible state.',
        'Will not claim "ready" while any layer of the readiness chain is unresolved.',
        'Will not feed an AI pipeline with mailbox content that is not operation-attributed.',
        'Will not boot in production with the in-memory vault adapter (refuses to start).',
        'Will not auto-imply Google/Microsoft inbound monitoring exists — OAuth is send-only on this deployment.',
        'Will not mirror the Sent folder; only Orchestrate-generated outbound is stored.',
      ],
    );
  }
}

class _FurtherReading extends StatelessWidget {
  const _FurtherReading({required this.theme});
  final ThemeData theme;

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
          Text(
            'Further reading',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in _links)
                OutlinedButton(
                  onPressed: () => context.go(entry.path),
                  child: Text(entry.label),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static const _links = <_LinkEntry>[
    _LinkEntry('Trust architecture', '/trust-architecture'),
    _LinkEntry('Mailbox access policy', '/legal/mailbox-access'),
    _LinkEntry('Reply monitoring', '/legal/reply-monitoring'),
    _LinkEntry('Credential handling', '/legal/credentials'),
    _LinkEntry('AI usage', '/legal/ai-usage'),
    _LinkEntry('Provider boundaries', '/legal/providers'),
    _LinkEntry('Suppression / opt-out', '/legal/suppression'),
    _LinkEntry('Abuse policy', '/legal/abuse'),
    _LinkEntry('Retention / deletion', '/legal/retention'),
    _LinkEntry('How Orchestrate operates', '/how-orchestrate-operates'),
    _LinkEntry('Why Orchestrate exists', '/why-orchestrate'),
  ];
}

class _LinkEntry {
  const _LinkEntry(this.label, this.path);
  final String label;
  final String path;
}
