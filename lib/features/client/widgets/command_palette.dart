import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';

/// FAST ACCESS TO THINGS A PERSON MEANS TO DO.
///
/// This is what lets navigation shrink to three destinations without capability
/// becoming hard to reach. Compactness has to improve convenience, not just
/// reduce visible links.
///
/// It is deliberately NOT a directory of the backend. There are 418 routes
/// behind this product; exposing them here would rebuild the subsystem museum
/// inside a text field, in service-layer vocabulary nobody outside the codebase
/// speaks. Commands are written the way a person would say them.
class CommandPaletteHost extends StatefulWidget {
  const CommandPaletteHost({super.key, required this.child});

  final Widget child;

  static void open(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => const _CommandPalette(),
    );
  }

  @override
  State<CommandPaletteHost> createState() => _CommandPaletteHostState();
}

class _CommandPaletteHostState extends State<CommandPaletteHost> {
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const _OpenPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            const _OpenPaletteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenPaletteIntent: CallbackAction<_OpenPaletteIntent>(
            onInvoke: (_) {
              CommandPaletteHost.open(context);
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: widget.child),
      ),
    );
  }
}

class _OpenPaletteIntent extends Intent {
  const _OpenPaletteIntent();
}

class _Command {
  const _Command(this.label, this.path, this.icon, {this.hint});

  final String label;
  final String path;
  final IconData icon;
  final String? hint;
}

/// Human actions and places, not endpoints.
const List<_Command> _commands = [
  _Command('What needs me', '/client/today', Icons.today_outlined),
  _Command('Relationships', '/client/relationships', Icons.hub_outlined),
  _Command('Pipeline', '/client/relationships?view=pipeline', Icons.view_kanban_outlined,
      hint: 'Relationships, as a board'),
  _Command('Waiting on a reply', '/client/relationships?view=waiting',
      Icons.hourglass_empty),
  _Command('Business settings', '/client/business', Icons.tune_outlined),
  _Command('Targeting and discovery', '/client/business#targeting',
      Icons.travel_explore_outlined),
  _Command('Mailbox and sending', '/client/business#infrastructure',
      Icons.mark_email_read_outlined),
  _Command('Credentials and evidence', '/client/business#trust',
      Icons.verified_outlined),
  _Command('People and authority', '/account/people', Icons.badge_outlined,
      hint: 'Who can decide for the business'),
  _Command('Plan and billing', '/account/plan', Icons.receipt_long_outlined,
      hint: 'Your subscription to Orchestrate'),
  _Command('Account and security', '/account/security', Icons.lock_outline),
  _Command('Support', '/client/support', Icons.help_outline),
];

class _CommandPalette extends StatefulWidget {
  const _CommandPalette();

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Command> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _commands;
    return _commands
        .where((c) =>
            c.label.toLowerCase().contains(q) ||
            (c.hint?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 90, left: 20, right: 20),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search or jump to…',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
            ),
            const Divider(height: 1, color: AppTheme.publicLine),
            Flexible(
              child: results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Nothing matches that.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.publicMuted)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final c = results[i];
                        return ListTile(
                          dense: true,
                          leading:
                              Icon(c.icon, size: 18, color: AppTheme.publicMuted),
                          title: Text(c.label,
                              style: Theme.of(context).textTheme.bodyMedium),
                          subtitle: c.hint == null
                              ? null
                              : Text(c.hint!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppTheme.publicMuted)),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.go(c.path);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
