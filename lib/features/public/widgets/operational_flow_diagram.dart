import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';

/// Vertical operational-flow diagram. Renders an ordered sequence of
/// operational stages as connected nodes — each stage carries a label,
/// a description, and an optional state badge. Used on the public
/// "How Orchestrate operates" walkthrough so the visitor sees
/// progression as architecture, not as a wall of prose.
///
/// Visual contract: a left-side timeline rail with circular nodes
/// (numbered, governance-toned), each node connected by a vertical
/// line; a right-side card with the stage title, body, and optional
/// ownership tag. The diagram is calm, infrastructural, and reads
/// in dependency order top-to-bottom.
class OperationalFlowDiagram extends StatelessWidget {
  const OperationalFlowDiagram({super.key, required this.stages});

  final List<OperationalFlowStage> stages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
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
              for (var i = 0; i < stages.length; i++)
                _StageRow(
                  index: i,
                  total: stages.length,
                  stage: stages[i],
                  narrow: narrow,
                  theme: theme,
                ),
            ],
          ),
        );
      },
    );
  }
}

class OperationalFlowStage {
  const OperationalFlowStage({
    required this.label,
    required this.body,
    this.ownership,
    this.bullets = const <String>[],
  });

  final String label;
  final String body;

  /// Optional ownership tag — `'client'` / `'orchestrate'` / `'operator'`.
  /// Drives the small chip rendered next to the stage title.
  final String? ownership;
  final List<String> bullets;
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.index,
    required this.total,
    required this.stage,
    required this.narrow,
    required this.theme,
  });

  final int index;
  final int total;
  final OperationalFlowStage stage;
  final bool narrow;
  final ThemeData theme;

  bool get _isLast => index == total - 1;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RailColumn(
            index: index,
            isLast: _isLast,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: _isLast ? 0 : 22),
              child: _StageCard(stage: stage, narrow: narrow, theme: theme),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailColumn extends StatelessWidget {
  const _RailColumn({required this.index, required this.isLast});

  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.publicSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.publicAccent, width: 2),
            ),
            child: Text(
              '${index + 1}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.publicAccent,
                  ),
            ),
          ),
          if (!isLast)
            Expanded(
              child: Container(
                width: 2,
                color: AppTheme.publicLine,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.stage,
    required this.narrow,
    required this.theme,
  });

  final OperationalFlowStage stage;
  final bool narrow;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final ownership = stage.ownership;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius - 4),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  stage.label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (ownership != null) ...[
                const SizedBox(width: 8),
                _OwnerChip(ownership: ownership),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            stage.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.publicText,
              height: 1.45,
            ),
          ),
          if (stage.bullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final bullet in stage.bullets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 7, right: 10),
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppTheme.publicMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        bullet,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.publicMuted,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _OwnerChip extends StatelessWidget {
  const _OwnerChip({required this.ownership});

  final String ownership;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = ownership.toLowerCase();
    final isClient = label == 'client';
    final isOperator = label == 'operator';
    final colour = isClient
        ? AppTheme.publicAccent
        : isOperator
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary;
    final display = isClient
        ? 'Client'
        : isOperator
            ? 'Operator'
            : 'Orchestrate';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colour.withValues(alpha: 0.40)),
      ),
      child: Text(
        display,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colour,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
