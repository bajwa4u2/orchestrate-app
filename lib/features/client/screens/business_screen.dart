import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/theme/workspace_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_business_identity_repository.dart';

/// THE BUSINESS BEING OPERATED — NOT A SETTINGS INDEX.
///
/// This screen was four headings over eight links. Every link was correct and
/// the screen said nothing: a person arriving learned only that configuration
/// exists somewhere below. The area that represents the company Orchestrate
/// acts for read as the place you go to change a preference.
///
/// It now answers the two questions somebody actually arrives with, in order,
/// before offering anywhere to go:
///
///   WHO IS THIS BUSINESS?   Its trading name and its legal name, which are
///   genuinely different things and are used for different purposes — one
///   appears on correspondence, the other on agreements.
///
///   CAN IT ACT RIGHT NOW?   Whether the business can currently send, and if
///   not, what is stopping it and what that blocks.
///
/// Then the configuration, which is what the screen used to be.
///
/// Composed only from truth the product already holds. No counts, no
/// dashboard: the relationship estate belongs to Relationships and the day's
/// work belongs to Today, and repeating either here would be a widget wall
/// pretending to be an overview.
class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  final ClientBusinessIdentityRepository _identity =
      ClientBusinessIdentityRepository();
  final ApiClient _api = ApiClient();

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _sending;

  /// Named separately, so a surface that could not load says which part is
  /// missing rather than presenting a partial answer as a whole one.
  final Set<String> _unavailable = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _unavailable.clear();
    });

    final results = await Future.wait([
      _identity.fetchProfile().then<Map<String, dynamic>?>((v) => v).catchError(
          (Object _) {
        _unavailable.add('who this business is');
        return null;
      }),
      _api
          .getJson('/client/outbound-email-readiness', surface: ApiSurface.client)
          .then<Map<String, dynamic>?>(
              (v) => v is Map ? Map<String, dynamic>.from(v) : null)
          .catchError((Object _) {
        _unavailable.add('whether it can send');
        return null;
      }),
    ]);

    if (!mounted) return;
    setState(() {
      // THE HUB WAS READING THE ENVELOPE, NOT THE PROFILE.
      //
      // `/client/business-identity` answers { profile: {...}, sections: [...] }.
      // Business identity unwraps it; this surface did not, so `legalName` and
      // `displayName` were read off the envelope and were always null. The
      // first thing an operator sees on Business said the business had no
      // trading name and no legal name — in red, as a problem — while Business
      // identity one tap away showed both set. Found on a Pixel by opening the
      // two surfaces in sequence, which is the only way this shows up: the
      // widget code reads correctly, it is the shape underneath that differs.
      final identity = results[0];
      final nested = identity == null ? null : identity['profile'];
      _profile = nested is Map
          ? Map<String, dynamic>.from(nested)
          : identity;
      _sending = results[1];
      _loading = false;
    });
  }

  String? _text(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty || s == 'null' ? null : s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _profile ?? const <String, dynamic>{};
    final legal = _text(profile['legalName']);
    final trading = _text(profile['displayName']);
    final ready = _sending?['ready'] == true;
    final blockers = (_sending?['blockers'] as List?) ?? const [];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const WorkspaceHeader(
          title: 'Business',
          context_: 'The company Orchestrate acts for, and how it is set up.',
        ),

        if (_unavailable.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1, right: 8),
                  child: Icon(Icons.info_outline, size: 15, color: Ws.info),
                ),
                Expanded(
                  child: Text(
                    'Could not load ${_unavailable.join(' or ')}. Everything '
                    'else on this screen is still accurate.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Ws.info),
                  ),
                ),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          ),

        // ── WHO THIS BUSINESS IS ──────────────────────────────────────────
        //
        // Two names that are not interchangeable. The trading name is what a
        // counterparty sees on correspondence; the legal name is what belongs
        // on an agreement. A product that shows only one leaves somebody to
        // guess which they are looking at — and this business genuinely has
        // two different ones.
        WorkspaceBand(
          title: 'THIS BUSINESS',
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Text('Loading…'),
              )
            else ...[
              WorkspaceRow(
                title: trading ?? 'No trading name set',
                detail: trading == null
                    ? 'Counterparties see this name on correspondence. Set it '
                        'in Business identity.'
                    : 'The name counterparties see on correspondence.',
                tone: trading == null ? RowTone.problem : RowTone.neutral,
                onTap: () => context.go('/client/representation'),
              ),
              WorkspaceRow(
                title: legal ?? 'No legal name set',
                detail: legal == null
                    ? 'Agreements and invoices are made in this name. Set it '
                        'in Business identity.'
                    : 'The name agreements and invoices are made in.',
                tone: legal == null ? RowTone.problem : RowTone.neutral,
                onTap: () => context.go('/client/representation'),
              ),
            ],
          ],
        ),

        // ── WHETHER IT CAN ACT ────────────────────────────────────────────
        //
        // Readiness stated as consequence rather than as configuration state.
        // "Mailbox unverified" is a fact about a record; "nothing can be sent
        // until the mailbox is verified" is the same fact said to somebody who
        // has to decide what to do about it.
        if (!_loading && _sending != null)
          WorkspaceBand(
            title: 'CAN THIS BUSINESS ACT',
            children: [
              if (ready)
                const WorkspaceRow(
                  title: 'Ready to write to counterparties',
                  detail: 'Sending is configured and working.',
                  tone: RowTone.good,
                )
              else ...[
                WorkspaceRow(
                  title: 'Nothing can be sent yet',
                  detail: blockers.isEmpty
                      ? 'Sending is not ready. No reason was reported, which '
                          'is itself worth raising.'
                      : 'Until this is resolved, no outreach and no reply '
                          'leaves the business.',
                  tone: RowTone.problem,
                ),
                for (final b in blockers.whereType<Map>())
                  WorkspaceRow(
                    title: _text(b['title']) ?? 'Sending is held',
                    detail: _text(b['reason']) ?? _text(b['message']),
                    tone: RowTone.problem,
                    onTap: () => context.go('/client/infrastructure'),
                  ),
              ],
            ],
          ),

        // ── HOW IT IS SET UP ──────────────────────────────────────────────
        //
        // Eight destinations collapse to four areas. These are settled
        // configuration: visited when something needs changing, not every
        // morning, and none of them belongs beside Today.
        //
        // Business is deliberately not the new settings dump: four
        // territories, each with a stated purpose. If a fifth ever seems
        // necessary, that is a signal something belongs somewhere else.
        //
        // The split from Account is doctrinal. Business is how the client's
        // own operation is configured. Account is their relationship with
        // Orchestrate. Keeping them apart is what stops Orchestrate's invoices
        // and the client's invoices sharing a screen.
        WorkspaceSection(
          title: 'Identity & presence',
          description: 'How the business appears to the people it writes to.',
          icon: Icons.badge_outlined,
          children: const [
            _Entry(
              label: 'Business identity',
              detail: 'Legal name, public identity, voice.',
              path: '/client/representation',
            ),
            _Entry(
              label: 'Branding',
              detail: 'Logo, colours, signatures, templates.',
              path: '/app/branding',
            ),
          ],
        ),
        WorkspaceSection(
          title: 'Targeting & discovery',
          description:
              'Who the business wants to reach, and how candidates are found.',
          icon: Icons.travel_explore_outlined,
          children: const [
            _Entry(
              label: 'Market and targeting',
              detail: 'Ideal customer, geography, industries.',
              path: '/client/business-identity',
            ),
          ],
        ),
        WorkspaceSection(
          title: 'Communication infrastructure',
          description:
              'The mailbox and sending setup the business communicates through.',
          icon: Icons.mark_email_read_outlined,
          children: const [
            _Entry(
              label: 'Mailbox and sending',
              detail: 'Transport, domain, authentication, health.',
              path: '/client/infrastructure',
            ),
          ],
        ),
        WorkspaceSection(
          title: 'Trust & governance',
          description:
              'What the business can evidence about itself, and what it keeps.',
          icon: Icons.verified_outlined,
          children: const [
            _Entry(
              label: 'Credentials',
              detail: 'Certifications, licences, insurance.',
              // /app/trust, not /client/trust. The real Credentials screen has
              // always been here; /client/trust answered with a generic
              // backend-surface diagnostic titled "Client-safe AI activity and
              // trust summary", and that is what this entry was opening.
              path: '/app/trust',
            ),
            _Entry(
              label: 'Evidence',
              detail: 'Supporting material held on record.',
              path: '/app/evidence',
            ),
            _Entry(
              label: 'Artifacts',
              detail: 'Documents produced and retained.',
              path: '/app/artifacts',
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry(
      {required this.label, required this.detail, required this.path});

  final String label;
  final String detail;
  final String path;

  @override
  Widget build(BuildContext context) {
    return WorkspaceRow(
      title: label,
      detail: detail,
      onTap: () => context.go(path),
      action: const Icon(Icons.chevron_right, size: 18, color: Ws.inkSubtle),
    );
  }
}
