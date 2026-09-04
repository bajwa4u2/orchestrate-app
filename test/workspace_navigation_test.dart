import 'package:flutter_test/flutter_test.dart';

import 'package:orchestrate_app/core/navigation/workspace_map.dart';

/// GETTING OUT OF WHERE YOU ARE.
///
/// The founder entered Business, went into a working surface, and could not
/// tell where he was or how to get back. The measurement behind that: 89
/// surfaces, 6 carrying a header, 2 carrying a return, and 20 client surfaces
/// with no return affordance of any kind.
///
/// These assert the navigation authority rather than any screen, because the
/// answer has to be the same everywhere. A per-screen back button is a
/// per-screen opinion, and twenty of those is what produced the estate above.
void main() {
  // Every destination Business offers. Kept here rather than read from the
  // screen so that adding a Business row without placing it on the map is a
  // failing test rather than another surface a person gets lost in.
  const businessDestinations = <String>[
    '/client/representation',
    '/app/branding',
    '/client/infrastructure',
    '/client/trust',
    '/app/evidence',
    '/app/artifacts',
  ];

  test('every Business surface knows what contains it', () {
    final orphans = surfacesMissingOwnership(businessDestinations);
    expect(orphans, isEmpty,
        reason: 'a surface with no owner is a surface with no way back');

    for (final route in businessDestinations) {
      expect(semanticParentOf(route), '/client/business',
          reason: '$route belongs to Business and must return there');
      expect(titleOf(route), isNotNull,
          reason: '$route must be able to say what it is');
      expect(areaOf(route), WorkspaceArea.business);
    }
  });

  test('an area landing offers no return to itself', () {
    for (final area in WorkspaceArea.values) {
      expect(isAreaLanding(area.root), isTrue);
      expect(semanticParentOf(area.root), isNull,
          reason: '${area.root} is a destination, not a sub-surface');
    }
  });

  test('a deep link has an escape even with no history behind it', () {
    // The case that strands people: an emailed link opened in a new tab. There
    // is no history to go back through, so the return has to come from what
    // the product knows about itself rather than from the navigation stack.
    const cold = '/client/infrastructure';
    expect(semanticParentOf(cold), isNotNull);
    expect(semanticParentOf(cold), isNot(cold));
  });

  test('an unmapped child inherits its parent rather than falling off', () {
    // Sub-routes appear over time. Inheriting ownership means a new one is
    // orientable on the day it ships, instead of being a dead end until
    // somebody notices.
    expect(semanticParentOf('/client/infrastructure/smtp'), '/client/business');
    expect(areaOf('/client/infrastructure/smtp'), WorkspaceArea.business);
  });

  test('home is one place, and it is a real destination', () {
    expect(canonicalWorkspaceHome, '/client/today');
    expect(isAreaLanding(canonicalWorkspaceHome), isTrue,
        reason: 'the logo must land somewhere that is itself a destination');
  });

  test('the account layer returns within itself, not into the workspace', () {
    // Account is the business's relationship with Orchestrate. Returning from
    // Plan & billing into Today would cross a boundary the product keeps
    // deliberately: Business is how their operation is configured, Account is
    // what they have with us.
    expect(semanticParentOf('/account/plan'), '/account/people');
    expect(areaOf('/account/plan'), WorkspaceArea.account);
  });
}
