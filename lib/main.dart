import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/auth/auth_session.dart';
import 'app/routing/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
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
