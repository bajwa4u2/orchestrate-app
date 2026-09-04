import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/data/repositories/client/client_contact_repository.dart';
import 'package:orchestrate_app/features/client/widgets/contact_readiness_panel.dart';

/// WHETHER WE HAVE A WAY TO REACH THEM, RENDERED AND READ.
///
/// Every one of these states is real in production: 425 messages went to the
/// client's own domain, 435 to publishers who were never prospects, 611 to
/// addresses that permanently failed. The panel exists so a person sees which
/// of those they are looking at before anyone writes to anybody.
///
/// Each case prints what would be read, so the states can be inspected rather
/// than only asserted.
void main() {
  ContactReadiness readiness({
    required ContactReadinessState state,
    required String says,
    required String because,
    ContactCandidate? selected,
    List<ContactCandidate> alternatives = const [],
    bool canProvideContact = true,
  }) =>
      ContactReadiness(
        counterpartyKey: 'trainwell.com',
        state: state,
        says: says,
        because: because,
        selected: selected,
        alternatives: alternatives,
        canProvideContact: canProvideContact,
      );

  ContactCandidate contact({
    String id = 'c1',
    String address = 'dana.reyes@trainwell.com',
    String? name = 'Dana Reyes',
    String? role = 'Head of Sales',
    ContactProvenance provenance = ContactProvenance.clientAuthoritative,
    bool eligible = true,
    String? why,
  }) =>
      ContactCandidate(
        contactId: id,
        address: address,
        personName: name,
        role: role,
        provenance: provenance,
        provenanceSays: switch (provenance) {
          ContactProvenance.clientAuthoritative =>
            'Your business supplied this address. That says where it came from, '
                'not that the mailbox exists.',
          ContactProvenance.externalDiscovery =>
            'A data provider says it observed this address. That is an '
                'observation, not a confirmation.',
          ContactProvenance.inferred =>
            'This address was constructed from a pattern. Nobody observed it, so '
                'it cannot be used until somewhere real supplies it.',
          ContactProvenance.unknown =>
            'There is no record of where this address came from.',
        },
        eligible: eligible,
        why: why,
      );

  Future<void> show(WidgetTester tester, ContactReadiness r) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ContactReadinessPanel(
            counterpartyKey: 'trainwell.com',
            counterpartyName: 'trainwell',
            repository: _Canned(r),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Everything a person would actually read on screen.
  void read(WidgetTester tester, String title) {
    final lines = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .where((s) => s.trim().isNotEmpty);
    debugPrint('\n── $title ──');
    for (final line in lines) {
      debugPrint('  $line');
    }
  }

  testWidgets('no contact is an honest gap, and offers the way to close it',
      (tester) async {
    await show(
      tester,
      readiness(
        state: ContactReadinessState.noContact,
        says: 'Nobody here has an address for them.',
        because: 'A counterparty can be worth pursuing before anyone knows how '
            'to reach them. That is an honest gap, not a defect.',
      ),
    );
    read(tester, 'NO CONTACT');

    expect(find.textContaining('Nobody here has an address'), findsOneWidget);
    expect(find.textContaining('honest gap'), findsOneWidget);
    // Not phrased as an error, and not a dead end.
    expect(find.text('Add a contact you know'), findsOneWidget);
  });

  testWidgets('a usable destination says what it does and does not establish',
      (tester) async {
    await show(
      tester,
      readiness(
        state: ContactReadinessState.ready,
        says: 'There is an address we may use.',
        because: 'Your business supplied this address. That says where it came '
            'from, not that the mailbox exists.',
        selected: contact(),
      ),
    );
    read(tester, 'READY');

    expect(find.textContaining('There is an address we may use'), findsOneWidget);
    // The whole point: source authority is never transport certainty.
    expect(find.textContaining('not that the mailbox exists'), findsOneWidget);
    expect(find.textContaining('Dana Reyes'), findsWidgets);
  });

  testWidgets('a pattern-built address is refused until somewhere real supplies it',
      (tester) async {
    await show(
      tester,
      readiness(
        state: ContactReadinessState.needsStrongerEvidence,
        says: 'The address we have is not supported well enough to use.',
        because: 'This address was constructed from a pattern. Nobody observed '
            'it, so it cannot be used until somewhere real supplies it.',
      ),
    );
    read(tester, 'NEEDS STRONGER EVIDENCE');

    expect(find.textContaining('constructed from a pattern'), findsOneWidget);
    expect(find.text('Add a different contact'), findsOneWidget);
  });

  testWidgets('the business\'s own domain is refused, and still not a dead end',
      (tester) async {
    await show(
      tester,
      readiness(
        state: ContactReadinessState.belongsToYou,
        says: 'The address we have is your own business.',
        because: '"bajwainsurance.com" is your own business domain. Outreach '
            'goes to counterparties, not to yourself.',
      ),
    );
    read(tester, 'BELONGS TO YOU');

    expect(find.textContaining('not to yourself'), findsOneWidget);
    // A suppressed or self-addressed destination refuses one address, not the
    // counterparty. Supplying a different one is the designed path, and the
    // panel used to hide it.
    expect(find.text('Add a different contact'), findsOneWidget);
  });

  testWidgets('a permanently failed address is refused, and a replacement offered',
      (tester) async {
    await show(
      tester,
      readiness(
        state: ContactReadinessState.suppressed,
        says: 'The address we have must not be written to again.',
        because: 'This address failed permanently. Writing to it again would '
            'damage the sending reputation your other mail depends on.',
      ),
    );
    read(tester, 'SUPPRESSED');

    expect(find.textContaining('must not be written to again'), findsOneWidget);
    expect(find.text('Add a different contact'), findsOneWidget);
  });

  testWidgets('two real people means a person chooses, and both are shown',
      (tester) async {
    await show(
      tester,
      readiness(
        state: ContactReadinessState.ambiguous,
        says: 'There is more than one address here and no way to tell which is right.',
        because: 'Choosing between them is a business decision. Guessing would '
            'mean writing to the wrong person.',
        alternatives: [
          contact(id: 'c1', address: 'dana.reyes@trainwell.com', name: 'Dana Reyes'),
          contact(id: 'c2', address: 'sam.okafor@trainwell.com', name: 'Sam Okafor'),
        ],
      ),
    );
    read(tester, 'AMBIGUOUS');

    expect(find.textContaining('Guessing would mean writing to the wrong person'),
        findsOneWidget);
    // Both, so the choice is real. Neither pre-selected.
    expect(find.textContaining('Dana Reyes'), findsOneWidget);
    expect(find.textContaining('Sam Okafor'), findsOneWidget);
  });

  testWidgets('a role mailbox is a legitimate contact and is not given a person\'s name',
      (tester) async {
    await show(
      tester,
      readiness(
        state: ContactReadinessState.ready,
        says: 'There is an address we may use.',
        because: 'Your business supplied this address. That says where it came '
            'from, not that the mailbox exists.',
        selected: contact(address: 'info@trainwell.com', name: null, role: null),
      ),
    );
    read(tester, 'ROLE MAILBOX');

    expect(find.textContaining('info@trainwell.com'), findsOneWidget);
    // `info@` is not a person called Info. Nothing invents one.
    expect(find.textContaining('Info'), findsNothing);
  });

  testWidgets('the add form says what recording an address is, before anyone types',
      (tester) async {
    await show(
      tester,
      readiness(
        state: ContactReadinessState.noContact,
        says: 'Nobody here has an address for them.',
        because: 'A counterparty can be worth pursuing before anyone knows how '
            'to reach them. That is an honest gap, not a defect.',
      ),
    );
    await tester.tap(find.text('Add a contact you know'));
    await tester.pumpAndSettle();
    read(tester, 'ADD A CONTACT');

    expect(find.textContaining('does not confirm the mailbox works'), findsOneWidget);
    expect(find.textContaining('nothing is sent from here'), findsOneWidget);
    // Only the address is required. Asking for a person would invite somebody
    // to invent one.
    expect(find.text('Their name (optional)'), findsOneWidget);
    expect(find.text('How you know this (optional)'), findsOneWidget);
  });

  testWidgets('recording a contact does not make it sendable, and the panel says so',
      (tester) async {
    final canned = _Canned(
      readiness(
        state: ContactReadinessState.noContact,
        says: 'Nobody here has an address for them.',
        because: 'A counterparty can be worth pursuing before anyone knows how '
            'to reach them. That is an honest gap, not a defect.',
      ),
    );
    // What the server answers once the address is on file: recorded, and still
    // refused, because it is the client's own domain.
    canned.next = readiness(
      state: ContactReadinessState.belongsToYou,
      says: 'The address we have is your own business.',
      because: '"bajwainsurance.com" is your own business domain. Outreach goes '
          'to counterparties, not to yourself.',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ContactReadinessPanel(
            counterpartyKey: 'trainwell.com',
            counterpartyName: 'trainwell',
            repository: canned,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a contact you know'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).first, 'owner@bajwainsurance.com');
    await tester.tap(find.text('Record this contact'));
    await tester.pumpAndSettle();
    read(tester, 'RECORDED, AND STILL REFUSED');

    expect(canned.provided, 'owner@bajwainsurance.com');
    // Human entry establishes where an address came from. It never manufactures
    // permission to use it.
    expect(find.textContaining('not to yourself'), findsOneWidget);
  });

  testWidgets('a mail provider is not a company, and nothing here can fix that',
      (tester) async {
    await show(
      tester,
      readiness(
        state: ContactReadinessState.conflicts,
        says: '"gmail.com" is a mail provider, not a company.',
        because: 'An address there belongs to whoever holds the mailbox, so it '
            'is no evidence of belonging to this counterparty. Whoever this is '
            'meant to be needs their own identity before we can say we can '
            'reach them.',
        // Production holds exactly this: a relationship whose counterparty is
        // `gmail.com.`, which read as the single usable destination in the
        // estate until the projection stopped believing it.
        canProvideContact: false,
      ),
    );
    read(tester, 'MAIL PROVIDER AS COUNTERPARTY');

    expect(find.textContaining('not a company'), findsOneWidget);
    // Typing an address would not help. The counterparty is what is wrong.
    expect(find.textContaining('Add a'), findsNothing);
  });

  testWidgets('every state fits, phone through desktop', (tester) async {
    for (final size in const [Size(360, 900), Size(768, 1024), Size(1440, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await show(
        tester,
        readiness(
          state: ContactReadinessState.ambiguous,
          says: 'There is more than one address here and no way to tell which is right.',
          because: 'Choosing between them is a business decision. Guessing '
              'would mean writing to the wrong person.',
          alternatives: [
            contact(id: 'c1', address: 'dana.reyes@trainwell.com', name: 'Dana Reyes'),
            contact(id: 'c2', address: 'sam.okafor@trainwell.com', name: 'Sam Okafor'),
          ],
        ),
      );
      expect(tester.takeException(), isNull,
          reason: 'contact readiness must not overflow at ${size.width}px');
      debugPrint('  ok  ${size.width.toInt()}x${size.height.toInt()} — no overflow');
    }
  });

  testWidgets('a failed check leaves what we know unchanged', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ContactReadinessPanel(
          counterpartyKey: 'trainwell.com',
          counterpartyName: 'trainwell',
          repository: _Broken(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    read(tester, 'UNAVAILABLE');

    expect(find.textContaining('could not check the contact'), findsOneWidget);
    // Not "no contact". An unanswered question is not a negative answer.
    expect(find.textContaining('Nobody here has an address'), findsNothing);
  });
}

/// The server's answers, supplied rather than composed.
class _Canned implements ClientContactRepository {
  _Canned(this.answer);

  ContactReadiness answer;
  ContactReadiness? next;
  String? provided;

  @override
  Future<ContactReadiness> forCounterparty(String counterpartyKey) async => answer;

  @override
  Future<Map<String, dynamic>> provide({
    required String counterpartyKey,
    required String address,
    String? personName,
    String? role,
    String? sourceNote,
  }) async {
    provided = address;
    if (next != null) answer = next!;
    return {'ok': true};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Broken implements ClientContactRepository {
  @override
  Future<ContactReadiness> forCounterparty(String counterpartyKey) async =>
      throw Exception('unreachable');

  @override
  Future<Map<String, dynamic>> provide({
    required String counterpartyKey,
    required String address,
    String? personName,
    String? role,
    String? sourceNote,
  }) async =>
      throw Exception('unreachable');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
