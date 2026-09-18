import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orchestrate_app/features/auth/screens/client_login_screen.dart';

/// Deleting an account used to end on a sign-in screen identical to any
/// ordinary sign-out. The one irreversible act in the account area now says
/// what happened, in the product's actual semantics: erased, not restorable,
/// and the email may start a NEW workspace.
void main() {
  const notice = 'Your account was deleted. Its sign-in and personal details '
      'were erased, and it cannot be restored. You can use the same email to '
      'create a new workspace, which starts from nothing.';

  Future<void> open(WidgetTester tester, String location) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1920, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: location, routes: [
      GoRoute(path: '/auth/login', builder: (_, __) => const ClientLoginScreen()),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('arriving after deletion says so', (tester) async {
    await open(tester, '/auth/login?deleted=1');
    expect(find.text(notice), findsOneWidget);
  });

  testWidgets('an ordinary sign-in says nothing about deletion', (tester) async {
    await open(tester, '/auth/login');
    expect(find.text(notice), findsNothing);
  });
}
