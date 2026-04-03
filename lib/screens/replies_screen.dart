import 'package:flutter/material.dart';

import '../core/widgets/async_surface.dart';
import '../core/widgets/resource_table.dart';
import '../core/widgets/section_header.dart';
import '../data/models/resource_item.dart';
import '../data/repositories/control_repository.dart';

class RepliesScreen extends StatelessWidget {
  const RepliesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = ControlRepository();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Replies', subtitle: ''),
            const SizedBox(height: 24),
            AsyncSurface<List<ResourceItem>>(
              future: repository.fetchReplies(),
              builder: (context, items) => ResourceTable(
                title: 'Replies',
                subtitle: '',
                items: items ?? const <ResourceItem>[],
                emptyLabel: 'No replies.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
