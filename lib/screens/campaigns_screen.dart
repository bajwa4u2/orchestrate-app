import 'package:flutter/material.dart';

import 'operator_workspace_screen.dart';

class CampaignsScreen extends StatelessWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OperatorWorkspaceScreen(section: OperatorSection.campaigns);
  }
}
