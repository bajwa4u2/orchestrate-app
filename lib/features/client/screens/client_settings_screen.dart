import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/data/repositories/auth_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';
import 'package:orchestrate_app/core/theme/workspace_theme.dart';
import 'package:orchestrate_app/core/layout/workspace.dart';

/// WORKSPACE SETTINGS, REDUCED TO WHAT IT ACTUALLY OWNS.
///
/// This screen held nine panels and, by ownership, none of them were its own.
/// Business readiness belonged to the Business hub, business naming to
/// Business identity, billing to Plan and billing, records to Records, the
/// signature to Mailbox and sending, and a person's trusted devices to Account
/// and security — which had itself been reduced to three links pointing
/// elsewhere while the real personal security controls sat here, on a page the
/// product describes as preferences.
///
/// Controls accumulate on a screen like this because it is the one nobody
/// argues about. That is not ownership, and it cost the estate a great deal:
/// two writers for the business name, a compliance footer nobody could find
/// from the refusal that named it, and a security surface with no security.
///
/// What remains is small, and the page is deliberately not padded to disguise
/// that. It says where the things people arrive looking for actually live,
/// because pointing at an owner is a legitimate job and reproducing one is not.
/// If real workspace preferences are introduced later, this is where they
/// belong — and they will be the first thing this screen has ever owned.
class ClientSettingsScreen extends StatefulWidget {
  const ClientSettingsScreen({super.key});

  @override
  State<ClientSettingsScreen> createState() => _ClientSettingsScreenState();
}

class _ClientSettingsScreenState extends State<ClientSettingsScreen> {
  final AuthRepository _authRepository = AuthRepository();
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await _authRepository.logout();
    } catch (_) {
      // Local session cleanup still completes sign out if the network call
      // fails. Being unable to reach the server must not strand somebody
      // signed in on a machine they are trying to leave.
    } finally {
      await AuthSessionController.instance.clear();
      if (mounted) context.go('/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;

    return ClientPage(
      eyebrow: 'Settings',
      title: 'Workspace settings',
      // No readiness verdict here any more. This page used to open with a
      // banner about setup, permissions and blockers — a fourth opinion on a
      // question the Business hub decides.
      subtitle: 'How this workspace behaves. What the business is, what it '
          'can do, and where you are signed in are each decided elsewhere.',
      actions: [
        TextButton.icon(
          onPressed: _signingOut ? null : _signOut,
          icon: _signingOut
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout, size: 18),
          label: Text(_signingOut ? 'Signing out' : 'Sign out'),
        ),
      ],
      children: [
        ClientPanel(
          title: 'Where things are configured',
          subtitle: 'This workspace has no preferences of its own yet. What '
              'people usually arrive here looking for is owned elsewhere, and '
              'this is where.',
          children: [
            WorkspaceRow(
              title: 'How this business is named and reached',
              detail: 'Legal name, trading name, website, postal address '
                  'and market.',
              onTap: () => context.go('/client/representation'),
              action: const Icon(Icons.chevron_right,
                  size: 18, color: Ws.inkSubtle),
            ),
            WorkspaceRow(
              title: 'How this business speaks in its outbound',
              detail: 'Sending mailbox, signature, and what has to be true '
                  'before anything can leave.',
              onTap: () => context.go('/client/infrastructure'),
              action: const Icon(Icons.chevron_right,
                  size: 18, color: Ws.inkSubtle),
            ),
            WorkspaceRow(
              title: 'Where you are signed in',
              detail: 'Trusted devices, and ending one. These were on this '
                  'page; a session is not a workspace preference.',
              onTap: () => context.go('/account/security'),
              action: const Icon(Icons.chevron_right,
                  size: 18, color: Ws.inkSubtle),
            ),
            WorkspaceRow(
              title: 'Whether this business can act',
              detail: 'Readiness, and whatever is blocking it. Stated once, '
                  'where it is decided.',
              onTap: () => context.go('/client/business'),
              action: const Icon(Icons.chevron_right,
                  size: 18, color: Ws.inkSubtle),
            ),
            // SUPPORT HAD NO WAY IN ON A PHONE.
            //
            // Its entry is a rail action, and the rail only exists on desktop.
            // On a phone it was reachable by knowing to search for it, or from
            // Billing — and the account menu offers 'Tell us something', which
            // is feedback, not a support case. Somebody who needed help had
            // nowhere obvious to go.
            WorkspaceRow(
              title: 'Getting help from Orchestrate',
              detail: 'Open a support request, and see the ones you have '
                  'already opened.',
              onTap: () => context.go('/client/support'),
              action: const Icon(Icons.chevron_right,
                  size: 18, color: Ws.inkSubtle),
            ),
            WorkspaceRow(
              title: 'What you are on, and what it costs',
              detail: 'Plan, subscription state and billing documents.',
              onTap: () => context.go('/account/plan'),
              action: const Icon(Icons.chevron_right,
                  size: 18, color: Ws.inkSubtle),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ClientPanel(
          title: 'Legal',
          subtitle: 'The policies that govern how Orchestrate handles your '
              'data and service.',
          children: [
            ClientInfoRow(
              title: 'Privacy policy',
              primary:
                  'How Orchestrate collects, uses, and protects workspace data.',
              trailing: TextButton(
                onPressed: () => context.push('/legal/privacy'),
                child: const Text('Open'),
              ),
            ),
            ClientInfoRow(
              title: 'Terms of service',
              primary:
                  'The agreement that governs use of the Orchestrate service.',
              trailing: TextButton(
                onPressed: () => context.push('/legal/terms'),
                child: const Text('Open'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Kept last and stated plainly. Signing out ends this session on this
        // device; it is not revoking a trusted device, not withdrawing
        // authority for the business, and not closing an account.
        ClientInfoRow(
          title: 'Signed in as',
          primary: session.email,
          secondary: 'Signing out ends this session on this device. It does '
              'not change what the business permits you to do.',
        ),
      ],
    );
  }
}
