import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/layout/workspace.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/core/ui/governed_action.dart';
import 'package:orchestrate_app/data/repositories/client/client_today_repository.dart';

/// THE OPERATIONAL HOME.
///
/// This replaces a dashboard that opened with a status hero and a grid of
/// counters — Evaluated 13, Suppressed 0, opportunities, "Your market coverage
/// is active", "No action is needed from you". None of those carried a
/// decision, and the last one was a large card whose entire content was the
/// news that it did not need to exist.
///
/// One rule decides what appears here:
///
///   A card that carries neither a decision, an action, nor consequential
///   operational context does not belong on Today.
///
/// Which is why a healthy morning is nearly empty. That is the product working,
/// not the product missing.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _repo = ClientTodayRepository();
  TodayState? _state;
  bool _loading = true;
  Refusal? _refusal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _refusal = null;
    });
    try {
      final state = await _repo.load();
      if (!mounted) return;
      setState(() {
        _state = state;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refusal = Refusal.unexpected(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspaceHeader(
          title: 'Today',
          // Orientation only. Not plan, not tier, not onboarding state.
          context_: _contextLine(),
          trailing: IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Refresh',
            visualDensity: VisualDensity.compact,
          ),
        ),
        if (_refusal != null) RefusalNotice(refusal: _refusal!, onRetry: _load),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _body(session),
        ),
      ],
    );
  }

  String? _contextLine() {
    final s = _state;
    if (s == null) return null;
    final needs = s.needsYou.length;
    if (needs > 0) return '$needs thing${needs == 1 ? '' : 's'} need you';
    return null;
  }

  Widget _body(AuthSessionController session) {
    final s = _state;
    if (s == null) return const SizedBox.shrink();

    final needsYou = s.needsYou;
    final inFlight = s.inFlight;
    final changed = s.changed;

    // Onboarding appears ONLY while incomplete and actionable. Once done it is
    // history, and history does not get permanent space.
    final setupIncomplete = !session.hasSetupCompleted;

    if (needsYou.isEmpty && inFlight.isEmpty && changed.isEmpty && !setupIncomplete) {
      return const QuietState(
        message: 'Nothing needs you right now.',
        hint: 'Work in flight and anything that changes will appear here.',
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        WorkspaceBand(
          title: 'NEEDS YOU',
          children: [
            if (setupIncomplete)
              WorkspaceRow(
                title: 'Finish setting up your business',
                detail:
                    'Discovery and outreach stay off until your market and '
                    'sending are configured.',
                tone: RowTone.attention,
                action: TextButton(
                  onPressed: () => context.go('/client/setup'),
                  child: const Text('Continue'),
                ),
                onTap: () => context.go('/client/setup'),
              ),
            for (final item in needsYou)
              WorkspaceRow(
                title: item.title,
                detail: item.detail,
                meta: item.meta,
                tone: item.severity == 'CRITICAL' || item.severity == 'ERROR'
                    ? RowTone.problem
                    : RowTone.attention,
              ),
          ],
        ),
        WorkspaceBand(
          title: 'IN FLIGHT',
          children: [
            for (final item in inFlight)
              WorkspaceRow(
                title: item.title,
                detail: item.detail,
                meta: item.meta,
                tone: RowTone.waiting,
              ),
          ],
        ),
        WorkspaceBand(
          title: 'CHANGED',
          children: [
            for (final item in changed)
              WorkspaceRow(
                title: item.title,
                detail: item.detail,
                meta: item.meta,
                tone: item.severity == 'WARNING'
                    ? RowTone.problem
                    : (item.intent == 'INTERESTED' ? RowTone.good : RowTone.neutral),
                onTap: () => context.go('/client/relationships'),
              ),
          ],
        ),
        if (needsYou.isEmpty && !setupIncomplete)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: QuietState(message: 'Nothing needs a decision from you.'),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// A small, quiet marker used where a state genuinely helps orientation.
/// Never a banner, never permanent, never about plan or onboarding.
class StateChip extends StatelessWidget {
  const StateChip({super.key, required this.label, this.tone = RowTone.neutral});

  final String label;
  final RowTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      RowTone.attention => AppTheme.amber,
      RowTone.problem => AppTheme.rose,
      RowTone.good => AppTheme.emerald,
      _ => AppTheme.publicMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
