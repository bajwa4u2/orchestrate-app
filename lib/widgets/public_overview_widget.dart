
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class PublicOverviewWidget extends StatefulWidget {
  const PublicOverviewWidget({super.key});

  @override
  State<PublicOverviewWidget> createState() => _PublicOverviewWidgetState();
}

class _PublicOverviewWidgetState extends State<PublicOverviewWidget> {
  static const String _apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000/v1');

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

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
      final response = await _dio.get('/public/overview');
      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        setState(() {
          _data = payload;
          _loading = false;
        });
        return;
      }

      setState(() {
        _error = 'invalid';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'empty';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _OverviewShell(
        child: _LoadingState(),
      );
    }

    if (_error != null || _data == null) {
      return const _OverviewShell(
        child: _EmptyState(),
      );
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
    final borderColor = switch (tone) {
      _FlowTone.normal => AppTheme.publicLine,
      _FlowTone.emphasis => AppTheme.publicLine,
      _FlowTone.strong => AppTheme.publicAccent.withValues(alpha: 0.20),
      _FlowTone.strongest => AppTheme.publicAccent.withValues(alpha: 0.28),
    };

    final background = switch (tone) {
      _FlowTone.normal => AppTheme.publicBackground,
      _FlowTone.emphasis => AppTheme.publicBackground,
      _FlowTone.strong => AppTheme.publicAccentSoft,
      _FlowTone.strongest => AppTheme.publicAccentSoft,
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 156),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.publicText,
                ),
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
              children: [
                TextSpan(
                  text: value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.publicText,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                ),
                TextSpan(text: ' $suffix'),
              ],
            ),
          ),
          const Spacer(),
          if (detail != null)
            Text(
              detail!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 10),
          child: Container(
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.publicBackground,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No active operations yet',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          'This system reflects real outreach, meetings, billing, and revenue. Once active, this view updates automatically.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.publicMuted,
              ),
        ),
      ],
    );
  }
}
