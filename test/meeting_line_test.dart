// ONE LINE, FOUR THINGS TO SAY.
//
// A meeting has to say when it was due, whether it actually happened and when,
// what state it is in, and whether anything can be done about it. The record
// used to hold one timestamp and had to make it mean all of those, so a meeting
// due at one o'clock and held at ten showed the schedule and called it history.
//
// Real production case: three certification meetings scheduled three hours
// ahead and genuinely held within minutes of being created, with durations of
// four, seven and fifty-one minutes. "Held" and "due" were both true and
// different. A surface that can only say one of them is choosing which truth to
// discard.
import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/relationships/client_relationships.dart';
import 'package:orchestrate_app/features/client/widgets/meeting_line.dart';

void main() {
  RelationshipMeeting meeting({
    String status = 'COMPLETED',
    String handoffStage = 'CONFIRMED_BY_PROVIDER',
    DateTime? due,
    DateTime? held,
    DateTime? ended,
  }) =>
      RelationshipMeeting(
        id: 'm1',
        title: 'Introductory call',
        status: status,
        handoffStage: handoffStage,
        scheduledAt: due,
        startedAt: held,
        completedAt: ended,
        entrance: null,
      );

  // Anchored to today so the phrasing is exercised, not the calendar.
  DateTime at(int hour, int minute) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, hour, minute);
  }

  test('a meeting held far from its schedule says both', () {
    // The production case. Due at 13:16, held at 10:17, ran seven minutes.
    final line = meetingLine(meeting(
      due: at(13, 16),
      held: at(10, 17),
      ended: at(10, 23),
    ));

    expect(line, contains('Held 10:17'));
    expect(line, contains('was due 13:16'));
    expect(line, contains('ran 6 min'));
  });

  test('a meeting held close to its schedule does not quote the schedule', () {
    // Repeating the plan for a meeting that started on time is noise dressed
    // as precision.
    final line = meetingLine(meeting(
      due: at(13, 0),
      held: at(13, 4),
      ended: at(13, 30),
    ));

    expect(line, contains('Held 13:04'));
    expect(line, isNot(contains('was due')));
  });

  test('a long meeting reads in hours', () {
    final line = meetingLine(meeting(
      due: at(11, 27),
      held: at(8, 42),
      ended: at(9, 33),
    ));
    expect(line, contains('ran 51 min'));

    final longer = meetingLine(meeting(
      due: at(9, 0),
      held: at(9, 0),
      ended: at(11, 30),
    ));
    expect(longer, contains('ran 2h 30m'));
  });

  // ── States that are not "it happened" ────────────────────────────────

  test('a cancelled meeting never claims to have been held', () {
    final line = meetingLine(meeting(status: 'CANCELED', due: at(7, 29)));
    expect(line, startsWith('Cancelled'));
    expect(line, contains('was due 07:29'));
    expect(line, isNot(contains('Held')));
  });

  test('a no-show says nobody attended rather than reporting a duration', () {
    final line = meetingLine(meeting(status: 'NO_SHOW', due: at(9, 0)));
    expect(line, contains('Nobody attended'));
  });

  test('a meeting nobody was invited to leads with that', () {
    // Nothing else about it matters until it is fixed.
    final line = meetingLine(meeting(
      status: 'PROPOSED',
      handoffStage: 'NEVER_REACHED_PROVIDER',
      due: at(15, 0),
    ));
    expect(line, contains('Never created with the meeting provider'));
    expect(line, contains('nobody was invited'));
  });

  test('completed with no record of starting says exactly that', () {
    // The honest rendering of a contradiction, rather than inventing a start
    // time or hiding the completion.
    final line = meetingLine(meeting(status: 'COMPLETED', due: at(11, 0)));
    expect(line, contains('no record of it starting'));
    expect(line, contains('was due 11:00'));
  });

  // ── Still ahead ──────────────────────────────────────────────────────

  test('an upcoming meeting leads with when it is due', () {
    final soon = DateTime.now().add(const Duration(hours: 2));
    final line = meetingLine(meeting(status: 'BOOKED', due: soon));
    expect(line, startsWith('Due '));
  });

  test('a meeting past its time with no occurrence says so plainly', () {
    // Not "held", and not silence. The time passed and nothing is recorded.
    final line = meetingLine(meeting(
      status: 'BOOKED',
      due: DateTime.now().subtract(const Duration(hours: 2)),
    ));
    expect(line, contains('Was due'));
    expect(line, contains('no record it took place'));
  });

  test('a meeting with no time at all does not invent one', () {
    expect(meetingLine(meeting(status: 'PROPOSED')), 'No time set yet');
  });

  // ── The domain predicate the phrasing rests on ───────────────────────

  test('held away from schedule is measured, not guessed', () {
    final onTime = meeting(due: at(13, 0), held: at(13, 10));
    final early = meeting(due: at(13, 0), held: at(10, 0));

    expect(onTime.heldAwayFromSchedule, isFalse);
    expect(early.heldAwayFromSchedule, isTrue);
    expect(early.wasHeld, isTrue);
    expect(meeting(due: at(13, 0)).wasHeld, isFalse);
  });
}
