// A DAY IS NOT A LIST SORTED BY ONE TIMESTAMP.
//
// Sorting a day by a single date assumes every object's time means the same
// thing, and none of them do. A meeting has a time it is DUE. A delivery has a
// time it HAPPENED. A blocked provider has no time at all — it is simply true
// until somebody fixes it, and giving it a date to be ordered by would be
// inventing one.
//
// The second half of the same problem: Today is a temporal surface, and one
// that leads with last week is not answering the question it exists for.
// Production showed three five-day-old refusals filling the screen under a
// heading that reads as news, while the day itself had nothing in it.
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/data/repositories/client/client_today_repository.dart';

void main() {
  TodayItem item(String title, TodayWhen when, DateTime? at) =>
      TodayItem(title: title, when: when, at: at);

  final now = DateTime.now();

  group('temporal order follows meaning', () {
    test('a standing condition outranks anything with a date', () {
      // It is true right now and nothing about it resolves by waiting.
      final ordered = orderForToday([
        item('happened an hour ago', TodayWhen.happened,
            now.subtract(const Duration(hours: 1))),
        item('due in ten minutes', TodayWhen.due,
            now.add(const Duration(minutes: 10))),
        item('sending is blocked', TodayWhen.standing, null),
      ]);

      expect(ordered.first.title, 'sending is blocked');
    });

    test('what is due comes before what already happened', () {
      final ordered = orderForToday([
        item('happened', TodayWhen.happened, now.subtract(const Duration(minutes: 5))),
        item('due', TodayWhen.due, now.add(const Duration(hours: 6))),
      ]);

      expect(ordered.map((i) => i.title), ['due', 'happened']);
    });

    test('due items run soonest first, the order a day is lived', () {
      final ordered = orderForToday([
        item('later', TodayWhen.due, now.add(const Duration(hours: 5))),
        item('sooner', TodayWhen.due, now.add(const Duration(hours: 1))),
      ]);

      expect(ordered.map((i) => i.title), ['sooner', 'later']);
    });

    test('things that happened run most recent first', () {
      // The opposite direction, and for the opposite reason: the newest thing
      // that happened is the one still worth reading.
      final ordered = orderForToday([
        item('older', TodayWhen.happened, now.subtract(const Duration(days: 2))),
        item('newer', TodayWhen.happened, now.subtract(const Duration(hours: 2))),
      ]);

      expect(ordered.map((i) => i.title), ['newer', 'older']);
    });

    test('an item with no time is not ranked against ones that have one', () {
      // Inventing a timestamp so a standing condition can be sorted is exactly
      // the mistake this replaced.
      final ordered = orderForToday([
        item('dated', TodayWhen.due, now.add(const Duration(hours: 1))),
        item('undated', TodayWhen.due, null),
      ]);

      expect(ordered.first.title, 'dated');
      expect(ordered.last.title, 'undated');
    });
  });

  group('recency', () {
    TodayState stateWith(List<Map<String, dynamic>> replies) => TodayState(
          alerts: const [],
          workflow: const {},
          eligibility: const {},
          recentMessages: const [],
          replies: replies,
        );

    Map<String, dynamic> reply(DateTime at) => {
          'fromEmail': 'someone@counterparty.com',
          'intent': 'INTERESTED',
          'receivedAt': at.toIso8601String(),
        };

    test('something from this morning is change', () {
      final s = stateWith([reply(now.subtract(const Duration(hours: 3)))]);
      expect(s.changed, isNotEmpty);
      expect(s.changedButNotRecently, isFalse);
    });

    test('something from last week is not change', () {
      // Real, and not news. It stays on the relationship it belongs to.
      final s = stateWith([reply(now.subtract(const Duration(days: 5)))]);
      expect(s.changed, isEmpty);
      expect(
        s.changedButNotRecently,
        isTrue,
        reason: 'the surface has to tell a quiet stretch apart from an empty '
            'record, because they render identically otherwise',
      );
    });

    test('a genuinely empty record is not a quiet stretch', () {
      final s = stateWith(const []);
      expect(s.changed, isEmpty);
      expect(s.changedButNotRecently, isFalse);
    });

    test('the window reaches back over a weekend', () {
      // Four days rather than one: a business does not work every day, and a
      // Monday should still show what happened on Friday.
      final s = stateWith([reply(now.subtract(const Duration(days: 3)))]);
      expect(s.changed, isNotEmpty);
    });
  });

  group('partial failure stays legible', () {
    test('a source that did not answer is named, and the rest still stands', () {
      const s = TodayState(
        alerts: [],
        workflow: {},
        eligibility: {},
        recentMessages: [],
        replies: [],
        unavailable: {'meetings'},
      );

      expect(s.incompleteBecause, contains('meetings'));
      expect(s.incompleteBecause, contains('not the whole picture'));
    });

    test('several missing sources read as a sentence', () {
      const s = TodayState(
        alerts: [],
        workflow: {},
        eligibility: {},
        recentMessages: [],
        replies: [],
        unavailable: {'meetings', 'replies'},
      );

      expect(s.incompleteBecause, contains(' and '));
    });

    test('nothing missing says nothing', () {
      const s = TodayState(
        alerts: [],
        workflow: {},
        eligibility: {},
        recentMessages: [],
        replies: [],
      );
      expect(s.incompleteBecause, isNull);
    });
  });
}
