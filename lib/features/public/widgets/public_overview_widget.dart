import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/public_repository.dart';

class PublicOverviewWidget extends StatefulWidget {
  const PublicOverviewWidget({super.key});

  @override
  State<PublicOverviewWidget> createState() => _PublicOverviewWidgetState();
}

class _PublicOverviewWidgetState extends State<PublicOverviewWidget> {
  final PublicRepository _repository = PublicRepository();

  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchOverview();
  }

  Future<void> _fetchOverview() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final payload = await _repository.fetchLifecycle();
      if (!mounted) return;
      setState(() {
        _data = payload;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'empty';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _OverviewShell(child: _LoadingState());
    }

    if (_error != null || _data == null) {
      return const _OverviewShell(child: _EmptyState());
    }

    // PUBLIC HOME METRICS DOCTRINE — dynamic commercial journey.
    //
    // The card set is NOT hardcoded here. The backend's /public/lifecycle
    // registry resolves every eligible commercial stage / retained asset from
    // DB truth and returns only the cards whose value > 0 (ordered by commercial
    // progression). This widget renders exactly that list — so a stage appears
    // automatically when its count moves 0→1 and disappears when it returns to
    // 0, with no code change here. There is no per-card title list and no
    // visibility logic in the frontend.
    final rawCards = (_data!['cards'] as List?) ?? const [];
    final cards = <_FlowCard>[
      for (final entry in rawCards)
        if (entry is Map) _cardFromPayload(Map<String, dynamic>.from(entry)),
    ];

    if (cards.isEmpty) {
      return const _OverviewShell(child: _EmptyState());
    }

    return _OverviewShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive grid via a Wrap with width-computed cells, so it can
          // never overflow horizontally regardless of device width or how many
          // cards the registry currently resolves to non-zero:
          //   >= 720px (desktop/tablet) → max 5 columns → auto-wrap 5 + 5 + 5
          //   >= 420px (mobile wide)    → 2 columns
          //   <  420px (mobile narrow)  → 1 column
          const gap = 12.0;
          final w = constraints.maxWidth;
          final int columns = w >= 720
              ? 5
              : w >= 420
                  ? 2
                  : 1;
          // Floor the cell width so rounding never pushes a row past the
          // available width (prevents a 6th card wrapping onto row 1).
          final double cellWidth =
              ((w - gap * (columns - 1)) / columns).floorToDouble();
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final card in cards)
                SizedBox(width: cellWidth, child: card),
            ],
          );
        },
      ),
    );
  }

  // Map one registry-resolved card payload to a render model. Tone is derived
  // from the metric's kind (STAGE vs retained ASSET) — never from a hardcoded
  // per-card list — so newly registered metrics style themselves automatically.
  _FlowCard _cardFromPayload(Map<String, dynamic> entry) {
    final value = entry['value'];
    final String valueText = value is num
        ? value.toInt().toString()
        : (int.tryParse('$value')?.toString() ?? 'Not available');

    final amount = (entry['amountCents'] ?? 0) as num;
    final String? detail =
        amount > 0 ? _formatCurrency((amount / 100).round()) : null;

    final _FlowTone tone =
        '${entry['kind']}' == 'ASSET' ? _FlowTone.emphasis : _FlowTone.normal;

    return _FlowCard(
      title: '${entry['label'] ?? entry['key'] ?? ''}',
      value: valueText,
      suffix: '${entry['suffix'] ?? ''}',
      detail: detail,
      tone: tone,
    );
  }

  String _formatCurrency(num value) {
    final whole = value.round();
    final text = whole.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final reversedIndex = text.length - i;
      buffer.write(text[i]);
      if (reversedIndex > 1 && reversedIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    return '\$${buffer.toString()}';
  }
}

class _OverviewShell extends StatelessWidget {
  const _OverviewShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: child,
    );
  }
}

enum _FlowTone { normal, emphasis, strong, strongest }

class _FlowCard extends StatelessWidget {
  const _FlowCard({
    required this.title,
    required this.value,
    required this.suffix,
    required this.tone,
    this.detail,
  });

  final String title;
  final String value;
  final String suffix;
  final String? detail;
  final _FlowTone tone;

  @override
  Widget build(BuildContext context) {
    final Color border;
    switch (tone) {
      case _FlowTone.normal:
        border = AppTheme.publicLine;
        break;
      case _FlowTone.emphasis:
        border = AppTheme.publicAccent.withOpacity(0.25);
        break;
      case _FlowTone.strong:
        border = AppTheme.publicAccent.withOpacity(0.35);
        break;
      case _FlowTone.strongest:
        border = AppTheme.publicAccent.withOpacity(0.45);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(suffix,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.publicMuted)),
          if (detail != null && detail!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(detail!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.publicMuted)),
          ],
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          'Live overview is not available at the moment.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.publicMuted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
