import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/main.dart';

void main() {
  testWidgets('app starts', (tester) async {
    await tester.pumpWidget(const OrchestrateApp());
    expect(find.text('Orchestrate'), findsOneWidget);
  });
}
