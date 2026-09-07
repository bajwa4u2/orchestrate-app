/// HOW A MEETING READS IN A COMMERCIAL RECORD.
///
/// A meeting has at least four separate things to say and only one line to say
/// them in: when it was due, whether it actually happened and when, what state
/// it is in now, and whether there is anything to do about it. The product used
/// to have one timestamp and had to make it mean all of them, so a meeting due
/// at one o'clock and held at ten showed the schedule and called it history.
///
/// That is not hypothetical here. Three certification meetings were scheduled
/// three hours ahead and genuinely held within minutes of being created, with
/// real durations. "Held" and "due" were both true and different, and a surface
/// that can only say one of them is choosing which truth to discard.
///
/// The rule these follow: say what happened first, and say what was planned
/// only when it differs enough to matter. A meeting that ran four minutes late
/// does not need its schedule quoted back; one that ran three hours early does.
library;

import 'package:orchestrate_app/core/relationships/client_relationships.dart';

String _clock(DateTime at) {
  final local = at.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

const _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// A time said the way a person says it, relative to today.
String meetingWhen(DateTime at) {
  final local = at.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year && local.month == now.month && local.day == now.day;
  if (sameDay) return '${_clock(local)} today';

  final yesterday = now.subtract(const Duration(days: 1));
  if (local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day) {
    return '${_clock(local)} yesterday';
  }

  final tomorrow = now.add(const Duration(days: 1));
  if (local.year == tomorrow.year &&
      local.month == tomorrow.month &&
      local.day == tomorrow.day) {
    return '${_clock(local)} tomorrow';
  }

  return '${_clock(local)}, ${local.day} ${_months[local.month - 1]}';
}

/// How long it ran, when that is known and worth saying.
String? meetingDuration(RelationshipMeeting m) {
  final from = m.startedAt;
  final to = m.completedAt;
  if (from == null || to == null) return null;
  final minutes = to.difference(from).inMinutes;
  if (minutes < 1) return null;
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

/// The one line a meeting gets, composed from what is actually true about it.
///
/// Ordered by what a person needs first. A meeting nobody was invited to leads
/// with that, because nothing else about it matters until it is fixed. A
/// meeting that happened leads with when it happened. A meeting still ahead
/// leads with when it is due, because that is the only thing about it that is
/// yet a fact.
String meetingLine(RelationshipMeeting m) {
  if (m.neverReachedProvider) {
    return 'Never created with the meeting provider — nobody was invited';
  }

  final status = m.status.toUpperCase();
  final due = m.scheduledAt;
  final held = m.startedAt;

  if (status == 'CANCELED') {
    return due == null
        ? 'Cancelled'
        : 'Cancelled — was due ${meetingWhen(due)}';
  }

  if (status == 'NO_SHOW') {
    return due == null
        ? 'Nobody attended'
        : 'Nobody attended — was due ${meetingWhen(due)}';
  }

  if (held != null) {
    final parts = <String>['Held ${meetingWhen(held)}'];
    final ran = meetingDuration(m);
    if (ran != null) parts.add('ran $ran');
    // The schedule is quoted only when it genuinely differs. Repeating it for
    // a meeting that started on time is noise dressed as precision.
    if (m.heldAwayFromSchedule && due != null) {
      parts.add('was due ${meetingWhen(due)}');
    }
    return parts.join(' · ');
  }

  // Settled without ever having started. The record says it finished and has
  // no evidence it ever ran, and saying so is more honest than picking one.
  if (status == 'COMPLETED') {
    return due == null
        ? 'Recorded as held, with no record of it starting'
        : 'Recorded as held, with no record of it starting — was due '
            '${meetingWhen(due)}';
  }

  if (due == null) return 'No time set yet';

  final ahead = due.isAfter(DateTime.now());
  return ahead
      ? 'Due ${meetingWhen(due)}'
      : 'Was due ${meetingWhen(due)} — no record it took place';
}
