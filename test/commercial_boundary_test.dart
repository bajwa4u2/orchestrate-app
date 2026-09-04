import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/commercial/client_capabilities.dart';
import 'package:orchestrate_app/features/client/widgets/commercial_boundary.dart';

/// FOUR REASONS ORCHESTRATE SAYS NO, AND ONLY ONE IS SOLVED BY PAYING.
///
///   PLAN_ACTIVATION_REQUIRED   the service is not commercially active
///   ACTOR_UNAUTHORIZED         nobody holds the authority to do this
///   DESTINATION_NOT_READY      the recipient boundary refused
///   EXECUTION_HELD             the rails are held
///
/// Collapsing them into "upgrade your plan" would sell a business a
/// subscription that cannot fix its problem, and would teach people that
/// Orchestrate's governance is a paywall wearing a suit.
///
/// Each case prints what would be read, so the states can be inspected rather
/// than only asserted.
void main() {
  CapabilityProjection projection({
    required EntitlementState state,
    required EntitlementSource source,
    required String says,
    required String because,
    bool operating = false,
  }) =>
      CapabilityProjection(
        entitlement: Entitlement(
          state: state,
          source: source,
          says: says,
          because: because,
          isPayingCustomer: source == EntitlementSource.paid,
        ),
        capabilities: [
          for (final c in [
            Capabilities.readOwnRecords,
            Capabilities.configureBusiness,
            Capabilities.manageAccount,
            Capabilities.export,
          ])
            CapabilityVerdict(
                capability: c, permitted: true, code: null, why: null, resolution: null),
          CapabilityVerdict(
            capability: Capabilities.operateCommercially,
            permitted: operating,
            code: operating ? null : 'PLAN_ACTIVATION_REQUIRED',
            why: operating
                ? null
                : state == EntitlementState.lapsed
                    ? 'Your plan has lapsed. Everything your business built is '
                        'still here and still readable; starting new work needs '
                        'an active plan.'
                    : 'Ongoing operation needs an active plan. Your workspace, '
                        'your setup and anything already recorded stay exactly '
                        'as they are.',
            resolution: operating ? null : 'Activate from Plan & billing in your account.',
          ),
        ],
        model: const [
          (
            dimension: 'PLATFORM_SUBSCRIPTION',
            means: 'A subscription for your organisation, priced primarily at '
                'the level of the business rather than per seat.'
          ),
        ],
        note: 'Activating a plan makes capability available. It never authorises '
            'anyone to act on your behalf — who may do that stays yours to decide.',
      );

  Future<void> show(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ));
    await tester.pump();
  }

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

  tearDown(() => ClientCapabilities.instance.seed(null));

  testWidgets('a new organisation is told what activation turns on, not to upgrade',
      (tester) async {
    ClientCapabilities.instance.seed(projection(
      state: EntitlementState.none,
      source: EntitlementSource.none,
      says: 'Your workspace is set up. Activating Orchestrate turns on ongoing operation.',
      because: 'Nothing has been activated for this organisation yet.',
    ));
    await show(tester,
        const CommercialBoundary(capability: Capabilities.operateCommercially));
    read(tester, 'NO PLAN');

    expect(find.text('This needs an active plan'), findsOneWidget);
    // The reassurance matters: nothing they have is at risk.
    expect(find.textContaining('stay exactly as they are'), findsOneWidget);
    expect(find.text('Plan & billing'), findsOneWidget);
    // Never the word that turns governance into a sales funnel.
    expect(find.textContaining('Upgrade'), findsNothing);
  });

  testWidgets('a lapsed organisation is told its work is still there',
      (tester) async {
    ClientCapabilities.instance.seed(projection(
      state: EntitlementState.lapsed,
      source: EntitlementSource.none,
      says: 'Everything your business built here is still yours to read.',
      because: 'The subscription ended.',
    ));
    await show(tester,
        const CommercialBoundary(capability: Capabilities.operateCommercially));
    read(tester, 'LAPSED');

    expect(find.text('Your plan has lapsed'), findsOneWidget);
    // The distinction that matters: lapsed is not the same as never activated.
    expect(find.textContaining('still here and still readable'), findsOneWidget);
  });

  testWidgets('an operating organisation sees no boundary at all', (tester) async {
    ClientCapabilities.instance.seed(projection(
      state: EntitlementState.active,
      source: EntitlementSource.paid,
      says: 'Orchestrate is active for your organisation.',
      because: 'The subscription is current.',
      operating: true,
    ));
    await show(tester,
        const CommercialBoundary(capability: Capabilities.operateCommercially));

    // No banner, no nudge, no upgrade card. A paying customer should not be
    // sold to inside the product they already bought.
    expect(find.byType(Text), findsNothing);
    debugPrint('  ok  nothing rendered for an active organisation');
  });

  testWidgets('what is never gated stays never gated', (tester) async {
    ClientCapabilities.instance.seed(projection(
      state: EntitlementState.none,
      source: EntitlementSource.none,
      says: 'Your workspace is set up.',
      because: 'Nothing has been activated yet.',
    ));

    for (final unconditional in [
      Capabilities.readOwnRecords,
      Capabilities.configureBusiness,
      Capabilities.manageAccount,
      Capabilities.export,
    ]) {
      await show(tester, CommercialBoundary(capability: unconditional));
      expect(find.byType(Text), findsNothing,
          reason: '$unconditional must never show a commercial boundary — a '
              "business's own records are not ours to withhold");
    }
    debugPrint('  ok  records, setup, account and export are never gated');
  });

  testWidgets('a granted organisation is not presented as a customer',
      (tester) async {
    ClientCapabilities.instance.seed(projection(
      state: EntitlementState.active,
      source: EntitlementSource.internal,
      says: 'Internal operational access.',
      because: 'Access was granted directly rather than purchased, so it does '
          'not depend on a billing period.',
      operating: true,
    ));
    await show(tester, const EntitlementSummary());
    read(tester, 'INTERNAL GRANT');

    expect(find.textContaining('granted directly rather than purchased'),
        findsOneWidget);
    // The nature of the access is named. Two of Orchestrate's four granted
    // organisations are its own products and one belongs to a Strategic
    // Member; none of them bought anything.
    expect(find.text('Internal operational access'), findsWidgets);
    expect(ClientCapabilities.instance.entitlement!.isPayingCustomer, isFalse);
  });

  testWidgets('Plan & billing shows the model and never a price', (tester) async {
    ClientCapabilities.instance.seed(projection(
      state: EntitlementState.none,
      source: EntitlementSource.none,
      says: 'Your workspace is set up. Activating Orchestrate turns on ongoing operation.',
      because: 'Nothing has been activated for this organisation yet.',
    ));
    await show(tester, const EntitlementSummary());
    read(tester, 'PLAN & BILLING');

    expect(find.textContaining('priced primarily at the level of the business'),
        findsOneWidget);
    // The sentence that must survive every future edit.
    expect(find.textContaining('never authorises anyone to act on your behalf'),
        findsOneWidget);
    // No amount, and no plan cards to choose between.
    final everything = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(RegExp(r'\$\d').hasMatch(everything), isFalse,
        reason: 'no dollar figure is approved, so none may be shown');
  });

  testWidgets('the boundary fits, phone through desktop', (tester) async {
    ClientCapabilities.instance.seed(projection(
      state: EntitlementState.lapsed,
      source: EntitlementSource.none,
      says: 'Everything your business built here is still yours to read.',
      because: 'The subscription ended.',
    ));

    for (final size in const [Size(360, 900), Size(768, 1024), Size(1440, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await show(tester,
          const CommercialBoundary(capability: Capabilities.operateCommercially));
      expect(tester.takeException(), isNull,
          reason: 'the commercial boundary must not overflow at ${size.width}px');
      debugPrint('  ok  ${size.width.toInt()}x${size.height.toInt()} — no overflow');
    }
  });
}
