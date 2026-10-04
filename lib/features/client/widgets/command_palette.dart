import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/market/client_market.dart';
import 'package:orchestrate_app/core/relationships/client_relationships.dart';
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
///
/// ONLY PLACES THAT EXIST TODAY (DD-34, founder, 2 Oct 2026). Search kept
/// offering the retired Business pages (business settings, targeting,
/// credentials, evidence) after Setup replaced them, so a client searching
/// found yesterday's product. Each command is a current place; a test holds
/// every path here to a mounted, current screen.
const List<_Command> _commands = [
  _Command('What needs me', '/client/today', Icons.today_outlined),
  _Command('Market', '/client/market', Icons.travel_explore_outlined,
      hint: 'Businesses worth your time'),
  _Command('Customers', '/client/relationships', Icons.people_outline),
  _Command('Money', '/client/money', Icons.payments_outlined,
      hint: 'Agreed, invoiced, paid'),
  // Setup's steps are on Setup's own strip; Search does not repeat them.
  _Command('Setup', '/client/setup?step=ready', Icons.tune_outlined,
      hint: 'Your business, buyers, offer, proof, payment, email'),
  // NO PIPELINE, NO WAITING VIEW.
  //
  // Both pointed at ?view= values nothing reads. The relationships screen has
  // one ordering — anything contested or never reached first — and offering a
  // board and a filter that quietly resolve to that same list is worse than
  // not offering them: a person searches the palette for the view they were
  // promised, lands on the ordinary list, and concludes the product is broken
  // rather than that the view was never built.
  _Command('People and authority', '/account/people', Icons.badge_outlined,
      hint: 'Who can decide for the business'),
  _Command('Plan and billing', '/account/plan', Icons.receipt_long_outlined,
      hint: 'Your subscription to Orchestrate'),
  _Command('Your record with Orchestrate', '/account/record', Icons.folder_outlined,
      hint: "Orchestrate's agreement and invoices to you"),
  _Command('Account and security', '/account/security', Icons.lock_outline,
      hint: 'Your name, signed-in devices, delete account'),
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
  void initState() {
    super.initState();
    // Customers and Market businesses are searched too; ask for both once,
    // quietly, so typing finds them even when neither screen was opened yet.
    final rel = ClientRelationships.instance;
    if (!rel.hasAnswer && !rel.isLoading) {
      rel.load().then((_) {
        if (mounted) setState(() {});
      }, onError: (Object _) {});
    }
    final market = ClientMarket.instance;
    if (!market.hasAnswer && !market.isLoading && market.error == null) {
      market.load().then((_) {
        if (mounted) setState(() {});
      }, onError: (Object _) {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Places, then the businesses themselves: a customer by name or domain,
  /// and anyone on Market. Search used to know only page names, so typing a
  /// customer's name said "Nothing matches that." (2 Oct 2026).
  List<_Command> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _commands;
    final places = _commands
        .where((c) =>
            c.label.toLowerCase().contains(q) ||
            (c.hint?.toLowerCase().contains(q) ?? false))
        .toList();
    final customers = [
      for (final r in ClientRelationships.instance.list?.relationships ?? const [])
        if (r.counterparty.toLowerCase().contains(q) ||
            r.counterpartyKey.toLowerCase().contains(q))
          _Command(r.counterparty, '/client/relationships/${r.id}',
              Icons.people_outline,
              hint: 'Customer'),
    ];
    final market = [
      for (final c in ClientMarket.instance.view?.candidates ?? const [])
        if (!c.hasRelationship &&
            (c.name.toLowerCase().contains(q) || c.domain.toLowerCase().contains(q)))
          _Command(c.name, Uri(path: '/client/market', queryParameters: {'focus': c.key}).toString(),
              Icons.travel_explore_outlined,
              hint: c.geography == null ? 'On Market' : 'On Market · ${c.geography}'),
    ];
    return [...customers.take(8), ...market.take(8), ...places];
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
        // As tall as the window allows (4 Oct 2026): a fixed 460 cut the last
        // entry in half on a desktop with room to spare.
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: (MediaQuery.sizeOf(context).height * 0.75).clamp(300.0, 640.0),
        ),
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
                            // Read before the dialog closes: its context is
                            // gone after pop, and a navigation through it went
                            // nowhere (founder, live walk, 2 Oct 2026).
                            final router = GoRouter.of(context);
                            Navigator.of(context).pop();
                            router.go(c.path);
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
