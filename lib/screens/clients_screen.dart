import 'package:flutter/material.dart';

import 'operator_workspace_screen.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OperatorWorkspaceScreen(section: OperatorSection.clients);
  }
}
