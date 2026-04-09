import 'package:flutter/material.dart';

class SupportFooter extends StatelessWidget {
  final bool showStripe;

  const SupportFooter({
    super.key,
    this.showStripe = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Powered by OpenAI', style: style),
          if (showStripe) const SizedBox(height: 4),
          if (showStripe) Text('Powered by Stripe', style: style),
        ],
      ),
    );
  }
}
