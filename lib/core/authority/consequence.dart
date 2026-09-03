/// WHAT AN ACT DOES IN THE WORLD.
///
/// The backend classifies every governed act into one of these, and routes
/// authority by that class. The client renders the same vocabulary, from this
/// one definition, so an act cannot be described as reversible in a button and
/// as contractual in a permission check.
///
/// Lives beside the authority model rather than in the UI layer because it is
/// a governance fact first and a presentation detail second — the wire values
/// below are the backend's own, not a client convention.
enum Consequence {
  /// A record of something. Nothing is claimed and nothing changes.
  informational('INFORMATIONAL'),

  /// Nothing leaves the system. A draft, a note, a saved view.
  reversibleInternal('REVERSIBLE_INTERNAL'),

  /// Someone outside will see this.
  externallyCommunicated('EXTERNALLY_COMMUNICATED'),

  /// This binds, or claims to.
  contractual('CONTRACTUAL'),

  /// This concerns money.
  financial('FINANCIAL'),

  /// This cannot be walked back.
  terminal('TERMINAL');

  const Consequence(this.wire);

  /// The backend's own name for this class.
  final String wire;

  static Consequence? parse(String? value) {
    for (final c in Consequence.values) {
      if (c.wire == value) return c;
    }
    return null;
  }
}
