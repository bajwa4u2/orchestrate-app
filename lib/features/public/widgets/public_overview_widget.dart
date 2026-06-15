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

    // DB-backed commercial-lifecycle funnel (platform-wide). Every value
    // is a live count from /public/lifecycle — never hard-coded. A field
    // absent from the payload renders as "Not available" (truthful
    // degradation); a real 0 renders as "0".
    String n(String key) {
      final v = _data![key];
      if (v == null) return 'Not available';
      if (v is num) return v.toInt().toString();
      return int.tryParse('$v')?.toString() ?? 'Not available';
    }

    final invoiceAmount = (_data!['invoicesIssuedAmountCents'] ?? 0) as num;
    final paymentAmount = (_data!['paymentsClearedAmountCents'] ?? 0) as num;

    // Public funnel = the connected, single-unit client-execution lifecycle
    // only (leads → … → payments). Upstream acquisition counters ("Raw
    // Results") and discovery entities are intentionally not shown here:
    // they are a different unit with no row-lineage into this funnel and
    // would imply current-client pipeline they are not.
    final cards = [
      _FlowCard(
        title: 'Leads',
        value: n('leads'),
        suffix: 'created',
        tone: _FlowTone.normal,
      ),
      _FlowCard(
        title: 'Suppressed',
        value: n('suppressed'),
        suffix: 'governed exclusions',
        tone: _FlowTone.normal,
      ),
      _FlowCard(
        title: 'Opportunities',
        value: n('opportunities'),
        suffix: 'qualified',
        tone: _FlowTone.normal,
      ),
      _FlowCard(
        title: 'Dispatch',
        value: n('dispatch'),
        suffix: 'governed sends',
        tone: _FlowTone.normal,
      ),
      _FlowCard(
        title: 'Replies',
        value: n('replies'),
        suffix: 'classified',
        tone: _FlowTone.normal,
      ),
      _FlowCard(
        title: 'Meetings',
        value: n('meetings'),
        suffix: 'handed off',
        tone: _FlowTone.emphasis,
      ),
      _FlowCard(
        title: 'Invoices',
        value: n('invoices'),
        suffix: 'issued',
        detail: invoiceAmount > 0
            ? '${_formatCurrency((invoiceAmount / 100).round())} issued'
            : null,
        tone: _FlowTone.strong,
      ),
      _FlowCard(
        title: 'Payments',
        value: n('payments'),
        suffix: 'cleared',
        detail: paymentAmount > 0
            ? '${_formatCurrency((paymentAmount / 100).round())} cleared'
            : null,
        tone: _FlowTone.strongest,
      ),
    ];

    return _OverviewShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive grid via a Wrap with width-computed cells, so it
          // can never overflow horizontally regardless of device width:
          //   >= 720px (desktop/tablet) → 5 columns → 10 cards = 5 + 5
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
