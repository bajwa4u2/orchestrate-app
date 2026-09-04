import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/attention/client_attention.dart';
import 'package:orchestrate_app/features/client/screens/attention_screen.dart';

/// THE INBOUND STATES, RENDERED AND READ.
///
/// Twenty-seven real messages sat where the client could not see them. Making
/// them visible is only half the fix — a list that shows operator work as
/// though the client must fix it, or buries the two items that are genuinely
/// theirs under twenty-five that are not, has replaced one defect with another.
///
/// Each case prints what a person would read, so the states can be inspected
/// rather than only asserted.
void main() {
  AttentionItem item({
    String id = 'q1',
    String title = 'The Hartford Billing Status Alert',
    AttentionOwner owner = AttentionOwner.client,
    AttentionState state = AttentionState.open,
    String why = 'This arrived in your mailbox and matched no message '
        'Orchestrate sent, so we cannot say who it belongs to.',
    String? counterparty = 'Alerts@agent.thehartford.com',
    String? relationshipId,
    List<AttentionAction> actions = const [
      AttentionAction.reviewMessage,
      AttentionAction.markReviewed,
      AttentionAction.associateWithRelationship,
      AttentionAction.escalateToOperator,
      AttentionAction.dismiss,
      AttentionAction.viewProvenance,
    ],
    String? counterpartyKey,
    String? resolvedBy,
  }) =>
      AttentionItem(
        id: id,
        kind: 'CLASSIFICATION_REQUIRED',
        owner: owner,
        severity: owner == AttentionOwner.client ? 'WARNING' : 'INFO',
        state: state,
        title: title,
        why: why,
        occurredAt: DateTime.now(),
        counterparty: counterparty,
        relationshipId: relationshipId,
        actions: actions,
        counterpartyKey: counterpartyKey,
        resolvedBy: resolvedBy,
      );

  AttentionView view(List<AttentionItem> items) => AttentionView(
        items: items,
        counts: {
          for (final o in AttentionOwner.values)
            o: items
                .where((i) => i.owner == o && i.state != AttentionState.resolved)
                .length,
        },
        note: 'This arrived in mailboxes belonging to your business.',
      );

  Future<void> render(WidgetTester tester, String name) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AttentionScreen())),
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

  tearDown(() => ClientAttention.instance.seed(null));

  testWidgets('1. healthy — nothing arrived we could not place', (tester) async {
    ClientAttention.instance.seed(view(const []));
    await render(tester, 'healthy');

    expect(find.textContaining('Nothing is waiting on you'), findsOneWidget);
    // A healthy state says so. An empty list a person has to interpret is not
    // an answer.
    expect(find.text('NEEDS YOU'), findsNothing);
  });

  testWidgets('2. client-owned mail appears under Needs you', (tester) async {
    ClientAttention.instance.seed(view([item()]));
    await render(tester, 'client-owned');

    expect(find.text('NEEDS YOU'), findsOneWidget);
    expect(find.text('The Hartford Billing Status Alert'), findsOneWidget);
    // The backend's own sentence, verbatim.
    expect(find.textContaining('matched no message'), findsOneWidget);
    expect(find.textContaining('Alerts@agent.thehartford.com'), findsOneWidget);
  });

  testWidgets('3. operator work is visible and honestly not theirs',
      (tester) async {
    ClientAttention.instance.seed(view([
      item(
        id: 'q2',
        title: 'Verify your email',
        owner: AttentionOwner.operator,
        counterparty: 'no-reply@orchestrateops.com',
        why: "This is Orchestrate's own correspondence arriving in a mailbox we "
            'poll. Settling it is ours to do, not yours.',
        actions: const [AttentionAction.viewProvenance],
      ),
    ]));
    await render(tester, 'operator-owned');

    // Shown — hiding a business's own mail is the defect. Not demanded of them.
    expect(find.text('WITH ORCHESTRATE'), findsOneWidget);
    expect(find.textContaining('ours to do, not yours'), findsOneWidget);
    expect(find.text('NEEDS YOU'), findsNothing);
    expect(find.textContaining('Nothing here needs a decision from you'),
        findsOneWidget);
    // Never conveyed by colour alone.
    expect(find.textContaining('with Orchestrate'), findsOneWidget);
  });

  testWidgets('4. the two are separated, not summed into a count',
      (tester) async {
    ClientAttention.instance.seed(view([
      item(id: 'a'),
      item(id: 'b', title: 'Iffat, we should likely talk!'),
      item(id: 'c', title: 'Verify your email', owner: AttentionOwner.operator),
      item(id: 'd', title: 'IA Evolve Conference', owner: AttentionOwner.operator),
      item(id: 'e', title: 'Labor Day hours', owner: AttentionOwner.none),
    ]));
    await render(tester, 'mixed ownership');

    expect(find.text('NEEDS YOU'), findsOneWidget);
    expect(find.text('WITH ORCHESTRATE'), findsOneWidget);
    // The product leads with what needs you and why, never with "you have 5".
    expect(find.textContaining('5 '), findsNothing);
    expect(find.text('The Hartford Billing Status Alert'), findsOneWidget);
    expect(find.text('Iffat, we should likely talk!'), findsOneWidget);
  });

  testWidgets('5. settled work leaves Needs you and stays in history',
      (tester) async {
    ClientAttention.instance.seed(view([
      item(id: 'open'),
      item(
        id: 'done',
        title: 'Happy Labor Day!',
        state: AttentionState.resolved,
        resolvedBy: 'CLIENT',
        actions: const [AttentionAction.viewProvenance],
      ),
    ]));
    await render(tester, 'settled');

    // Out of the way.
    expect(find.text('Happy Labor Day!'), findsNothing);
    // Not gone. Resolution removes work owed; it does not erase what happened.
    expect(find.textContaining('Show 1 already dealt with'), findsOneWidget);

    await tester.tap(find.textContaining('Show 1 already dealt with'));
    await tester.pump();
    expect(find.text('Happy Labor Day!'), findsOneWidget);
    expect(find.text('DEALT WITH'), findsOneWidget);
  });

  testWidgets('6. escalated work is with Orchestrate, not vanished',
      (tester) async {
    ClientAttention.instance.seed(view([
      item(id: 'esc', state: AttentionState.inReview),
    ]));
    await render(tester, 'escalated');

    // An item handed on must not disappear while nobody is looking.
    expect(find.text('WITH ORCHESTRATE'), findsOneWidget);
    expect(find.text('The Hartford Billing Status Alert'), findsOneWidget);
    expect(find.textContaining('Show'), findsNothing);
  });

  testWidgets('7. the list could not be read — nothing is assumed',
      (tester) async {
    ClientAttention.instance.seed(null, error: StateError('network'));
    await render(tester, 'unavailable');

    expect(find.textContaining('could not load what is waiting'), findsOneWidget);
    // Says what did NOT happen, which is the part a person actually worries
    // about when a screen about their mail fails to load.
    expect(find.textContaining('Your mail is where it was'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('8. every state fits, phone through desktop', (tester) async {
    ClientAttention.instance.seed(view([
      item(),
      item(id: 'b', title: 'Iffat, we should likely talk!'),
      item(id: 'c', title: 'Verify your email', owner: AttentionOwner.operator),
    ]));

    for (final size in const [
      Size(360, 900), // phone
      Size(768, 1024), // tablet
      Size(1440, 900), // desktop
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AttentionScreen())),
      );
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'inbound must render without overflow at ${size.width}px');
      expect(find.text('NEEDS YOU'), findsOneWidget);
      debugPrint('  ok  ${size.width.toInt()}x${size.height.toInt()} — no overflow');
    }
  });

  // ── D3: WORK THAT IS NOT MAIL ────────────────────────────────────────────
  //
  // Attention stopped being an inbound-only list when a counterparty a business
  // chose to pursue, and cannot reach, became a real thing waiting on them.

  AttentionItem contactWork({
    String counterparty = 'trainwell',
    String counterpartyKey = 'trainwell.com',
    String? relationshipId,
  }) =>
      AttentionItem(
        id: 'pursuit-1',
        kind: 'COMMERCIAL_ACTION',
        owner: AttentionOwner.client,
        severity: 'WARNING',
        state: AttentionState.open,
        title: 'You chose to pursue $counterparty',
        why: 'Nobody here has an address for them. A counterparty can be worth '
            'pursuing before anyone knows how to reach them. That is an honest '
            'gap, not a defect.',
        occurredAt: DateTime.now(),
        counterparty: counterparty,
        relationshipId: relationshipId,
        actions: relationshipId != null
            ? const [AttentionAction.openRelationship, AttentionAction.openCounterparty]
            : const [AttentionAction.openCounterparty],
        counterpartyKey: counterpartyKey,
        resolvedBy: null,
      );

  testWidgets('10. a pursued counterparty with no contact is work owed',
      (tester) async {
    ClientAttention.instance.seed(view([contactWork()]));
    await render(tester, 'contact work owed');

    expect(find.text('NEEDS YOU'), findsOneWidget);
    // Said as the decision the business already made, not as a system error.
    expect(find.text('You chose to pursue trainwell'), findsOneWidget);
    expect(find.textContaining('honest gap'), findsOneWidget);
    // The readiness projection's own sentence, quoted rather than restated.
    expect(find.textContaining('Nobody here has an address for them'),
        findsOneWidget);
  });

  testWidgets('11. contact work carries no message actions', (tester) async {
    final work = contactWork();
    // It is not mail: there is nothing to read, nothing to place on a
    // relationship, and nothing to escalate. Offering any of those would be a
    // button that means something else.
    expect(work.actions.contains(AttentionAction.reviewMessage), isFalse);
    expect(work.actions.contains(AttentionAction.associateWithRelationship), isFalse);
    expect(work.actions.contains(AttentionAction.markReviewed), isFalse);
    expect(work.actions, contains(AttentionAction.openCounterparty));
    debugPrint('  ok  contact work offers only the way to the counterparty');
  });

  testWidgets('9. summaries are semantically readable', (tester) async {
    ClientAttention.instance.seed(view([item()]));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AttentionScreen())),
    );
    await tester.pump();

    // Visible-on-canvas is not enough — Chapter A shipped two defects that
    // were exactly that. Sender, subject and who owes the work must all be
    // reachable as text, not implied by layout or colour.
    final semantics = tester.getSemantics(find.text(
      'The Hartford Billing Status Alert',
    ));
    expect(semantics.label, contains('Hartford'));
    expect(find.textContaining('Alerts@agent.thehartford.com'), findsOneWidget);
  });
}
