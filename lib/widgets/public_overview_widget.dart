import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/repositories/public_repository.dart';

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
      final payload = await _repository.fetchOverview();
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

    final leadsActive = (_data!['leadsActive'] ?? 0) as num;
    final outreachSent = (_data!['outreachSent'] ?? 0) as num;
    final repliesReceived = (_data!['repliesReceived'] ?? 0) as num;
    final meetingsScheduled = (_data!['meetingsScheduled'] ?? 0) as num;
    final invoicesIssuedAmount = (_data!['invoicesIssuedAmount'] ?? 0) as num;
    final paymentsClearedAmount = (_data!['paymentsClearedAmount'] ?? 0) as num;
    final paymentsDueAmount = (_data!['paymentsDueAmount'] ?? 0) as num;

    final cards = [
      _FlowCard(
        title: 'Leads',
        value: leadsActive.toString(),
        suffix: 'active',
        tone: _FlowTone.normal,
      ),
      _FlowCard(
        title: 'Outreach',
        value: outreachSent.toString(),
        suffix: 'sent',
        tone: _FlowTone.normal,
      ),
      _FlowCard(
        title: 'Replies',
        value: repliesReceived.toString(),
        suffix: 'received',
        tone: _FlowTone.normal,
      ),
      _FlowCard(
        title: 'Meetings',
        value: meetingsScheduled.toString(),
        suffix: 'scheduled',
        detail: 'Current pipeline',
        tone: _FlowTone.emphasis,
      ),
      _FlowCard(
        title: 'Invoices',
        value: _formatCurrency(invoicesIssuedAmount),
        suffix: 'issued',
        detail: paymentsDueAmount > 0 ? '${_formatCurrency(paymentsDueAmount)} due' : 'Issued inside the same flow',
        tone: _FlowTone.strong,
      ),
      _FlowCard(
        title: 'Payments',
        value: _formatCurrency(paymentsClearedAmount),
        suffix: 'cleared',
        detail: paymentsDueAmount > 0 ? '${_formatCurrency(paymentsDueAmount)} open' : 'Settlement carried forward',
        tone: _FlowTone.strongest,
      ),
    ];

    return _OverviewShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1120) {
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < 4; i++) ...[
                      Expanded(child: cards[i]),
                      if (i != 3) const SizedBox(width: 12),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[4]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[5]),
                    const Spacer(flex: 2),
                  ],
                ),
              ],
            );
          }

          if (constraints.maxWidth >= 720) {
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: card,
                  ),
              ],
            );
          }

          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 12),
              ],
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
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(suffix, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted)),
          if (detail != null && detail!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(detail!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.publicMuted)),
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
          'Live overview is not available right now.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
