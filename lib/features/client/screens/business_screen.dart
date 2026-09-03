import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';

/// HOW THIS BUSINESS OPERATES.
///
/// Eight sidebar entries collapse to four areas here — representation,
/// branding, infrastructure, mailbox, credentials, evidence, artifacts and
/// records each had equal navigational weight with the daily work, which is
/// how a workspace ends up with sixteen destinations.
///
/// These are settled configuration. They are visited when something needs
/// changing, not every morning, and none of them belongs beside Today.
///
/// Business is deliberately not the new settings dump: four territories, each
/// with a stated purpose. If a fifth ever seems necessary, that is a signal
/// something belongs somewhere else entirely.
///
/// The split from Account is doctrinal, not cosmetic. Business is how the
/// client's own operation is configured. Account is their relationship with
/// Orchestrate. Keeping them apart is what stops Orchestrate's invoices and
/// the client's invoices sharing a screen, which is exactly what the old
/// Records surface did.
class BusinessScreen extends StatelessWidget {
  const BusinessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const WorkspaceHeader(
          title: 'Business',
          context_: 'How your operation is configured.',
        ),
        WorkspaceSection(
          title: 'Identity & presence',
          description: 'How the business appears to the people it writes to.',
          icon: Icons.badge_outlined,
          children: [
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
          children: [
            _Entry(
              label: 'Market and targeting',
              detail: 'Ideal customer, geography, industries.',
              path: '/client/representation/targeting',
            ),
            _Entry(
              label: 'Discovery',
              detail: 'How candidates are sourced and qualified.',
              path: '/client/representation',
            ),
          ],
        ),
        WorkspaceSection(
          title: 'Communication infrastructure',
          description:
              'The mailbox and sending setup the business communicates through.',
          icon: Icons.mark_email_read_outlined,
          children: [
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
          children: [
            _Entry(
              label: 'Credentials',
              detail: 'Certifications, licences, insurance.',
              path: '/client/trust',
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
      action: const Icon(Icons.chevron_right, size: 18, color: AppTheme.publicMuted),
    );
  }
}
