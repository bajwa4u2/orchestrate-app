/// WHOSE WORKSPACE THIS IS.
///
/// The shell answered "which human am I?" and never "which business am I
/// operating?". On a phone the app bar carried the surface name and the account
/// avatar, and the avatar is the PERSON — so the only identity on screen was
/// the individual signed in, never the business the workspace acts for. The
/// desktop rail named the business but carried no mark, and lost even the name
/// when collapsed.
///
/// The business leads. The person stays available in the account control, which
/// is where a person's own account, security and sign-out belong — making that
/// control the business mark would mean tapping a company logo to reach a
/// personal account, and would blur the line the account estate depends on.
///
/// These widgets are CONSUMERS of Branding and Business identity, never
/// writers. They hold no name and no asset of their own, so changing either
/// upstream changes what appears here, and an operator who later acts for a
/// second business sees that business rather than a hardcoded one.
library;

import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/config/app_config.dart';
import 'package:orchestrate_app/core/theme/workspace_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_branding_repository.dart';

/// Whether the current business has a logo, asked once per business.
///
/// Cached per process because a mark sits in the chrome of every workspace
/// screen, and a fetch per build would put a request behind every navigation
/// for a fact that changes only when somebody uploads a logo. Keyed by the
/// workspace it was resolved for, so switching business context re-asks rather
/// than showing the previous company's mark.
class _LogoPresence {
  static bool? has;
  static String? resolvedFor;

  static Future<void> resolve(VoidCallback onChanged) async {
    final workspace = AuthSessionController.instance.workspaceName;
    if (resolvedFor == workspace) return;
    resolvedFor = workspace;
    try {
      final branding = await ClientBrandingRepository().fetchBranding();
      final assets = branding['assets'];
      has = assets is Map && assets['logo_primary'] != null;
    } catch (_) {
      // A branding fetch that fails must not cost the workspace its name.
      has = false;
    }
    onChanged();
  }
}

/// The business's mark: its logo, or a business initial when it has none.
///
/// Never the operator's initials, which would present the person as though they
/// were the company.
class WorkspaceMark extends StatefulWidget {
  const WorkspaceMark({super.key, this.size = 26, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  State<WorkspaceMark> createState() => _WorkspaceMarkState();
}

class _WorkspaceMarkState extends State<WorkspaceMark> {
  @override
  void initState() {
    super.initState();
    _LogoPresence.resolve(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;
    final business = session.workspaceName.trim();
    final tone = widget.onDark ? Ws.onField : Ws.accent;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: _LogoPresence.has == true
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                '${AppConfig.normalizedApiBaseUrl}'
                '/clients/me/branding/logo/logo_primary',
                headers: {'Authorization': 'Bearer ${session.token}'},
                fit: BoxFit.contain,
                // A logo that fails to load falls back to the business mark
                // rather than leaving a broken glyph where identity belongs.
                errorBuilder: (_, __, ___) => Initial(
                  text: business,
                  tone: tone,
                  size: widget.size,
                ),
              ),
            )
          : Initial(text: business, tone: tone, size: widget.size),
    );
  }
}

/// The workspace's mark and name together, for the phone app bar.
///
/// It replaced the surface name rather than crowding in beside it: every screen
/// already states its own name in its heading, its breadcrumb, and the selected
/// destination in the bottom bar. The app bar was the fourth place saying
/// "Today" and the only place that could have said whose Today it was.
class WorkspaceIdentity extends StatelessWidget {
  const WorkspaceIdentity({super.key, required this.showPerson});

  /// True on the account estate, where the PERSON is the subject.
  ///
  /// Entering your own account changes what the screen is about; it does not
  /// change who owns the workspace, so leaving it restores the business.
  final bool showPerson;

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final person = session.fullName.trim().isNotEmpty
            ? session.fullName.trim()
            : session.email;
        final business = session.workspaceName.trim();
        final label = showPerson
            ? person
            : (business.isEmpty ? 'This workspace' : business);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showPerson)
              SizedBox(
                width: 26,
                height: 26,
                child: Initial(text: person, tone: Ws.inkMuted, size: 26),
              )
            else
              const WorkspaceMark(),
            const SizedBox(width: 10),
            // A long trading name is a real thing to have. It ellipsises rather
            // than overflowing or pushing the account control off the edge, and
            // the tooltip carries the whole of it.
            Flexible(
              child: Tooltip(
                message: label,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Ws.ink,
                      ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// An initial, drawn from whichever identity is the subject.
class Initial extends StatelessWidget {
  const Initial({
    super.key,
    required this.text,
    required this.tone,
    this.size = 26,
  });

  final String text;
  final Color tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    final letter =
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
          color: tone,
        ),
      ),
    );
  }
}
