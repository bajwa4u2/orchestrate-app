import 'package:flutter/material.dart';

import '../../data/repositories/client/client_relationship_workspace_repository.dart';
import '../attention/client_attention.dart';
import '../auth/auth_session.dart';

export '../../data/repositories/client/client_relationship_workspace_repository.dart'
    show
        EngagementSummary,
        Reachability,
        RelationshipAttention,
        RelationshipCondition,
        RelationshipDepth,
        RelationshipList,
        RelationshipOrigin,
        RelationshipSummary,
        TimelineEntry;

/// THE ONE PLACE THE CLIENT APP KNOWS ITS RELATIONSHIPS.
///
/// The list, the depth view, a Today item that concerns a relationship, and the
/// arrival from Market all need the same answer. Left alone each would assemble
/// relationship semantics locally, and the list would say one thing about a
/// counterparty while the detail said another — which is exactly what happened
/// when the backend had two condition derivations.
///
/// Holds relationships and nothing else. Condition, timeline, origin and
/// engagement containment are server truth; none of them is local state and
/// none may be set with setState. Local state is for expanded sections,
/// filters and drafts.
class ClientRelationships extends ChangeNotifier {
  ClientRelationships._() {
    AuthSessionController.instance.addListener(_onSessionChanged);
  }

  static final ClientRelationships instance = ClientRelationships._();

  final ClientRelationshipWorkspaceRepository _repository =
      ClientRelationshipWorkspaceRepository();

  RelationshipList? _list;
  Object? _error;
  bool _loading = false;
  String? _forClientId;
  Future<RelationshipList>? _inFlight;

  /// Depth answers already fetched, keyed by relationship id. Cached because
  /// entering and leaving a relationship is the most common movement here.
  final Map<String, RelationshipDepth> _depth = {};

  RelationshipList? get list => _list;
  Object? get error => _error;
  bool get isLoading => _loading;
  bool get hasAnswer => _list != null;

  RelationshipDepth? cachedDepth(String id) => _depth[id];

  Future<RelationshipList> load({bool refresh = false}) {
    final clientId = AuthSessionController.instance.clientId;
    if (_forClientId != null && _forClientId != clientId) _reset();

    if (!refresh && _list != null) return Future.value(_list);
    final existing = _inFlight;
    if (existing != null) return existing;

    _loading = true;
    _error = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_loading) notifyListeners();
    });

    final future = _repository.fetchList().then((value) {
      _list = value;
      _forClientId = clientId;
      _error = null;
      return value;
    }).catchError((Object e) {
      _error = e;
      throw e;
    }).whenComplete(() {
      _loading = false;
      _inFlight = null;
      notifyListeners();
    });

    _inFlight = future;
    return future;
  }

  Future<RelationshipDepth> depth(String id, {bool refresh = false}) async {
    final cached = _depth[id];
    if (!refresh && cached != null) return cached;
    final value = await _repository.fetchDepth(id);
    _depth[id] = value;
    notifyListeners();
    return value;
  }

  /// Something happened that could have changed what a relationship shows.
  ///
  /// Invalidates the shared answer and Attention together, because resolving an
  /// item in one place must not leave the other stale. No widget callbacks
  /// across domains.
  Future<void> invalidate({String? relationshipId}) async {
    if (relationshipId != null) {
      _depth.remove(relationshipId);
    } else {
      _depth.clear();
    }
    await Future.wait([
      load(refresh: true).catchError((Object e) => throw e),
      ClientAttention.instance.refresh(),
    ]);
  }

  Future<void> refresh() async {
    try {
      await load(refresh: true);
    } catch (_) {
      // Listeners already hold the error.
    }
  }

  void clear() {
    _reset();
    notifyListeners();
  }

  void _onSessionChanged() {
    final clientId = AuthSessionController.instance.clientId;
    if (_forClientId == null || _forClientId == clientId) return;
    _reset();
    notifyListeners();
  }

  void _reset() {
    _list = null;
    _error = null;
    _loading = false;
    _forClientId = null;
    _inFlight = null;
    _depth.clear();
  }

  /// A test seam, so every relationship state can be rendered and read as a
  /// person would see it. Nothing in the app calls it.
  @visibleForTesting
  void seed(RelationshipList? list, {Object? error, Map<String, RelationshipDepth>? depth}) {
    _reset();
    _list = list;
    _error = error;
    if (depth != null) _depth.addAll(depth);
    _forClientId = AuthSessionController.instance.clientId;
    notifyListeners();
  }
}
