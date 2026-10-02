import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orchestrate_app/core/theme/ob.dart';
import 'package:orchestrate_app/data/repositories/public/visitor_assistant_repository.dart';
import 'package:orchestrate_app/features/public/widgets/visitor_assistant.dart';

/// THE VISITOR ASSISTANT (2 Oct 2026): a visitor asks, gets an answer with at
/// most two next steps, and can hand the question to a person with their
/// name and email.
class _FakeRepo extends VisitorAssistantRepository {
  final asked = <String>[];
  final handed = <Map<String, Object?>>[];
  bool offerPerson = false;

  @override
  Future<List<String>> starters() async => ['What does it cost?', 'Is it for my kind of business?'];

  @override
  Future<VisitorAnswer> ask(String message, List<VisitorTurn> history, {String? page}) async {
    asked.add(message);
    return VisitorAnswer(
      id: 'v${asked.length}',
      answer: 'Monthly plan, \$29.99 a month. Setting up costs nothing.',
      places: const [VisitorPlace(key: 'start', label: 'Create your workspace', route: '/auth/register')],
      question: null,
      offerPerson: offerPerson,
    );
  }

  @override
  Future<String> handoff({
    required String name,
    required String email,
    String? company,
    required String message,
    required List<VisitorTurn> conversation,
    required List<String> answerIds,
    String? page,
  }) async {
    handed.add({'name': name, 'email': email, 'message': message, 'turns': conversation.length, 'ids': answerIds, 'page': page});
    return 'Thank you. A person will reply to your email within one business day.';
  }
}

Future<void> _show(WidgetTester tester, _FakeRepo repo) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(
        body: SingleChildScrollView(child: VisitorAssistant(page: '/contact', repository: repo)),
      ),
    ),
    GoRoute(path: '/auth/register', builder: (_, __) => const Scaffold(body: Text('REGISTER'))),
  ]);
  await tester.pumpWidget(MaterialApp.router(theme: Ob.theme(), routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a starter asks, and the answer offers its next step', (tester) async {
    final repo = _FakeRepo();
    await _show(tester, repo);
    expect(find.text('ASK BEFORE YOU START'), findsOneWidget);
    await tester.tap(find.text('What does it cost?'));
    await tester.pumpAndSettle();
    expect(repo.asked, ['What does it cost?']);
    expect(find.textContaining('\$29.99'), findsOneWidget);
    await tester.tap(find.text('Create your workspace'));
    await tester.pumpAndSettle();
    expect(find.text('REGISTER'), findsOneWidget);
  });

  testWidgets('to a person: name and a real email are asked for, then it is sent with the conversation',
      (tester) async {
    final repo = _FakeRepo()..offerPerson = true;
    await _show(tester, repo);
    await tester.enterText(find.byType(TextField).first, 'Can you call me about my roofing company?');
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    // Unsure answers open the person form on their own.
    expect(find.text('Send it to a person'), findsOneWidget);

    await tester.tap(find.text('Send to a person'));
    await tester.pumpAndSettle();
    expect(find.textContaining('an email address the reply can reach'), findsOneWidget);
    expect(repo.handed, isEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Dana Reyes');
    await tester.enterText(find.widgetWithText(TextField, 'Your email'), 'dana@roofs.example');
    await tester.tap(find.text('Send to a person'));
    await tester.pumpAndSettle();
    expect(repo.handed.single['message'], 'Can you call me about my roofing company?');
    expect(repo.handed.single['turns'], 2);
    expect(repo.handed.single['ids'], ['v1']);
    expect(repo.handed.single['page'], '/contact');
    expect(find.textContaining('within one business day'), findsWidgets);
  });

  testWidgets('fits a phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeRepo()..offerPerson = true;
    await tester.pumpWidget(MaterialApp(
      theme: Ob.theme(),
      home: Scaffold(body: SingleChildScrollView(child: VisitorAssistant(page: '/', repository: repo))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Talk to a person'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
