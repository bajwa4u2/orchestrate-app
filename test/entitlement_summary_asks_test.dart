import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A SPINNER IS A PROMISE THAT SOMETHING WAS ASKED.
///
/// The capability holder deliberately does not fetch on a session event — that
/// would put a network call wherever the session happens to change. Its
/// contract is the other way round: a surface asks when it builds and finds no
/// answer.
///
/// The entitlement panel rendered the no-answer case and asked nobody. Billing
/// showed a spinner that never resolved unless the person had already opened
/// the account screen, which was the only caller of load() in the product.
void main() {
  final widget =
      File('lib/features/client/widgets/commercial_boundary.dart').readAsStringSync();

  test('the panel asks for the answer it is waiting on', () {
    expect(widget.contains('class _EntitlementSummaryState'), isTrue);
    expect(widget.contains('capabilities.load()'), isTrue);
    // Asked on mount, not only when something else happens to notify.
    final initState = widget.substring(
      widget.indexOf('void initState()'),
      widget.indexOf('void didUpdateWidget'),
    );
    expect(initState.contains('_ask('), isTrue);
  });

  test('a failure does not become a request loop', () {
    // A failed load notifies listeners, which rebuilds the panel. Asking again
    // from the rebuild path would spin requests behind a panel that looks calm.
    expect(widget.contains('afterFailure'), isTrue);
    final state = widget.substring(widget.indexOf('class _EntitlementSummaryState'));
    final build = state.substring(state.indexOf('Widget build(BuildContext context) {'));
    expect(
      build.contains('_ask(afterFailure: true)'),
      isFalse,
      reason: 'the rebuild path must not retry a failure',
    );
  });

  test('an in-flight or answered holder is not asked again', () {
    expect(widget.contains('capabilities.entitlement != null || capabilities.isLoading'),
        isTrue);
  });
}
