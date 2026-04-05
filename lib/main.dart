import 'package:flutter/material.dart';

import 'core/auth/auth_session.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthSessionController.instance.init();
  runApp(const OrchestrateApp());
}

class OrchestrateApp extends StatelessWidget {
  const OrchestrateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Orchestrate',
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
