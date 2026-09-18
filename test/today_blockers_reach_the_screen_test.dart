// THREE BLOCKERS, AND TODAY SAID "NOTHING NEEDS YOU RIGHT NOW."
//
// Observed on a live account on 2026-09-17. The workspace had no
// representation authorization, no plan and no sending mailbox;
// /client/execution-eligibility returned 200 with three blockers, each with a
// label, a detail, an owner and a resolution route — and Today rendered the
// empty state.
//
// The cause was a field-name mismatch. `ResolvableBlocker` is
// `{code, label, detail, owner, resolutionRoute, resolutionCta}`. Today read
// `reason`, `message` and `title`, so `reason` was always null and the guard
// `if (reason == null) continue;` discarded every blocker that has ever
// existed.
//
// It is the worst shape a defect can take on this screen: not a wrong answer,
// a confident wrong answer, on the one surface whose entire promise is that
// what needs you is on it.
import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/data/repositories/client/client_today_repository.dart';

TodayState withBlockers(List<Map<String, dynamic>> blockers) {
  return TodayState(
    alerts: const [],
    workflow: const {},
    eligibility: {'bucket': 'client_action_required', 'blockers': blockers},
    recentMessages: const [],
    replies: const [],
  );
}

void main() {
  group('the blockers the backend actually sends', () {
    test('the three from the live account all reach the screen', () {
      // Copied from the real 200 response, field for field.
      final state = withBlockers([
        {
          'code': 'AUTHORIZATION_MISSING',
          'label': 'Authorization required',
          'detail': 'Representation authorization is required before outbound '
              'outreach can send.',
          'owner': 'client',
          'resolutionRoute': '/client/representation',
          'resolutionCta': 'Authorize representation',
        },
        {
          'code': 'PLAN_ACTIVATION_REQUIRED',
          'label': 'Readiness blocker',
          'detail': 'Ongoing operation needs an active plan.',
          'owner': 'client',
          'resolutionRoute': '/client/operations',
          'resolutionCta': 'View operations',
        },
        {
          'code': 'MAILBOX_MISSING',
          'label': 'Mailbox missing',
          'detail': 'No sending mailbox of yours is connected yet.',
          'owner': 'client',
          'resolutionRoute': '/client/mailbox',
          'resolutionCta': 'Connect a mailbox',
        },
      ]);

      final titles = state.needsYou.map((i) => i.title).toList();
      expect(titles, contains('Authorization required'));
      expect(titles, contains('Readiness blocker'));
      expect(titles, contains('Mailbox missing'));
      expect(state.needsYou.length, 3,
          reason: 'three blockers in, three items out');

      final mailbox =
          state.needsYou.firstWhere((i) => i.title == 'Mailbox missing');
      expect(mailbox.detail, contains('No sending mailbox'),
          reason: 'the detail is what tells them what to do');
    });

    test('an older payload using reason or message still renders', () {
      final state = withBlockers([
        {'title': 'Sending is held', 'reason': 'An older shape.'},
        {'message': 'The degraded envelope uses message.'},
      ]);
      expect(state.needsYou.length, 2);
      expect(state.needsYou.first.detail, 'An older shape.');
    });

    test('a blocker with a label but no detail is still named', () {
      // Dropping it would repeat the original defect in miniature.
      final state = withBlockers([
        {'code': 'X', 'label': 'Something is held'},
      ]);
      expect(state.needsYou.length, 1);
      expect(state.needsYou.single.title, 'Something is held');
    });

    test('a blocker that says nothing at all is the only one skipped', () {
      final state = withBlockers([
        {'code': 'X', 'owner': 'client'},
      ]);
      expect(state.needsYou, isEmpty);
    });

    test('an internal fault is not shown raw to a client', () {
      final state = withBlockers([
        {
          'label': 'Readiness blocker',
          'detail': 'Error: Exception at /app/dist/src/workers/first_send.js:268',
        },
      ]);
      expect(state.needsYou.single.detail, contains('a fault on our side'));
      expect(state.needsYou.single.detail, isNot(contains('/app/dist')));
    });
  });

  group('the guard that caused it', () {
    test('an empty blocker list still yields nothing', () {
      expect(withBlockers(const []).needsYou, isEmpty);
    });
  });
}
