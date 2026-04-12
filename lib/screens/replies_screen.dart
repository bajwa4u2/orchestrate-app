import 'package:flutter/material.dart';

import 'operator_workspace_screen.dart';

class RepliesScreen extends StatelessWidget {
  const RepliesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OperatorWorkspaceScreen(section: OperatorSection.replies);
  }
}
