import 'package:flutter/material.dart';
import 'package:orchestrate_app/features/operator/screens/audit_timeline_screen.dart';

/// Audit History — wraps the existing AuditTimelineScreen.
///
/// Demoted from primary nav into System · Audit history. The underlying
/// widget is unchanged — this screen just hosts it under the new shell.
class OpsHistoryScreen extends StatelessWidget {
  const OpsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuditTimelineScreen();
  }
}
