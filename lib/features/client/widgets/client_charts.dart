import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/theme/app_theme.dart';

/// Visual tone for a single chart datum. Tones are semantic, not
/// decorative — they map a bucket to its operational meaning so a client
/// can read state at a glance (progress vs. attention vs. exclusion).
enum ClientBarTone { primary, neutral, positive, attention, negative }

/// One labelled, DB-backed value in a chart series. [value] is rendered
/// verbatim — charts never fabricate, interpolate, or trend. A series of
/// these is the ONLY input a chart accepts.
class ClientChartDatum {
  const ClientChartDatum(
    this.label,
    this.value, {
    this.tone = ClientBarTone.primary,
    this.hint,
  });

  final String label;
  final int value;
  final ClientBarTone tone;
  final String? hint;
}

/// True when at least one datum carries a positive value. Callers use this
/// to decide between rendering the chart and showing a truthful empty
/// state — a chart is never drawn over an all-zero series.
bool chartHasSignal(Iterable<ClientChartDatum> data) =>
    data.any((d) => d.value > 0);

Color _toneColor(ClientBarTone tone) {
  switch (tone) {
    case ClientBarTone.primary:
      return AppTheme.publicAccent;
    case ClientBarTone.positive:
      return const Color(0xFF1B8A5A);
    case ClientBarTone.attention:
      return AppTheme.coSun;
    case ClientBarTone.negative:
      return const Color(0xFFB42318);
    case ClientBarTone.neutral:
      return AppTheme.publicMuted;
  }
}

/// Horizontal proportional bar chart. Each bar's width is its value
/// relative to the largest value in the series; the printed number is the
/// caller's DB-backed count. Serves both progression/funnel (ordered
/// stages) and distribution (categorical breakdown) use cases.
///
/// Responsive: on wide layouts the label sits left of the bar; on narrow
/// layouts the label stacks above the bar so nothing clips or overflows.
class ClientBarChart extends StatelessWidget {
  const ClientBarChart({
    super.key,
    required this.data,
    this.showValues = true,
  });

  final List<ClientChartDatum> data;
  final bool showValues;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxValue =
        data.fold<int>(0, (m, d) => d.value > m ? d.value : m);
    final denom = maxValue <= 0 ? 1 : maxValue;

    return LayoutBuilder(builder: (context, constraints) {
      final stackLabel = constraints.maxWidth < 420;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < data.length; i++) ...[
            _BarRow(
              datum: data[i],
              fraction: data[i].value / denom,
              showValue: showValues,
              stackLabel: stackLabel,
            ),
            if (i != data.length - 1) const SizedBox(height: 14),
          ],
        ],
      );
    });
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.datum,
    required this.fraction,
    required this.showValue,
    required this.stackLabel,
  });

  final ClientChartDatum datum;
  final double fraction;
  final bool showValue;
  final bool stackLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _toneColor(datum.tone);

    final valueText = Text(
      '${datum.value}',
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );

    final labelText = Text(
      datum.label,
      style: theme.textTheme.bodyMedium,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final track = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 10,
        color: AppTheme.publicSurfaceSoft,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            // Keep a hairline of color visible for any positive value so a
            // small-but-real count never reads as empty; zero stays empty.
            widthFactor: datum.value <= 0
                ? 0.0
                : (fraction.clamp(0.04, 1.0)).toDouble(),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );

    if (stackLabel) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: labelText),
              if (showValue) ...[const SizedBox(width: 8), valueText],
            ],
          ),
          const SizedBox(height: 6),
          track,
          if (datum.hint != null && datum.hint!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(datum.hint!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.publicMuted)),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 168,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              labelText,
              if (datum.hint != null && datum.hint!.isNotEmpty)
                Text(datum.hint!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppTheme.publicMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: track),
        if (showValue) ...[
          const SizedBox(width: 14),
          SizedBox(
            width: 44,
            child: Align(alignment: Alignment.centerRight, child: valueText),
          ),
        ],
      ],
    );
  }
}
