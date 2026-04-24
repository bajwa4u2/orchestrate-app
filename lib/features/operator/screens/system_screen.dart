import 'package:flutter/material.dart';

import 'operator_workspace_screen.dart';

class SystemScreen extends StatelessWidget {
  const SystemScreen(
      {super.key,
      this.title = 'System',
      this.subtitle = 'Operational posture, configuration, and readiness.'});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return const OperatorWorkspaceScreen(section: OperatorSection.settings);
  }
}
