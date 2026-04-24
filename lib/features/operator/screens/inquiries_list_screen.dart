import 'package:flutter/material.dart';

import 'operator_workspace_screen.dart';

class InquiriesListScreen extends StatelessWidget {
  const InquiriesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OperatorWorkspaceScreen(section: OperatorSection.inquiries);
  }
}
