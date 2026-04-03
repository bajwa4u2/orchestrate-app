import 'package:flutter/material.dart';

import '../core/widgets/async_surface.dart';
import '../core/widgets/resource_table.dart';
import '../core/widgets/section_header.dart';
import '../data/models/resource_item.dart';
import '../data/repositories/control_repository.dart';

class CampaignsScreen extends StatelessWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = ControlRepository();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Campaigns', subtitle: ''),
            const SizedBox(height: 24),
            AsyncSurface<List<ResourceItem>>(
              future: repository.fetchCampaigns(),
              builder: (context, items) => ResourceTable(
                title: 'Campaigns',
                subtitle: '',
                items: items ?? const <ResourceItem>[],
                emptyLabel: 'No campaigns.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
