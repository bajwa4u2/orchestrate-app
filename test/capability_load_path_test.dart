import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/commercial/client_capabilities.dart';
import 'package:orchestrate_app/data/repositories/client/client_capability_repository.dart';
import 'package:orchestrate_app/features/client/widgets/commercial_boundary.dart';

/// THE PATH BETWEEN A SUCCESSFUL FETCH AND A PAINTED FRAME.
///
/// Plan & billing sat on a spinner in production while the request behind it
/// returned 200 with a correct payload. Three fixes were shipped on three
/// different theories and the spinner survived all of them, because every test
/// covering this surface seeded the projection directly — the defect lives
/// precisely in the stretch that seeding skips.
///
/// So this drives the real `load()` through a fake repository, mounted in a
/// widget shaped exactly like the screen: a listener, an ask from `build`, and
/// the summary reading the singleton.
void main() {
  const live = r'''
{"entitlement":{"organizationId":"org","clientId":"client","state":"ACTIVE","source":"STORE_REVIEW","says":"App-store review access.","because":"Access was granted directly rather than purchased, so it does not depend on a billing period.","isPayingCustomer":false,"executionActivated":false},"capabilities":[{"capability":"READ_OWN_RECORDS","permitted":true,"code":null,"why":null,"resolution":null},{"capability":"OPERATE_COMMERCIALLY","permitted":true,"code":null,"why":null,"resolution":null}],"model":[{"dimension":"PLATFORM_SUBSCRIPTION","means":"A subscription for your organisation, priced primarily at the level of the business rather than per seat."}],"note":"Activating a plan makes capability available. It never authorises anyone to act on your behalf."}
''';

  setUp(() {
    ClientCapabilities.instance.seed(null);
    ClientCapabilities.instance.useRepository(_FakeRepository(live));
  });

  testWidgets('the answer reaches the screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: _Screen())));

    // No assertion about the first frame: how quickly the answer arrives is a
    // property of the fake, not of the product. What matters is where it ends
    // up.
    await tester.pump();

    // Bounded pumps rather than pumpAndSettle: a CircularProgressIndicator
    // animates forever, so settling never returns while the defect is present
    // and the failure reads as a timeout instead of as the real state.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'a spinner that outlives a successful fetch is the defect');
    // Twice, legitimately: the panel says it, and the footnote names the
    // source. A grant is labelled as a grant rather than shown as a plan.
    expect(find.textContaining('App-store review access'), findsWidgets);
    expect(find.textContaining('granted directly rather than purchased'),
        findsOneWidget);
    expect(ClientCapabilities.instance.entitlement, isNotNull);
  });

  testWidgets('a failure is shown, and is not another spinner', (tester) async {
    ClientCapabilities.instance.useRepository(_BrokenRepository());
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: _Screen())));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    tester.takeException();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('could not read your plan'), findsOneWidget);
  });
}

/// Shaped like `_PlanAndBilling`: listens, asks from build when it has no
/// answer, and renders the summary that reads the singleton.
class _Screen extends StatefulWidget {
  const _Screen();

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  final ClientCapabilities _capabilities = ClientCapabilities.instance;

  @override
  void initState() {
    super.initState();
    _capabilities.addListener(_onChanged);
    _askIfUnanswered();
  }

  @override
  void dispose() {
    _capabilities.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _askIfUnanswered() {
    if (_capabilities.hasAnswer ||
        _capabilities.isLoading ||
        _capabilities.error != null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_capabilities.hasAnswer ||
          _capabilities.isLoading ||
          _capabilities.error != null) {
        return;
      }
      _capabilities.load().then((_) {}, onError: (Object _) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    _askIfUnanswered();
    return const SingleChildScrollView(child: EntitlementSummary());
  }
}

class _FakeRepository implements ClientCapabilityRepository {
  _FakeRepository(this.body);
  final String body;

  @override
  Future<CapabilityProjection> fetch() async =>
      CapabilityProjection.fromJson(Map<String, dynamic>.from(jsonDecode(body) as Map));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BrokenRepository implements ClientCapabilityRepository {
  @override
  Future<CapabilityProjection> fetch() async => throw Exception('unreachable');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
