import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/operator/system_status/system_status.dart';
import 'package:orchestrate_app/features/operator/system_status/system_status_ribbon.dart';

/// Operations console shell. Ten operational surfaces replacing the
/// legacy seven-faculty observation model.
///
/// Doctrine: every surface must support RESOLVE / INTERRUPT / FORWARD /
/// DISMISS. Surfaces that only observe are demoted under System & Tools.
class OperatorShell extends StatefulWidget {
  const OperatorShell({
    super.key,
    required this.currentPath,
    required this.child,
  });

  final String currentPath;
  final Widget child;

  static const double sidebarWidth = 264;
  static const double maxContentWidth = 1320;

  @override
  State<OperatorShell> createState() => _OperatorShellState();
}

class _OperatorShellState extends State<OperatorShell> {
  final _repo = SystemStatusRepository();
  SystemStatus? _status;
  bool _loading = true;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _kickoff();
  }

  Future<void> _kickoff() async {
    await _poll();
    Future<void> loop() async {
      while (!_disposed) {
        await Future<void>.delayed(const Duration(seconds: 60));
        if (_disposed) return;
        await _poll();
      }
    }
    unawaited(loop());
  }

  Future<void> _poll() async {
    try {
      final status = await _repo.fetch();
      if (_disposed) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (_) {
      if (_disposed) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<_NavGroup> get groups => [
        // ORGANISED BY WHAT AN OPERATOR IS RESPONSIBLE FOR.
        //
        // The old grouping — Operations, Support, System, Developer — described
        // where code lived rather than what work is owed. Seven items sat under
        // "Operations" with nothing in common except that they were not the
        // other three.
        //
        // Two of the target domains have no surface yet and are deliberately
        // absent rather than present and empty. AUTHORITY & GOVERNANCE has real
        // work — two designations are waiting on a decision right now — but that
        // work surfaces as Work Queue cases, and a nav item leading to a page
        // that only says "see the work queue" is a worse answer than no nav
        // item. COMMERCIAL OPERATIONS has eight live endpoints (agreements,
        // invoices, obligations, acceptances, standing) and no screen at all;
        // it appears when it has one.
        _NavGroup(
          label: 'Work',
          attentionKey: 'ops',
          items: const [
            // Everything a human owes a decision on, whatever produced it.
            _NavItem('Work queue', '/ops/work', Icons.inbox_outlined),
          ],
        ),
        _NavGroup(
          label: 'Clients & businesses',
          attentionKey: null,
          items: const [
            _NavItem('Clients', '/ops/clients', Icons.people_outline),
            // Counterparty records and how they arrived. It is the same
            // subject as Clients seen from the data side, not a separate one.
            _NavItem('Contacts & imports', '/ops/inventory',
                Icons.inventory_2_outlined),
          ],
        ),
        _NavGroup(
          label: 'Communication & delivery',
          attentionKey: null,
          items: const [
            // The mailbox and sending identity a business communicates through.
            _NavItem('Transport', '/ops/transport', Icons.send_outlined),
            // Whether a specific message may go, and what happened when it did.
            _NavItem('Dispatch', '/ops/dispatch', Icons.policy_outlined),
            _NavItem('Campaigns', '/ops/campaigns', Icons.campaign_outlined),
          ],
        ),
        _NavGroup(
          label: 'Trust & integrity',
          attentionKey: null,
          items: const [
            // Provenance of what was sent: template lineage, attribution,
            // recovery. Reached only from System & tools before now.
            _NavItem('Message provenance', '/ops/governance',
                Icons.verified_outlined),
            // What was done, by whom, to what, and when.
            _NavItem('Audit history', '/ops/history', Icons.history_outlined),
          ],
        ),
        _NavGroup(
          label: 'System operations',
          attentionKey: null,
          items: const [
            _NavItem('Jobs', '/ops/jobs', Icons.work_outline),
            _NavItem('System & tools', '/ops/system', Icons.settings_outlined),
          ],
        ),
        // A DEVIATION FROM THE SEVEN, STATED RATHER THAN HIDDEN.
        //
        // Inquiries and Feedback are both somebody outside asking for a person.
        // That is not communication infrastructure, not a client record, and
        // not system health, so forcing either into one of those would misname
        // it. They keep their own heading because the work is genuinely a
        // different shape: listening rather than operating.
        _NavGroup(
          label: 'Listening',
          attentionKey: null,
          items: const [
            _NavItem('Inquiries', '/ops/inquiries', Icons.support_agent_outlined),
            _NavItem('Feedback', '/ops/feedback', Icons.rate_review_outlined),
          ],
        ),
        // NOT PART OF THE OPERATOR PRODUCT.
        //
        // Logs, raw runtime and debugging are developer observability, and the
        // frozen distinction says they must not be mixed with operational
        // control. They stay reachable — deleting them would strand the
        // surfaces and removing them from navigation would make them URL-only,
        // which is the thing this reconstruction exists to end — but they sit
        // last, under their own name, and nothing above them links here.
        _NavGroup(
          label: 'Engineering',
          attentionKey: null,
          items: const [
            _NavItem('System doctor', '/operator/system-doctor',
                Icons.health_and_safety_outlined),
            _NavItem('Backend surfaces', '/operator/system', Icons.code_outlined),
            _NavItem('Debug checks', '/ops/debug', Icons.tune_outlined),
          ],
        ),
      ];

  // The retired estate carried a per-faculty attention rollup that no
  // surviving surface consumed. Real attention lives in the Work Queue, which
  // counts cases a human owes a decision on rather than a sum of module badges.
  Map<String, int> get _attentionMap => const {};

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        body: Row(
          children: [
            _Sidebar(
              currentPath: widget.currentPath,
              groups: groups,
              attention: _attentionMap,
            ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(currentPath: widget.currentPath, groups: groups),
                  SystemStatusRibbon(status: _status, loading: _loading),
                  Expanded(
                    child: Container(
                      color: AppTheme.background,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxWidth: OperatorShell.maxContentWidth),
                            child: SizedBox.expand(
                              child: SelectionArea(child: widget.child),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentPath,
    required this.groups,
    required this.attention,
  });

  final String currentPath;
  final List<_NavGroup> groups;
  final Map<String, int> attention;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: OperatorShell.sidebarWidth,
      color: AppTheme.sidebar,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 14, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Brand(currentPath: currentPath),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _NavGroupWidget(
                      group: group,
                      currentPath: currentPath,
                      attentionCount:
                          attention[group.attentionKey ?? ''] ?? 0,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.currentPath});
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final selected = currentPath == '/ops/work';
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      onTap: () => context.go('/ops/work'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.panel : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: selected ? AppTheme.line : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrandAssets.operatorLockup(context),
            const SizedBox(height: 12),
            Text('Operations console',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Resolve · Interrupt · Forward · Dismiss',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.muted, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.currentPath, required this.groups});

  final String currentPath;
  final List<_NavGroup> groups;

  String _title() {
    for (final group in groups) {
      for (final item in group.items) {
        if (item.path == currentPath) return '${group.label} · ${item.label}';
      }
    }
    // Sub-routes inherit the heading of whatever contains them. The exact
    // matches above handle destinations; these are the paths beneath one.
    //
    // These used to name groups — Operations, Support, System — that the
    // navigation no longer has, so a person deeper in the product was told they
    // were somewhere that does not exist.
    for (final group in groups) {
      for (final item in group.items) {
        if (currentPath.startsWith('${item.path}/')) {
          return '${group.label} · ${item.label}';
        }
      }
    }
    return 'Operator';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: SafeArea(
        bottom: false,
        left: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 14),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: OperatorShell.maxContentWidth),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _title(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.subdued,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const _TopPill(label: 'Operator'),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () async {
                      await AuthSessionController.instance.clear();
                      if (context.mounted) context.go('/ops/login');
                    },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _NavGroupWidget extends StatelessWidget {
  const _NavGroupWidget({
    required this.group,
    required this.currentPath,
    required this.attentionCount,
  });

  final _NavGroup group;
  final String currentPath;
  final int attentionCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  group.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.subdued,
                        letterSpacing: 0.4,
                        fontSize: 11,
                      ),
                ),
              ),
              if (attentionCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.rose.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$attentionCount',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.rose,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final item in group.items) ...[
          _ShellNavButton(
            item: item,
            selected: currentPath == item.path ||
                (item.path != '/ops/work' &&
                    currentPath.startsWith('${item.path}/')),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _ShellNavButton extends StatelessWidget {
  const _ShellNavButton({required this.item, required this.selected});

  final _NavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: () => context.go(item.path),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.panelRaised : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border:
                Border.all(color: selected ? AppTheme.lineSoft : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 16,
                color: selected ? AppTheme.text : AppTheme.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 13,
                        color: selected ? AppTheme.text : AppTheme.muted,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavGroup {
  const _NavGroup({
    required this.label,
    required this.items,
    required this.attentionKey,
  });
  final String label;
  final List<_NavItem> items;
  final String? attentionKey;
}

class _NavItem {
  const _NavItem(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}
