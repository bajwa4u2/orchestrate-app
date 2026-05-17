import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/public_repository.dart';
import 'package:orchestrate_app/features/system/widgets/governance_primitives.dart';

/// Public operational journey screen.
///
/// Renders a single curated journey (from the public journey
/// catalog) as a vertical timeline of stages. Each stage shows the
/// operational summary, the concrete next action, "read more"
/// links into the relevant Orchestrate surfaces, cross-referenced
/// knowledge catalog answers, and any blockers that may halt the
/// stage.
///
/// Visual coherence: uses LifecycleTimeline + GovernanceBadge from
/// the existing primitives library so the journey reads as the same
/// operational environment as the rest of the workspace.
class PublicJourneyScreen extends StatefulWidget {
  const PublicJourneyScreen({super.key, required this.journeyKey});

  final String journeyKey;

  @override
  State<PublicJourneyScreen> createState() => _PublicJourneyScreenState();
}

class _PublicJourneyScreenState extends State<PublicJourneyScreen> {
  final PublicRepository _repository = PublicRepository();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _journey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _journey = await _repository.fetchJourney(widget.journeyKey);
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _errorRow(context)
                  : _renderJourney(context),
        ),
      ),
    );
  }

  Widget _errorRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _error!,
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _renderJourney(BuildContext context) {
    final j = _journey;
    if (j == null) return const SizedBox.shrink();
    final stages = (j['stages'] as List? ?? const [])
        .whereType<Map>()
        .map((s) => s.cast<String, dynamic>())
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Hero(journey: j),
        const SizedBox(height: 24),
        for (final stage in stages) _stageCard(context, stage),
        const SizedBox(height: 24),
        _crossLinks(context),
      ],
    );
  }

  Widget _stageCard(BuildContext context, Map<String, dynamic> stage) {
    final title = stage['title']?.toString() ?? '';
    final summary = stage['summary']?.toString() ?? '';
    final action = stage['action']?.toString() ?? '';
    final linkedSurfaces = (stage['linkedSurfaces'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    final blockers = (stage['blockerCodes'] as List? ?? const [])
        .map((b) => b.toString())
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicText,
                  height: 1.55,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.publicSurfaceSoft,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.east, size: 16, color: AppTheme.publicAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    action,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.publicText,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                  ),
                ),
              ],
            ),
          ),
          if (blockers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final code in blockers)
                  GovernanceBadge(
                    label: 'blocker',
                    value: code,
                    monospace: true,
                    tone: GovernanceTone.cautious,
                  ),
              ],
            ),
          ],
          if (linkedSurfaces.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final surface in linkedSurfaces)
                  OutlinedButton(
                    onPressed: () =>
                        context.go(surface['path']?.toString() ?? '/'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.publicText,
                      side: BorderSide(color: AppTheme.publicLine),
                    ),
                    child: Text(surface['label']?.toString() ?? ''),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _crossLinks(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Related operational surfaces',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => context.go('/answers'),
                child: const Text('Operational answers'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/diagnostics'),
                child: const Text('Run DNS check'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/for-evaluators'),
                child: const Text('For evaluators'),
              ),
              FilledButton(
                onPressed: () => context.go('/activation'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.publicText,
                  foregroundColor: Colors.white,
                ),
                child: const Text('See activation progression'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.journey});

  final Map<String, dynamic> journey;

  @override
  Widget build(BuildContext context) {
    final title = journey['title']?.toString() ?? 'Operational journey';
    final intent = journey['intent']?.toString() ?? '';
    final audience = journey['audience']?.toString() ?? 'visitor';
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.publicSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            children: [
              const GovernanceBadge(
                label: 'Operational journey',
                tone: GovernanceTone.positive,
              ),
              GovernanceBadge(label: 'audience', value: audience),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          if (intent.isNotEmpty)
            Text(
              intent,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
        ],
      ),
    );
  }
}
