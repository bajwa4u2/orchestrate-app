import 'package:flutter/services.dart';
import 'package:orchestrate_app/data/repositories/client/client_today_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_held_follow_ups_repository.dart';

const emptyToday = TodayState(
  alerts: [],
  workflow: {},
  eligibility: {'bucket': 'ready', 'blockers': []},
  recentMessages: [],
  replies: [],
  unavailable: {},
);

const _reason =
    'Orchestrate was not sure this is the right moment to write again, so it is waiting for your yes.';

final heldFixture = <HeldFollowUp>[
  HeldFollowUp(
    id: 'job_1',
    company: 'Kestrel Civil Works',
    contactName: 'Dana Reyes',
    firstSubject: 'County road work this spring',
    firstBody:
        'Hello Dana, your crews are bidding on the county road work this spring. We survey corridors like that every week. Could we send you a quote?',
    firstSentAt: DateTime(2026, 10, 14, 9, 4),
    reasonText: _reason,
    waitsUntil: DateTime(2026, 11, 2, 9, 4),
  ),
  HeldFollowUp(
    id: 'job_2',
    company: 'Harbor Mechanical',
    contactName: 'Luis Ortega',
    firstSubject: 'The Main Street permit',
    firstBody:
        'Hello Luis, a commercial permit was filed on Main Street last week. We handle fire protection for buildings like it. Worth a short call?',
    firstSentAt: DateTime(2026, 10, 16, 10, 30),
    reasonText: _reason,
    waitsUntil: DateTime(2026, 11, 2, 10, 30),
  ),
  HeldFollowUp(
    id: 'job_3',
    company: 'Northgate Property Group',
    contactName: null,
    firstSubject: 'Winter maintenance for your buildings',
    firstBody: 'Hello, before the first freeze we check roofs and drainage for property managers in the area.',
    firstSentAt: DateTime(2026, 10, 20, 8, 15),
    reasonText: 'Orchestrate would like a person to look before it writes again.',
    waitsUntil: DateTime(2026, 11, 3, 8, 15),
  ),
];

class FakeHeldFollowUps extends ClientHeldFollowUpsRepository {
  FakeHeldFollowUps(this.items);
  final List<HeldFollowUp> items;
  final sent = <String>[];
  final declined = <String>[];
  String? refuse;

  @override
  Future<List<HeldFollowUp>> list() async => items;

  @override
  Future<Map<String, dynamic>> send(String id) async {
    if (refuse != null) return {'ok': false, 'reason': refuse};
    sent.add(id);
    return {'ok': true, 'message': 'Orchestrate will write it now, after one more look at the conversation.'};
  }

  @override
  Future<Map<String, dynamic>> dontSend(String id) async {
    if (refuse != null) return {'ok': false, 'reason': refuse};
    declined.add(id);
    return {'ok': true, 'message': 'It will not be sent.'};
  }
}

/// The app's own fonts, so text is measured as people see it (not Ahem).
Future<void> loadAppFonts() async {
  const families = {
    'Newsreader': ['Newsreader-400', 'Newsreader-600', 'Newsreader-600Italic'],
    'PublicSans': ['PublicSans-400', 'PublicSans-500', 'PublicSans-600', 'PublicSans-700'],
    'JetBrainsMono': ['JetBrainsMono-500', 'JetBrainsMono-600'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final f in entry.value) {
      loader.addFont(rootBundle.load('assets/fonts/$f.ttf'));
    }
    await loader.load();
  }
}
