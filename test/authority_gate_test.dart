import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/authority/client_authority.dart';
import 'package:orchestrate_app/core/ui/authority_gate.dart';

/// THE POINT OF ACTION, RENDERED.
///
/// An act is offered, withheld with a reason, or withheld because we could not
/// tell — and the three must be visibly different. These render each one and
/// read what the control actually says.
void main() {
  Future<void> render(
    WidgetTester tester,
    String name, {
    required Consequence consequence,
    PerformedBy by = PerformedBy.human,
    required VoidCallback onProceed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthorityGate(
            consequence: consequence,
            by: by,
            label: 'Sign the agreement',
            onProceed: onProceed,
          ),
        ),
      ),
    );
    await tester.pump();
    final read = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText())
        .whereType<String>()
        .where((t) => t.trim().isNotEmpty);
    debugPrint('\n──── $name ────');
    for (final line in read) {
      debugPrint('  $line');
    }
  }

  tearDown(() => ClientAuthority.instance.seedActions(null));

  testWidgets('permitted — the act is offered, and says what it does', (tester) async {
    ClientAuthority.instance.seedActions({
      'CONTRACTUAL:HUMAN': const ActionAuthority(
        permitted: true,
        consequence: 'CONTRACTUAL',
        requiresLabel: 'Agreements',
        refusal: null,
      ),
    });
    var pressed = false;
    await render(tester, 'permitted',
        consequence: Consequence.contractual, onProceed: () => pressed = true);

    // Consequence is visible before the click, not confirmed after it.
    expect(find.text('Commits the business'), findsOneWidget);
    await tester.tap(find.text('Sign the agreement'));
    expect(pressed, isTrue);
  });

  testWidgets('refused — the reason and the way out are both shown', (tester) async {
    ClientAuthority.instance.seedActions({
      'CONTRACTUAL:HUMAN': const ActionAuthority(
        permitted: false,
        consequence: 'CONTRACTUAL',
        requiresLabel: 'Agreements',
        refusal: AuthorityRefusal(
          code: 'ORGANIZATION_AUTHORITY_NOT_ESTABLISHED',
          why: 'Northwind Freight LLC has not yet named anyone who may make '
              'agreements decisions.',
          resolution: 'Name an authorised person in Account → People & '
              'authority. Orchestrate reviews what your business sends before '
              'it takes effect.',
        ),
      ),
    });
    var pressed = false;
    await render(tester, 'refused',
        consequence: Consequence.contractual, onProceed: () => pressed = true);

    // Not a silent grey button: what is needed, why, and what resolves it.
    expect(find.textContaining('Needs agreements authority'), findsOneWidget);
    expect(find.textContaining('has not yet named anyone'), findsOneWidget);
    expect(find.textContaining('Name an authorised person'), findsOneWidget);
    // The code is present so a support conversation can start from it.
    expect(find.text('ORGANIZATION_AUTHORITY_NOT_ESTABLISHED'), findsOneWidget);

    await tester.tap(find.text('Sign the agreement'));
    expect(pressed, isFalse, reason: 'a refused act must not be reachable');
  });

  testWidgets('the same act by Orchestrate is its own question', (tester) async {
    ClientAuthority.instance.seedActions({
      'CONTRACTUAL:HUMAN': const ActionAuthority(
        permitted: true, consequence: 'CONTRACTUAL',
        requiresLabel: 'Agreements', refusal: null,
      ),
      'CONTRACTUAL:ORCHESTRATE': const ActionAuthority(
        permitted: false,
        consequence: 'CONTRACTUAL',
        requiresLabel: 'Agreements',
        refusal: AuthorityRefusal(
          code: 'ORCHESTRATE_SCOPE_NOT_DELEGATED',
          why: 'Orchestrate may communicate on your behalf, which does not '
              'cover agreements.',
          resolution: 'Someone recognised for this area can widen what '
              'Orchestrate may do.',
        ),
      ),
    });
    await render(tester, 'by Orchestrate',
        consequence: Consequence.contractual,
        by: PerformedBy.orchestrate,
        onProceed: () {});

    // The person may sign it themselves; the software still may not.
    expect(find.textContaining('does not cover agreements'), findsOneWidget);
    expect(find.text('ORCHESTRATE_SCOPE_NOT_DELEGATED'), findsOneWidget);
  });

  testWidgets('unknown is not permitted', (tester) async {
    // Nothing seeded: the real call runs, and in a test binding every request
    // fails — which is exactly the state being rendered.
    var pressed = false;
    await render(tester, 'could not check',
        consequence: Consequence.financial, onProceed: () => pressed = true);
    await tester.pumpAndSettle();

    expect(find.textContaining('could not check whether you may do this'),
        findsOneWidget);
    await tester.tap(find.text('Sign the agreement'));
    expect(pressed, isFalse,
        reason: 'an act whose authority could not be read is withheld, not assumed');
  });

  testWidgets('internal work is offered quietly, with no consequence note',
      (tester) async {
    ClientAuthority.instance.seedActions({
      'REVERSIBLE_INTERNAL:HUMAN': const ActionAuthority(
        permitted: true,
        consequence: 'REVERSIBLE_INTERNAL',
        requiresLabel: null,
        refusal: null,
      ),
    });
    await render(tester, 'internal work',
        consequence: Consequence.reversibleInternal, onProceed: () {});

    // Labelling everything means nobody reads the labels that matter.
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Commits the business'), findsNothing);
  });
}
