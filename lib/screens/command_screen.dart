import 'package:flutter/material.dart';

import 'operator_workspace_screen.dart';

class CommandScreen extends StatelessWidget {
  const CommandScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OperatorWorkspaceScreen(section: OperatorSection.command);
  }
}
