import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';

/// System & Tools — nav hub for observation surfaces and legacy screens.
///
/// All screens that were in the old faculty navigation are preserved here
/// for reference access. They are no longer in primary nav because they
/// are observer-only: they do not support RESOLVE / INTERRUPT / FORWARD /
/// DISMISS. Use the operational subsystem screens for those actions.
class OpsSystemScreen extends StatelessWidget {
  const OpsSystemScreen({super.key});

  static const _groups = [
    _TileGroup(
      label: 'Cognition & observability',
      tiles: [
        _Tile(
          label: 'Continuity',
          description: 'Blocked work, continuity signals, execution state overview',
          icon: Icons.sync_outlined,
          path: '/ops/continuity',
        ),
        _Tile(
          label: 'Runtime Truth',
          description: 'Platform state, discovery profiles, provider status',
          icon: Icons.hub_outlined,
          path: '/ops/runtime-truth',
        ),
        _Tile(
          label: 'Trust & Readiness',
          description: 'Client trust scores, warmup state, readiness assessment',
          icon: Icons.verified_outlined,
          path: '/ops/trust-readiness',
        ),
        _Tile(
          label: 'Platform Supervision',
          description: 'System-level oversight and platform health',
          icon: Icons.monitor_heart_outlined,
          path: '/ops/platform-supervision',
        ),
      ],
    ),
    _TileGroup(
      label: 'AI & Adaptation',
      tiles: [
        _Tile(
          label: 'Adaptation Hub',
          description: 'Suggestions, playbooks, healing, guardrails, patterns',
          icon: Icons.psychology_outlined,
          path: '/ops/adaptation',
        ),
        _Tile(
          label: 'Governance / AI Approvals',
          description: 'AI-authored message governance review queue',
          icon: Icons.policy_outlined,
          path: '/ops/governance/ai-approvals',
        ),
      ],
    ),
    _TileGroup(
      label: 'Audit & history',
      tiles: [
        _Tile(
          label: 'Audit Timeline',
          description: 'Full append-only audit log across all entities',
          icon: Icons.history_outlined,
          path: '/ops/history',
        ),
        _Tile(
          label: 'Governance Log',
          description: 'Cross-client provenance and message lifecycle',
          icon: Icons.receipt_long_outlined,
          path: '/ops/governance',
        ),
      ],
    ),
    _TileGroup(
      label: 'Developer & legacy',
      tiles: [
        _Tile(
          label: 'System Doctor',
          description: 'Diagnostic checks and system health probes',
          icon: Icons.health_and_safety_outlined,
          path: '/operator/system-doctor',
        ),
        _Tile(
          label: 'Backend Surfaces',
          description: 'Operator API explorer and backend tool surfaces',
          icon: Icons.code_outlined,
          path: '/operator/system',
        ),
        _Tile(
          label: 'Campaign Lifecycle (legacy)',
          description: 'Legacy campaign/lifecycle view — use Campaigns screen instead',
          icon: Icons.campaign_outlined,
          path: '/ops/continuity/campaigns',
          legacy: true,
        ),
        _Tile(
          label: 'Overview (legacy)',
          description: 'Legacy operator command surface',
          icon: Icons.dashboard_outlined,
          path: '/ops/overview-legacy',
          legacy: true,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(),
          const SizedBox(height: 24),
          ...List.generate(_groups.length, (i) {
            final group = _groups[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i > 0) const SizedBox(height: 24),
                Text(
                  group.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.subdued,
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: group.tiles
                      .map((t) => _SystemTile(tile: t))
                      .toList(),
                ),
              ],
            );
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('System & Tools',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Observation surfaces, AI subsystems, audit history, and developer tools. '
          'These screens do not support operational actions — use the primary '
          'operational screens for RESOLVE · INTERRUPT · FORWARD · DISMISS.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.muted, height: 1.5),
        ),
      ],
    );
  }
}

class _SystemTile extends StatelessWidget {
  const _SystemTile({required this.tile});
  final _Tile tile;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(tile.path),
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Container(
        width: 280,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: tile.legacy ? AppTheme.background : AppTheme.panel,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
              color: tile.legacy ? AppTheme.line : AppTheme.lineSoft),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              tile.icon,
              size: 16,
              color: tile.legacy ? AppTheme.subdued : AppTheme.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tile.label,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontSize: 13,
                                color: tile.legacy
                                    ? AppTheme.subdued
                                    : AppTheme.text,
                              ),
                        ),
                      ),
                      if (tile.legacy)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.subdued.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('legacy',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.subdued)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tile.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: tile.legacy ? AppTheme.subdued : AppTheme.muted,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 14,
                color: tile.legacy ? AppTheme.line : AppTheme.subdued),
          ],
        ),
      ),
    );
  }
}

class _TileGroup {
  const _TileGroup({required this.label, required this.tiles});
  final String label;
  final List<_Tile> tiles;
}

class _Tile {
  const _Tile({
    required this.label,
    required this.description,
    required this.icon,
    required this.path,
    this.legacy = false,
  });
  final String label;
  final String description;
  final IconData icon;
  final String path;
  final bool legacy;
}
