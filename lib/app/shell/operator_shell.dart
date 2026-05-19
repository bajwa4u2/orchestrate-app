import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/brand/brand_assets.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/features/operator_workspace/models/cognition_models.dart';
import 'package:orchestrate_app/features/operator_workspace/repositories/operator_cognition_repository.dart';
import 'package:orchestrate_app/features/operator_workspace/widgets/operator_attention_badge.dart';
import 'package:orchestrate_app/features/operator_workspace/widgets/operator_trust_ribbon.dart';

/// Operator shell expressing the seven-faculty IA from
/// OPERATOR_WORKSPACE_SPECIFICATION.md §4. Cognition / Trust & Readiness
/// / Continuity / Runtime Truth / Adaptation / Governance / Platform
/// Supervision — plus a Developer drawer for debug-class surfaces
/// below the IA fold.
///
/// The shell mounts a periodic 60s poll against /operator/cognition/home
/// to power the trust ribbon and faculty attention badges.
class OperatorShell extends StatefulWidget {
  const OperatorShell({
    super.key,
    required this.currentPath,
    required this.child,
  });

  final String currentPath;
  final Widget child;

  static const double sidebarWidth = 296;
  static const double maxContentWidth = 1320;

  @override
  State<OperatorShell> createState() => _OperatorShellState();
}

class _OperatorShellState extends State<OperatorShell> {
  final _repo = OperatorCognitionRepository();
  CognitionHome? _home;
  bool _loading = true;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _kickoff();
  }

  Future<void> _kickoff() async {
    await _poll();
    // Poll every 60s while the shell is mounted.
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
      final home = await _repo.fetchHome();
      if (_disposed) return;
      setState(() {
        _home = home;
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

  // ── faculty groups (seven faculties + developer drawer) ──

  List<_NavGroup> get groups => [
        _NavGroup(
          label: 'Cognition',
          facultyKey: 'cognition',
          items: const [
            _NavItem('Home', '/ops/overview', Icons.radar_outlined),
          ],
        ),
        _NavGroup(
          label: 'Trust & Readiness',
          facultyKey: 'trustReadiness',
          items: const [
            _NavItem('Readiness board', '/ops/trust-readiness',
                Icons.verified_user_outlined),
          ],
        ),
        _NavGroup(
          label: 'Continuity',
          facultyKey: 'continuity',
          items: const [
            _NavItem('Execution continuity', '/ops/continuity',
                Icons.timeline_outlined),
            _NavItem('Governance review',
                '/ops/governance', Icons.shield_outlined),
          ],
        ),
        _NavGroup(
          label: 'Runtime Truth',
          facultyKey: 'runtimeTruth',
          items: const [
            _NavItem('Providers · mailboxes · DNS', '/ops/runtime-truth',
                Icons.signal_cellular_alt_outlined),
            _NavItem('Providers (legacy)', '/operator/providers',
                Icons.hub_outlined),
          ],
        ),
        _NavGroup(
          label: 'Adaptation & Cognition',
          facultyKey: 'adaptation',
          items: const [
            _NavItem('Hub', '/ops/adaptation', Icons.psychology_outlined),
            _NavItem('Convergence metrics', '/ops/adaptation/convergence',
                Icons.trending_down_outlined),
            _NavItem('AI economy', '/ops/adaptation/ai-economy',
                Icons.account_balance_outlined),
            _NavItem('Escalations', '/ops/adaptation/escalations',
                Icons.escalator_warning_outlined),
            _NavItem('Reasoning cache', '/ops/adaptation/reasoning-cache',
                Icons.cached_outlined),
            _NavItem('Suggestions', '/ops/adaptation/suggestions',
                Icons.lightbulb_outline),
            _NavItem('Playbooks', '/ops/adaptation/playbooks',
                Icons.menu_book_outlined),
            _NavItem('Self-healing', '/ops/adaptation/healing',
                Icons.healing_outlined),
            _NavItem('Cost guardrails', '/ops/adaptation/guardrails',
                Icons.shield_moon_outlined),
            _NavItem('Patterns', '/ops/adaptation/patterns',
                Icons.scatter_plot_outlined),
            _NavItem('Learning feed', '/ops/adaptation/learning-feed',
                Icons.list_alt_outlined),
            _NavItem('Operational memory', '/ops/adaptation/memory',
                Icons.memory_outlined),
          ],
        ),
        _NavGroup(
          label: 'Governance',
          facultyKey: 'governance',
          items: const [
            _NavItem('Dispatch governance', '/ops/governance',
                Icons.policy_outlined),
            _NavItem('AI approvals', '/ops/governance/ai-approvals',
                Icons.gavel_outlined),
            _NavItem('Audit timeline', '/ops/governance/audit',
                Icons.history_outlined),
            _NavItem('Inquiries', '/ops/inquiries',
                Icons.support_agent_outlined),
          ],
        ),
        _NavGroup(
          label: 'Platform Supervision',
          facultyKey: 'platformSupervision',
          items: const [
            _NavItem('Cross-tenant', '/ops/platform-supervision',
                Icons.public_outlined),
          ],
        ),
        _NavGroup(
          label: 'Developer drawer',
          facultyKey: null,
          items: const [
            _NavItem('System Doctor', '/operator/system-doctor',
                Icons.health_and_safety_outlined),
            _NavItem('Backend surfaces', '/operator/system',
                Icons.code_outlined),
            _NavItem('Debug / system checks', '/ops/debug', Icons.tune_outlined),
            _NavItem('Clients (legacy)', '/operator/clients',
                Icons.business_outlined),
            _NavItem('Campaigns (legacy)', '/operator/campaigns',
                Icons.campaign_outlined),
          ],
        ),
      ];

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
              attention: _home?.attentionByFaculty ?? const {},
            ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(currentPath: widget.currentPath, groups: groups),
                  OperatorTrustRibbon(
                      ribbon: _home?.trustRibbon, loading: _loading),
                  Expanded(
                    child: Container(
                      color: AppTheme.background,
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(28, 22, 28, 22),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxWidth: OperatorShell.maxContentWidth),
                            child: SizedBox.expand(child: widget.child),
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
          padding: const EdgeInsets.fromLTRB(22, 24, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Brand(currentPath: currentPath),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.panel,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppTheme.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppTheme.emerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Supervision live',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _NavGroupWidget(
                      group: group,
                      currentPath: currentPath,
                      attentionCount:
                          attention[group.facultyKey ?? ''] ?? 0,
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
    final selected = currentPath == '/ops/overview';
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      onTap: () => context.go('/ops/overview'),
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
            const SizedBox(height: 14),
            Text('Supervision console',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Cognition · Readiness · Continuity · Truth · Adaptation · Governance · Platform',
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
    // Detail / drill routes
    if (currentPath.startsWith('/ops/inquiries/')) return 'Governance · Inquiry detail';
    if (currentPath.startsWith('/ops/continuity')) return 'Continuity';
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
              constraints: const BoxConstraints(
                  maxWidth: OperatorShell.maxContentWidth),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _title(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
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
                      if (context.mounted) {
                        context.go('/ops/login');
                      }
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
          padding: const EdgeInsets.only(left: 10, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  group.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.subdued,
                        letterSpacing: 0.4,
                      ),
                ),
              ),
              OperatorAttentionBadge(count: attentionCount),
            ],
          ),
        ),
        for (final item in group.items) ...[
          _ShellNavButton(
            item: item,
            selected: currentPath == item.path,
          ),
          const SizedBox(height: 6),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.panelRaised : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
                color: selected ? AppTheme.lineSoft : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 17,
                color: selected ? AppTheme.text : AppTheme.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 14,
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
    required this.facultyKey,
  });
  final String label;
  final List<_NavItem> items;
  final String? facultyKey;
}

class _NavItem {
  const _NavItem(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}
