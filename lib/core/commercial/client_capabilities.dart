import 'package:flutter/material.dart';

import '../../data/repositories/client/client_capability_repository.dart';
import '../auth/auth_session.dart';

export '../../data/repositories/client/client_capability_repository.dart'
    show
        CapabilityProjection,
        CapabilityVerdict,
        Entitlement,
        EntitlementSource,
        EntitlementState;

/// THE ONE PLACE THE CLIENT APP KNOWS WHAT IT MAY OPERATE.
///
/// Market, Relationship, Engagement and Plan & Billing all need the same
/// answer. Left alone each would decide for itself what a plan permits, and
/// the product would carry a second commercial doctrine that drifts from the
/// server's — with the customer looking at whichever copy is wrong.
///
/// So this holds the server's projection and interprets none of it. Every
/// sentence a person reads about a commercial boundary was written by the
/// authority that made the decision.
class ClientCapabilities extends ChangeNotifier {
  ClientCapabilities._() {
    // Entitlement belongs to an organisation. When the session changes hands
    // the previous answer is not stale, it is about somebody else's business.
    AuthSessionController.instance.addListener(_onSessionChanged);
  }

  static final ClientCapabilities instance = ClientCapabilities._();

  ClientCapabilityRepository _repository = ClientCapabilityRepository();

  /// So the LOAD path can be exercised, not only the seeded one. The spinner
  /// defect lived between a successful fetch and a painted frame, which a
  /// seeded test cannot reach.
  @visibleForTesting
  // ignore: use_setters_to_change_properties
  void useRepository(ClientCapabilityRepository repository) {
    _repository = repository;
  }

  CapabilityProjection? _projection;
  Object? _error;
  bool _loading = false;
  String? _forClientId;
  Future<CapabilityProjection>? _inFlight;

  CapabilityProjection? get projection => _projection;
  Object? get error => _error;
  bool get isLoading => _loading;
  bool get hasAnswer => _projection != null;

  Entitlement? get entitlement => _projection?.entitlement;

  /// Whether a capability is permitted. Unknown is never permitted — a client
  /// that has not been told cannot invent a yes.
  bool may(String capability) => _projection?.may(capability) ?? false;

  /// Why not, in the server's own words. Null when it is permitted, or when we
  /// have not been told yet.
  CapabilityVerdict? refusalFor(String capability) {
    final verdict = _projection?.forCapability(capability);
    return verdict == null || verdict.permitted ? null : verdict;
  }

  Future<CapabilityProjection> load() {
    final existing = _inFlight;
    if (existing != null) return existing;

    _loading = true;
    _error = null;
    // Deliberately NOT notified synchronously.
    //
    // A surface asks for this while it is building — that is the only moment it
    // can tell it has no answer. Notifying here would call setState() during
    // build, which Flutter refuses, and the refusal broke the rebuild chain so
    // the answer that arrived a moment later was never painted. The screen sat
    // on a spinner over a request that had already returned 200.
    //
    // The completion notification below is what surfaces actually need; a
    // "started loading" ping is only useful for a spinner that is already
    // showing.

    final future = _repository.fetch().then((projection) {
      _projection = projection;
      _forClientId = AuthSessionController.instance.clientId;
      _error = null;
      return projection;
    }).catchError((Object error) {
      _error = error;
      throw error;
    }).whenComplete(() {
      _loading = false;
      _inFlight = null;
      notifyListeners();
    });

    _inFlight = future;
    return future;
  }

  Future<void> refresh() async {
    _projection = null;
    try {
      await load();
    } catch (_) {
      // The error is held and rendered. Rethrowing here would take down
      // whichever screen happened to trigger the refresh.
    }
  }

  void _onSessionChanged() {
    final clientId = AuthSessionController.instance.clientId;
    if (clientId == _forClientId) return;

    // The answer belonged to a different business, so it goes.
    //
    // Discarding it is right; discarding it and stopping was the defect. The
    // fetch resolves while the session is still settling, stamps whatever
    // client id exists at that moment, and is then thrown away when the real
    // one arrives — leaving a screen waiting forever on a request that had
    // already succeeded.
    //
    // Re-asking is the consumer's job, not this object's. A singleton that
    // fetches on a session event reaches the network from wherever the session
    // happens to change, which is how a state holder becomes something nobody
    // can reason about. Surfaces ask when they build and find no answer.
    _projection = null;
    _error = null;
    _forClientId = null;
    notifyListeners();
  }

  /// A test seam, so every commercial state can be rendered and read as a
  /// person would see it. Nothing in the app calls it.
  @visibleForTesting
  void seed(CapabilityProjection? projection, {Object? error}) {
    _projection = projection;
    _error = error;
    _loading = false;
    _inFlight = null;
    _forClientId = AuthSessionController.instance.clientId;
    notifyListeners();
  }
}

/// The capability names the server uses. Strings, not a client-side enum of
/// permissions — the list is the server's to grow.
class Capabilities {
  const Capabilities._();

  static const readOwnRecords = 'READ_OWN_RECORDS';
  static const configureBusiness = 'CONFIGURE_BUSINESS';
  static const manageAccount = 'MANAGE_ACCOUNT';
  static const export = 'EXPORT';
  static const operateCommercially = 'OPERATE_COMMERCIALLY';
  static const researchCounterparties = 'RESEARCH_COUNTERPARTIES';
  static const governedExecution = 'GOVERNED_EXECUTION';
}
