import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/async_surface.dart';
import '../data/repositories/operator_repository.dart';

class InquiriesListScreen extends StatelessWidget {
  const InquiriesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = OperatorRepository();

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      child: AsyncSurface<Map<String, dynamic>>(
        future: repository.fetchInquiries(limit: 100),
        builder: (context, data) {
          final response = data ?? const <String, dynamic>{};
          final rawItems = (response['items'] as List?) ?? const [];

          final items = rawItems
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inquiries',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Incoming work requiring attention, response, and resolution.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.slate,
                    ),
              ),
              const SizedBox(height: 24),

              // MAIN SURFACE
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: items.isEmpty
                    ? const _EmptyState()
                    : Column(
                        children: [
                          for (int i = 0; i < items.length; i++) ...[
                            _InquiryRow(item: items[i]),
                            if (i != items.length - 1)
                              const Divider(height: 1, color: AppTheme.border),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No inquiries',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'New contact intake and replies will appear here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.slate,
                ),
          ),
        ],
      ),
    );
  }
}

class _InquiryRow extends StatelessWidget {
  const _InquiryRow({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final id = _string(item['id']);
    final name = _string(item['name'], fallback: 'Unknown');
    final company = _string(item['company']);
    final type = _string(item['type'], fallback: 'General');
    final status = _string(item['status'], fallback: 'RECEIVED');
    final email = _string(item['email']);
    final preview = _string(item['message'], fallback: 'No message provided.');
    final createdAt = _string(item['createdAt']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: id.isEmpty ? null : () => context.go('/app/inquiries/$id'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        _StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (company.isNotEmpty) company,
                        if (email.isNotEmpty) email,
                        type
                      ].join('  ·  '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.slate,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _formatDate(createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.slate,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();

    final background = switch (normalized) {
      'RECEIVED' => const Color(0xFFFFF4DB),
      'NOTIFIED' => const Color(0xFFEFF4FF),
      'ACKNOWLEDGED' => const Color(0xFFE8F8F0),
      'CLOSED' => const Color(0xFFF3F4F6),
      'SPAM' => const Color(0xFFFDECEC),
      _ => const Color(0xFFF3F4F6),
    };

    final foreground = switch (normalized) {
      'RECEIVED' => const Color(0xFF8A5A00),
      'NOTIFIED' => const Color(0xFF1D4ED8),
      'ACKNOWLEDGED' => const Color(0xFF0F766E),
      'CLOSED' => const Color(0xFF4B5563),
      'SPAM' => const Color(0xFF991B1B),
      _ => const Color(0xFF4B5563),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized.replaceAll('_', ' '),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

String _string(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _formatDate(String raw) {
  if (raw.isEmpty) return '';
  final parsed = DateTime.tryParse(raw)?.toLocal();
  if (parsed == null) return raw;

  final month = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][parsed.month - 1];

  final hour = parsed.hour == 0
      ? 12
      : (parsed.hour > 12 ? parsed.hour - 12 : parsed.hour);

  final minute = parsed.minute.toString().padLeft(2, '0');
  final meridiem = parsed.hour >= 12 ? 'PM' : 'AM';

  return '$month ${parsed.day}, $hour:$minute $meridiem';
}