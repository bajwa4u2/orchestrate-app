import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../data/repositories/operator_repository.dart';

class InquiriesListScreen extends StatelessWidget {
  const InquiriesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: OperatorRepository().fetchInquiries(limit: 40),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final payload = snapshot.data ?? const <String, dynamic>{};
        final items = (payload['items'] as List? ?? const []).cast<dynamic>();

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Inquiries', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  Text('Inbound intake, current standing, and what still needs handling.', style: Theme.of(context).textTheme.bodyMedium),
                ]),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _MetricCard(label: 'Total', value: '${items.length}')),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard(label: 'Open', value: '${items.where((item) => _read(item, 'status') != 'CLOSED').length}')),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard(label: 'Closed', value: '${items.where((item) => _read(item, 'status') == 'CLOSED').length}')),
              ]),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.line)),
                child: items.isEmpty
                    ? Text('No inquiries are available right now.', style: Theme.of(context).textTheme.bodyMedium)
                    : Column(
                        children: [
                          for (int i = 0; i < items.length; i++) ...[
                            _InquiryRow(item: items[i]),
                            if (i != items.length - 1) const Divider(height: 22, color: AppTheme.line),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
      ]),
    );
  }
}

class _InquiryRow extends StatelessWidget {
  const _InquiryRow({required this.item});
  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final id = _read(item, 'id');
    return InkWell(
      onTap: id.isEmpty ? null : () => context.go('/app/inquiries/$id'),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_read(item, 'name', fallback: 'Inquiry'), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(_read(item, 'message'), maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text([
                  _read(item, 'email'),
                  _read(item, 'company'),
                  _read(item, 'type'),
                ].where((value) => value.isNotEmpty).join(' · '), style: Theme.of(context).textTheme.bodyMedium),
              ]),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppTheme.panelRaised, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.line)),
              child: Text(_read(item, 'status', fallback: 'NEW'), style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
      ),
    );
  }
}

String _read(dynamic source, String key, {String fallback = ''}) {
  if (source is! Map) return fallback;
  final value = source[key];
  if (value == null) return fallback;
  return value.toString();
}
