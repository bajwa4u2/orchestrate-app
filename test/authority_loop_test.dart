import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A DESIGNATION HAS TO CLOSE AS A LOOP, ON BOTH SIDES.
///
/// The client half of it: a person submitted, was told "we are reviewing what
/// you sent", and had no way to learn what they had sent, what was being relied
/// on, or what would settle it. Meanwhile they were told, on the same screen,
/// that they were not recognised to decide for the business and that Orchestrate
/// could already communicate on its behalf — which reads as a contradiction and
/// was never explained.
void main() {
  final panel = File('lib/features/client/widgets/authority_evidence_panel.dart')
      .readAsStringSync();
  final standing =
      File('lib/features/client/widgets/standing_authority.dart').readAsStringSync();
  final people =
      File('lib/features/client/screens/client_authorised_people_screen.dart')
          .readAsStringSync();
  final repository =
      File('lib/data/repositories/client/client_authority_repository.dart')
          .readAsStringSync();

  test('there is always an answer to what supports this', () {
    expect(panel.contains('What supports this'), isTrue);
    // Existing evidence is shown as relied upon, not asked for again.
    expect(panel.contains('reliedUpon'), isTrue);
    expect(repository.contains("json['reliedUpon']"), isTrue);
  });

  test('and a way to supply more when we ask', () {
    // The path the controller actually serves. It was written as
    // /client/designation/evidence, which is not a route: the controller is
    // @Controller('client/representative'). The panel 404'd on every load and
    // rendered "We could not read what this claim rests on just now" — found by
    // looking at it, not by any test that only checked the panel existed.
    expect(repository.contains("'/client/representative/evidence'"), isTrue);
    expect(repository.contains('addSupport'), isTrue);
    expect(panel.contains('mayAddSupport'), isTrue);
    // Never a document requirement we do not actually have.
    expect(
      panel.contains('It does not have to be a document'),
      isTrue,
      reason: 'asking for a PDF we do not require is how a claim stalls',
    );
  });

  test('the evidence panel is where the person who submitted is looking', () {
    expect(people.contains('AuthorityEvidencePanel'), isTrue);
    final at = people.indexOf('AuthorityEvidencePanel');
    final standingAt = people.indexOf('StandingAuthority(');
    expect(
      at > standingAt,
      isTrue,
      reason: 'it explains the standing directly above it',
    );
  });

  test('partial admission is said as one', () {
    // Admitted for some areas and not others is a fact about the decision, and
    // showing only what was admitted makes a partial look like a whole.
    expect(panel.contains('notAdmitted'), isTrue);
    expect(panel.contains('Not admitted for'), isTrue);
  });

  test('the apparent contradiction is explained where it appears', () {
    expect(repository.contains('class GrantProvenance'), isTrue);
    expect(standing.contains('provenance: authority.orchestrateProvenance'), isTrue);
    // Provenance is facts — who, when — not the phrase "legacy grant", which
    // explains nothing and cannot be checked.
    expect(repository.contains('acceptedBy'), isTrue);
    expect(repository.contains('scopeWasStated'), isTrue);
  });
}
