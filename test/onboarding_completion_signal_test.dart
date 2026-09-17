// THE PRODUCT HAS TO BE ABLE TO SAY "YOU ARE FINISHED".
//
// Readiness used to be expressed only as the disappearance of a row. A business
// that had completed every step and a business that had done nothing both read
// "Nothing needs you right now", so absence carried two opposite meanings and
// the interface never marked the transition between them.
//
// These tests hold the two properties that make the completion signal worth
// having: it comes from the one readiness authority, and it stays silent when
// that authority did not answer. A signal that is sometimes wrong is worse than
// one that is sometimes absent — a business told it can send when it cannot
// will find out from a counterparty.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrate_app/data/repositories/client/client_today_repository.dart';

TodayState state({
  Map<String, dynamic> eligibility = const {},
  Set<String> unavailable = const {},
}) {
  return TodayState(
    alerts: const [],
    workflow: const {},
    eligibility: eligibility,
    recentMessages: const [],
    replies: const [],
    unavailable: unavailable,
  );
}

void main() {
  group('the completion signal reads the readiness authority', () {
    test('the three buckets that mean the preparation is done', () {
      // ready_to_execute is dispatch eligibility granted. The other two are
      // reachable only through it, so a business in either has finished.
      for (final bucket in <String>[
        'ready_to_execute',
        'orchestrate_working',
        'executing',
      ]) {
        expect(state(eligibility: {'bucket': bucket}).executionReady, isTrue,
            reason: '$bucket means setup is behind them');
      }
    });

    test('a bucket that names outstanding work is not readiness', () {
      for (final bucket in <String>[
        'client_action_required',
        'recovering',
        'degraded',
        'orchestrate_blocked_internal',
      ]) {
        expect(state(eligibility: {'bucket': bucket}).executionReady, isFalse,
            reason: '$bucket must never be reported as finished');
      }
    });

    test('a bucket this build does not know is not readiness', () {
      // The backend can add a bucket. Unknown must fall to "do not claim",
      // never to a default of ready.
      expect(state(eligibility: {'bucket': 'some_future_bucket'}).executionReady,
          isFalse);
    });
  });

  group('silence rather than a guess', () {
    test('eligibility unavailable says nothing either way', () {
      // Null, not false. False would tell a business that had finished that it
      // had not, which is the same defect in the other direction.
      expect(
        state(unavailable: {'eligibility'}).executionReady,
        isNull,
        reason: 'a source that did not answer is not evidence of anything',
      );
    });

    test('an answer with no bucket says nothing either way', () {
      expect(state(eligibility: const {}).executionReady, isNull);
      expect(state(eligibility: {'bucket': ''}).executionReady, isNull);
      expect(state(eligibility: {'bucket': 42}).executionReady, isNull);
    });

    test('Today renders the completion state only on a true answer', () {
      final source =
          File('lib/features/client/screens/today_screen.dart').readAsStringSync();
      expect(source.contains('s.executionReady == true'), isTrue,
          reason: 'null and false must both fall through to the quiet state; '
              'a bare truthiness check would report an unknown as ready');
      expect(source.contains("message: 'Your setup is complete.'"), isTrue,
          reason: 'the product must say the thing, not imply it by absence');
    });
  });

  group('setup has one canonical route', () {
    late final String router =
        File('lib/app/routing/app_router.dart').readAsStringSync();

    test('/client/setup renders and /app/setup redirects to it', () {
      final canonical = router.indexOf("path: '/client/setup'");
      expect(canonical, greaterThan(-1));
      expect(
        router.substring(canonical, canonical + 200).contains('uilder:'),
        isTrue,
        reason: '/client/setup is the surface and must render',
      );

      final legacy = router.indexOf("path: '/app/setup'");
      expect(legacy, greaterThan(-1),
          reason: 'old links and deep links must still resolve');
      final next = router.indexOf('GoRoute(', legacy);
      final decl = router.substring(legacy, next == -1 ? legacy + 200 : next);
      expect(decl.contains("=> '/client/setup'"), isTrue,
          reason: '/app/setup is the second name, not a second screen');
    });

    test('nothing sends anybody to the second name', () {
      for (final file in <String>[
        'lib/features/auth/screens/client_login_screen.dart',
        'lib/features/client/screens/today_screen.dart',
      ]) {
        expect(File(file).readAsStringSync().contains("'/app/setup'"), isFalse,
            reason: '$file must use the canonical /client/setup');
      }
    });
  });

  group('setup ends in the workspace, not at a price', () {
    test('saving setup does not route to checkout', () {
      // The router treats subscription as not a door; sequencing a plan screen
      // immediately after setup taught the opposite of what the product does.
      final source = File('lib/features/client/screens/client_setup_screen.dart')
          .readAsStringSync();
      expect(source.contains("context.go('/app/subscribe')"), isFalse,
          reason: 'entitlement refuses an action, never a place');
      expect(source.contains("context.go('/client/today')"), isTrue,
          reason: 'finishing setup arrives at the workspace');
    });
  });
}
