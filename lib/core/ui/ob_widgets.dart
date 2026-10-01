import 'package:flutter/material.dart';

import '../theme/ob.dart';

/// The pieces every direction-B screen is built from (DD-26). Kept small and
/// literal so a screen reads like the board it was drawn from.

/// Where a customer stands on the way to being paid. Six parts, always in
/// this order; one is amber when the next move is the owner's yes.
enum PathStep { found, wrote, replied, agree, invoice, paid }

const pathStepLabels = ['Found', 'Wrote', 'Replied', 'Agree', 'Invoice', 'Paid'];

class PathBar extends StatelessWidget {
  const PathBar({
    super.key,
    required this.reached,
    this.waitingOnYes = false,
    this.height = 6,
    this.showLabels = false,
  });

  /// Steps completed. 0 means nothing yet; 6 means paid.
  final int reached;

  /// When true, the step after the last reached one is amber: it is waiting
  /// for the owner's yes.
  final bool waitingOnYes;
  final double height;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    Color colorFor(int i) {
      if (i < reached) return Ob.ink;
      if (i == reached && waitingOnYes) return Ob.yes;
      return Ob.track;
    }

    final bar = Row(
      children: [
        for (var i = 0; i < 6; i++) ...[
          if (i > 0) SizedBox(width: height < 7 ? 4 : 6),
          Expanded(
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: colorFor(i),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ],
      ],
    );
    final semantics = reached >= 6
        ? 'Paid'
        : 'Reached ${pathStepLabels[reached == 0 ? 0 : reached - 1]}'
            '${waitingOnYes ? ', ${pathStepLabels[reached]} waits for your yes' : ''}';
    if (!showLabels) return Semantics(label: semantics, child: bar);
    return Semantics(
      label: semantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    // A phone gets the whole word, smaller, never "Invoic".
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                    pathStepLabels[i],
                    style: Ob.body(13,
                        color: i == reached && waitingOnYes
                            ? Ob.yesDeep
                            : Ob.inkMuted,
                        weight: i == reached && waitingOnYes
                            ? FontWeight.w600
                            : FontWeight.w400),
                  ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A white card on paper. `raised` lifts the one card that leads the row.
class ObCard extends StatelessWidget {
  const ObCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.raised = false,
    this.waitingOnYes = false,
    this.color = Ob.card,
    this.radius = Ob.radiusPanel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool raised;

  /// Outlined in amber: this card is the owner's decision.
  final bool waitingOnYes;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: waitingOnYes ? Border.all(color: Ob.yes, width: 2) : null,
        boxShadow: raised ? Ob.liftHigh : null,
      ),
      child: child,
    );
  }
}

/// A rounded label. `tone` picks the only meanings a pill may carry.
enum PillTone { plain, ink, yes, money, refused }

class ObPill extends StatelessWidget {
  const ObPill(this.text, {super.key, this.tone = PillTone.plain});

  final String text;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.plain => (Ob.paper, Ob.inkSoft),
      PillTone.ink => (Ob.ink, Ob.onInk),
      PillTone.yes => (Ob.yesSoft, Ob.yesInk),
      PillTone.money => (Ob.moneySoft, Ob.moneyInk),
      PillTone.refused => (Ob.refusedSoft, Ob.refused),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Ob.radiusPill),
      ),
      child: Text(text,
          style: Ob.body(12, color: fg, weight: FontWeight.w600)
              .copyWith(height: 1.3)),
    );
  }
}

/// The small amber count beside "Today" in the rail.
class YesCount extends StatelessWidget {
  const YesCount(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count waiting for your yes',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Ob.yes,
          borderRadius: BorderRadius.circular(Ob.radiusPill),
        ),
        child: Text('$count',
            style: Ob.body(12, color: const Color(0xFF1A1206),
                weight: FontWeight.w600)),
      ),
    );
  }
}

/// A page title in the serif, with an optional italic amber ending:
/// "Three things need your *yes.*"
class ObHeadline extends StatelessWidget {
  const ObHeadline(this.text,
      {super.key, this.accent, this.size = 44, this.accentColor = Ob.yesDeep});

  final String text;
  final String? accent;
  final double size;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: text, style: Ob.display(size)),
          if (accent != null)
            TextSpan(
                text: accent,
                style: Ob.displayAccent(size, color: accentColor)),
        ]),
      ),
    );
  }
}

/// A money figure. Green only because it is money.
class MoneyText extends StatelessWidget {
  const MoneyText(this.text, {super.key, this.size = 15, this.onInk = false});
  final String text;
  final double size;
  final bool onInk;

  @override
  Widget build(BuildContext context) => Text(text,
      style: Ob.figure(size, color: onInk ? Ob.moneyOnInk : Ob.money));
}

/// Shield line: the reassurance that nothing moves without the owner.
class ObAssurance extends StatelessWidget {
  const ObAssurance(this.text, {super.key, this.onInk = false});
  final String text;
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.shield_outlined,
              size: 18, color: onInk ? Ob.onInkMuted : Ob.inkSoft),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: Ob.body(14, color: onInk ? Ob.onInkMuted : Ob.inkSoft)),
        ),
      ],
    );
  }
}

/// Primary (ink) and quiet secondary actions, side by side.
class ObActions extends StatelessWidget {
  const ObActions({
    super.key,
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.primaryColor = Ob.ink,
    this.busy = false,
  });

  final String primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  final Color primaryColor;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: primaryColor),
          onPressed: busy ? null : onPrimary,
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Ob.inkMuted))
              : Text(primary),
        ),
        if (secondary != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Ob.inkMuted),
            onPressed: busy ? null : onSecondary,
            child: Text(secondary!),
          ),
      ],
    );
  }
}

/// A removable choice chip in ink, and the dashed "+ add" chip beside it.
class ObChoice extends StatelessWidget {
  const ObChoice(this.label, {super.key, this.onRemove});
  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onRemove != null,
      label: onRemove != null ? 'Remove $label' : label,
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(Ob.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Ob.ink,
            borderRadius: BorderRadius.circular(Ob.radiusPill),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: Ob.body(14, color: Ob.onInk)),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.close, size: 14, color: Ob.onInkMuted),
            ],
          ]),
        ),
      ),
    );
  }
}

class ObAddChoice extends StatelessWidget {
  const ObAddChoice(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Ob.radiusPill),
      child: CustomPaint(
        painter: _DashedPill(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text('+ $label', style: Ob.body(14, color: Ob.inkMuted)),
        ),
      ),
    );
  }
}

class _DashedPill extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCFC8BA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(size.height / 2));
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Label + field + either the server's reason (in red) or a quiet hint.
class ObField extends StatelessWidget {
  const ObField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.onChanged,
    this.placeholder,
    this.autofillHints,
    this.obscure = false,
  });

  /// A password: its characters are hidden.
  final bool obscure;
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? placeholder;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Ob.strong(15)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          maxLines: obscure ? 1 : maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          onChanged: onChanged,
          autofillHints: autofillHints,
          style: Ob.body(16, color: Ob.ink),
          decoration: InputDecoration(
            hintText: placeholder,
            errorText: error,
            counterText: maxLength == null ? null : '',
          ),
        ),
        if (error == null && hint != null) ...[
          const SizedBox(height: 6),
          Text(hint!, style: Ob.body(13, color: Ob.inkMuted)),
        ],
      ],
    );
  }
}
