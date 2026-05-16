import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';

class ClientLoadingView extends StatelessWidget {
  const ClientLoadingView({
    super.key,
    this.label = 'Loading workspace data',
    this.eyebrow,
  });

  final String label;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eyebrowText = eyebrow ?? 'Workspace';
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: _panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrowText,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: AppTheme.publicMuted),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                const LinearProgressIndicator(minHeight: 3),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _LoadingPlaceholderBlock(),
          const SizedBox(height: 12),
          const _LoadingPlaceholderBlock(),
        ],
      ),
    );
  }
}

class _LoadingPlaceholderBlock extends StatelessWidget {
  const _LoadingPlaceholderBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
    );
  }
}

class ClientErrorView extends StatelessWidget {
  const ClientErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.title,
  });

  ClientErrorView.fromError(
    Object? error, {
    super.key,
    this.onRetry,
    this.title,
  }) : message = classifyError(error);

  final String message;
  final VoidCallback? onRetry;
  final String? title;

  static String classifyError(Object? error) {
    if (error == null) {
      return 'We could not load this view right now. Please refresh in a moment.';
    }
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host') ||
        text.contains('Network is unreachable')) {
      return 'We could not reach the workspace. Check your network connection and try again.';
    }
    if (text.contains('TimeoutException')) {
      return 'The workspace took too long to respond. We will keep retrying in the background.';
    }
    if (text.contains('401') || text.contains('unauthor')) {
      return 'Your session has ended. Sign in again to refresh the workspace.';
    }
    if (text.contains('403') || text.contains('forbidden')) {
      return 'This area is not available on your current plan. Contact support if you expected access.';
    }
    return 'We could not load this view right now. Please refresh shortly. If it keeps failing, contact support.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: _panelDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? 'This area is temporarily unavailable',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.publicText),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ClientPage extends StatelessWidget {
  const ClientPage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.children,
    this.actions = const [],
    this.banner,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClientHero(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            actions: actions,
          ),
          const SizedBox(height: 18),
          if (banner != null) ...[
            banner!,
            const SizedBox(height: 18),
          ],
          ...children,
        ],
      ),
    );
  }
}

enum ClientBannerTone { success, warning, blocked, info }

class ClientStatusBanner extends StatelessWidget {
  const ClientStatusBanner({
    super.key,
    required this.tone,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final ClientBannerTone tone;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      ClientBannerTone.success => AppTheme.publicAccent,
      ClientBannerTone.warning => AppTheme.amber,
      ClientBannerTone.blocked => Colors.red.shade700,
      ClientBannerTone.info => AppTheme.publicMuted,
    };
    final soft = switch (tone) {
      ClientBannerTone.success => AppTheme.publicAccentSoft,
      ClientBannerTone.warning => AppTheme.publicAmberSoft,
      ClientBannerTone.blocked => Colors.red.shade50,
      ClientBannerTone.info => AppTheme.publicSurfaceSoft,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 7, right: 12),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class ClientHero extends StatelessWidget {
  const ClientHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppTheme.publicMuted)),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ],
      ),
    );
  }
}

class ClientMetricStrip extends StatelessWidget {
  const ClientMetricStrip({super.key, required this.metrics});

  final List<ClientMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 860;
      final tiles = metrics
          .map((metric) => ClientMetricTile(metric: metric))
          .toList(growable: false);
      if (compact) {
        return Column(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i != tiles.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      }
      return Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            Expanded(child: tiles[i]),
            if (i != tiles.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    });
  }
}

class ClientMetric {
  const ClientMetric(this.label, this.value);

  final String label;
  final String value;
}

class ClientMetricTile extends StatelessWidget {
  const ClientMetricTile({super.key, required this.metric});

  final ClientMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric.label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(metric.value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class ClientPanel extends StatelessWidget {
  const ClientPanel({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class ClientEmptyState extends StatelessWidget {
  const ClientEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class ClientInfoRow extends StatelessWidget {
  const ClientInfoRow({
    super.key,
    required this.title,
    required this.primary,
    this.secondary = '',
    this.trailing,
  });

  final String title;
  final String primary;
  final String secondary;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (primary.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(primary, style: Theme.of(context).textTheme.bodyLarge),
                ],
                if (secondary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    secondary,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.publicMuted),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class ClientBadge extends StatelessWidget {
  const ClientBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppTheme.radius),
    border: Border.all(color: AppTheme.publicLine),
  );
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return const <String, dynamic>{};
}

List<dynamic> asList(dynamic value) => value is List ? value : const [];

String readText(Map<String, dynamic> map, String key, {String fallback = ''}) {
  final value = map[key];
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String titleCase(String value) {
  final clean = value.replaceAll('_', ' ').trim().toLowerCase();
  if (clean.isEmpty) return '';
  return clean
      .split(RegExp(r'\s+'))
      .map((part) => part.isEmpty
          ? part
          : '${part.substring(0, 1).toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String dateLabel(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return '';
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return text;
  final local = parsed.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
          ? local.hour - 12
          : local.hour;
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.month}/${local.day}/${local.year} $hour:$minute $suffix';
}

String relativeDateLabel(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return '';
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return text;
  final now = DateTime.now();
  final diff = parsed.toLocal().difference(now);
  final past = diff.isNegative;
  final abs = past ? diff.abs() : diff;
  String unit;
  int amount;
  if (abs.inDays >= 1) {
    amount = abs.inDays;
    unit = amount == 1 ? 'day' : 'days';
  } else if (abs.inHours >= 1) {
    amount = abs.inHours;
    unit = amount == 1 ? 'hour' : 'hours';
  } else {
    amount = abs.inMinutes.clamp(0, 59);
    unit = amount == 1 ? 'minute' : 'minutes';
  }
  if (amount == 0) return 'now';
  return past ? '$amount $unit ago' : 'in $amount $unit';
}

String moneyLabel(dynamic cents, String currency) {
  final amount = cents is num ? cents.toInt() : int.tryParse('$cents') ?? 0;
  return '$currency ${(amount / 100).toStringAsFixed(2)}';
}
