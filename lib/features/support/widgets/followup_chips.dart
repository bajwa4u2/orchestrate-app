import 'package:flutter/material.dart';

class FollowUpChips extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onTap;

  const FollowUpChips({
    super.key,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => ActionChip(
              label: Text(item),
              onPressed: () => onTap(item),
            ),
          )
          .toList(),
    );
  }
}
