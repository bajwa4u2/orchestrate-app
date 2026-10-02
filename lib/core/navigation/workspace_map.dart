/// WHERE EVERY WORKSPACE SURFACE SITS, AND WHAT GOING BACK MEANS.
///
/// One authority for the whole estate. The alternative — each screen deciding
/// its own return — is what produced 89 surfaces of which 6 carried a header
/// and 2 carried a return, and 20 client surfaces a person could enter and not
/// get out of except by guessing at the rail.
///
/// TWO DIFFERENT QUESTIONS, deliberately kept apart:
///
///   Browser Back is HISTORY. It answers "where was I a moment ago", and
///   nothing here overrides it.
///
///   The visible return is a SEMANTIC DESTINATION. It answers "what contains
///   this", and it has an answer even when there is no history at all — which
///   is the case that matters, because a person arriving on a deep link has
///   none. A workspace that only offers Back strands every emailed link.
///
/// So the two coexist and are never made to fight: Back goes where you came
/// from, the return action goes where this surface belongs.
library;

/// The one place a person lands when they ask for "home".
///
/// Today rather than a dashboard: it is the queue of what needs them, and it
/// is what the rail's first destination already means. Derived from the
/// existing architecture rather than invented to fix the logo.
const String canonicalWorkspaceHome = '/client/today';

/// The workspace areas. Four territories, matching the rail exactly, plus the
/// account layer — which is deliberately not a rail destination because it is
/// the business's relationship with Orchestrate rather than their own work.
enum WorkspaceArea {
  today('Today', '/client/today'),
  // DD-26 names: Customers is the relationship place; Money the business's
  // own commerce; Setup the business itself.
  market('Market', '/client/market'),
  relationships('Customers', '/client/relationships'),
  money('Money', '/client/money'),
  business('Setup', '/client/setup'),
  account('Account', '/account/people');

  const WorkspaceArea(this.label, this.root);
  final String label;
  final String root;
}

class _Surface {
  const _Surface(this.title, this.area, {this.parent});

  final String title;
  final WorkspaceArea area;

  /// What contains this. Null means the surface IS the area's landing, and a
  /// landing does not offer a return to itself.
  final String? parent;
}

/// Every workspace surface that is not an area landing.
///
/// A surface absent from here renders without a return header — which is
/// correct for the four landings and for anything that is genuinely top level,
/// and is a bug for anything else. `surfacesMissingOwnership` exists so that
/// is measurable rather than a matter of opinion.
const Map<String, _Surface> _surfaces = {
  // ── SETUP ────────────────────────────────────────────────────────
  // The Business pages that lived here (identity, branding, targeting,
  // mailbox, credentials, evidence, artifacts, records, newsletter) are
  // retired; each address redirects into Setup or Account (DD-34).

  // ── RELATIONSHIPS ────────────────────────────────────────────────────
  // One name, one home: the page says "Waiting on you" and is reached from
  // Today, so its trail and its tab say the same (2 Oct 2026).
  '/client/inbound': _Surface('Waiting on you', WorkspaceArea.today,
      parent: '/client/today'),

  // ── ACCOUNT ──────────────────────────────────────────────────────────
  // The account layer is a set of siblings under one roof; each returns to the
  // roof rather than to whichever one was visited last.
  '/account/plan':
      _Surface('Plan and billing', WorkspaceArea.account, parent: '/account/people'),
  '/account/security':
      _Surface('Security', WorkspaceArea.account, parent: '/account/people'),
  '/client/support':
      _Surface('Support', WorkspaceArea.account, parent: canonicalWorkspaceHome),

  '/account/record': _Surface('Your record with Orchestrate',
      WorkspaceArea.account, parent: '/account/plan'),
};

/// The area landings. These are destinations in their own right and offer no
/// return, because there is nothing above them.
const Set<String> _landings = {
  '/client/today',
  '/client/market',
  '/client/relationships',
  '/client/money',
  '/client/setup',
  '/client/setup/workspace',
  '/account/people',
};

/// What contains this surface, or null when it is a landing.
///
/// Always answers for a known surface, including on a cold deep link where
/// browser history is empty. That is the whole reason it is a map of the
/// product rather than a read of the navigation stack.
String? semanticParentOf(String path) {
  final surface = _surfaceFor(path);
  return surface?.parent;
}

/// What this surface is called, in the words the product uses for it.
String? titleOf(String path) => _surfaceFor(path)?.title;

/// Which area owns this surface. Used to say where a person is before saying
/// how to leave.
WorkspaceArea? areaOf(String path) {
  final surface = _surfaceFor(path);
  if (surface != null) return surface.area;
  for (final area in WorkspaceArea.values) {
    if (path == area.root) return area;
  }
  return null;
}

/// True when this path is an area landing and should carry no return.
bool isAreaLanding(String path) => _landings.contains(path);

_Surface? _surfaceFor(String path) {
  final exact = _surfaces[path];
  if (exact != null) return exact;
  // Longest-prefix, so a child of a mapped surface inherits its ownership
  // rather than falling off the map entirely.
  _Surface? best;
  var bestLength = 0;
  for (final entry in _surfaces.entries) {
    if (path.startsWith('${entry.key}/') && entry.key.length > bestLength) {
      best = entry.value;
      bestLength = entry.key.length;
    }
  }
  return best;
}

/// Surfaces reachable in the product that this map does not place.
///
/// Exposed so the gap is a number a test can assert on, rather than something
/// discovered later by a person who could not get out of a screen.
List<String> surfacesMissingOwnership(Iterable<String> routes) => [
      for (final route in routes)
        if (!isAreaLanding(route) && _surfaceFor(route) == null) route,
    ];
