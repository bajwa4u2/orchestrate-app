import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'ops_empty_state.dart';

/// ONE SHAPE FOR EVERY CROSS-ORGANISATION VIEW.
///
/// Clients, transport, imports and campaigns ask the same question in four
/// domains: what is the state of this, and what does the platform owe about it.
/// They were four bespoke screens carrying four copies of a loading spinner, an
/// error panel and a row layout, each drifting a little from the others.
///
/// The rows are deliberately plain. These surfaces exist so a platform operator
/// can SEE across the businesses Orchestrate serves; the deciding happens in
/// the work queue, where every action is bounded, audited and says what it
/// writes. A second place to act would be a second place for those properties
/// to be forgotten.
class PlatformSurface<T> extends StatefulWidget {
  const PlatformSurface({
    super.key,
    required this.title,
    required this.describes,
    required this.load,
    required this.rows,
    required this.build,
    required this.emptyHeadline,
    this.emptyDetail,
    this.summarise,
  });

  final String title;

  /// What this answers, in a sentence. Not what it is called again.
  final String describes;

  final Future<Map<String, dynamic>> Function() load;

  /// Pull the list out of the response.
  final List<T> Function(Map<String, dynamic> data) rows;

  final Widget Function(BuildContext context, T row) build;

  final String emptyHeadline;
  final String? emptyDetail;

  /// A line under the title: how many, how many need something.
  final String Function(List<T> rows)? summarise;

  @override
  State<PlatformSurface<T>> createState() => _PlatformSurfaceState<T>();
}

class _PlatformSurfaceState<T> extends State<PlatformSurface<T>> {
  List<T> _rows = const [];
  String? _note;
  bool _loading = true;
  String? _error;

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
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _rows = widget.rows(data);
        _note = data['note'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 5),
                  Text(
                    widget.summarise != null && !_loading && _error == null
                        ? widget.summarise!(_rows)
                        : widget.describes,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.muted, height: 1.5),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              icon: _loading
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.muted),
                    )
                  : const Icon(Icons.refresh, size: 15),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.muted,
                side: const BorderSide(color: AppTheme.line),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(child: _body()),
        if (_note != null && !_loading && _error == null) ...[
          const SizedBox(height: 12),
          // What this surface does NOT reach, said on the surface itself. It is
          // the half of a cross-organisation permission worth stating.
          Text(_note!,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.subdued, height: 1.5)),
        ],
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_outlined, size: 34, color: AppTheme.amber),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
                child: const Text('Try again',
                    style: TextStyle(color: AppTheme.background)),
              ),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return OpsEmptyState(
        headline: widget.emptyHeadline,
        detail: widget.emptyDetail ??
            'This reads across every organisation on the platform.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => widget.build(context, _rows[i]),
    );
  }
}

/// A row: a name, some facts, and — when there is one — what the platform owes.
class PlatformRow extends StatelessWidget {
  const PlatformRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.facts = const [],
    this.owed,
    this.attention = false,
  });

  final String title;
  final String subtitle;

  /// Short label/value pairs. State, never content.
  final List<(String, String)> facts;

  /// What Orchestrate has to do about this, in a sentence. Null when nothing.
  final String? owed;

  final bool attention;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
            color: attention ? AppTheme.amber.withOpacity(0.35) : AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, height: 1.25)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.subdued)),
                    ],
                  ],
                ),
              ),
              if (facts.isNotEmpty)
                Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    for (final (label, value) in facts)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(value,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(label,
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.subdued)),
                        ],
                      ),
                  ],
                ),
            ],
          ),
          if (owed != null && owed!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.flag_outlined, size: 13, color: AppTheme.amber),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(owed!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.muted, height: 1.45)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
