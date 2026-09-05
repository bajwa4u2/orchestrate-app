import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show BrowserContextMenu;
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/auth/auth_session.dart';
import 'app/routing/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  // SELECTABLE TEXT MUST NOT COST US SCROLLING.
  //
  // `SelectionArea` wraps both shells so an operator can copy an address or an
  // id out of a case. On web, while the browser's own context menu is enabled,
  // Flutter lays a real `<div>` over the whole selectable region to host that
  // menu — `Positioned.fill`, `pointer-events: auto`, above the canvas. It
  // swallows the wheel, and the workspace silently stops scrolling: the Work
  // Queue showed three of twenty-seven cases and would not move.
  //
  // Handing the context menu to Flutter removes the div. Selection and copy
  // still work, through Flutter's own toolbar, which is what the rest of the
  // product already looks like.
  if (kIsWeb) {
    await BrowserContextMenu.disableContextMenu();
  }
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
