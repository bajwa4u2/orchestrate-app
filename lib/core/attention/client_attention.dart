import 'package:flutter/material.dart';

import '../../data/repositories/client/client_attention_repository.dart';
import '../auth/auth_session.dart';

export '../../data/repositories/client/client_attention_repository.dart'
    show
        AttentionAction,
        AttentionItem,
        AttentionOwner,
        AttentionState,
        AttentionView,
        SafeMessage;

/// THE ONE PLACE THE CLIENT APP KNOWS WHAT IS WAITING.
///
/// Today, the Attention list, a message detail and — later — a Relationship
/// screen all need the same answer. Left alone each would fetch it, cache it
/// differently, and drift: Today would say one item needs you while the list
/// showed two, and both would be quoting the same backend.
///
/// So there is one owner, deliberately small. It holds open Attention and
/// nothing else — not an application store, and no unrelated state belongs in
/// it. It interprets nothing: ownership, actions and wording all come from the
/// backend, which is the only side that knows why the answer is what it is.
class ClientAttention extends ChangeNotifier {
  ClientAttention._() {
    // Attention belongs to a business. When the session changes hands the
    // previous answer is not stale, it is about someone else.
    AuthSessionController.instance.addListener(_onSessionChanged);
  }

  static final ClientAttention instance = ClientAttention._();

  final ClientAttentionRepository _repository = ClientAttentionRepository();

  AttentionView? _view;
  Object? _error;
  bool _loading = false;
  String? _forClientId;
  Future<AttentionView>? _inFlight;

  AttentionView? get view => _view;
  Object? get error => _error;
  bool get isLoading => _loading;
  bool get hasAnswer => _view != null;

  /// Open work this business's own people owe. What Today shows.
  List<AttentionItem> get needsYou => _view?.needsYou ?? const [];

  /// Load once, then serve from memory. Concurrent callers share one request:
  /// several widgets building in the same frame is normal, several identical
  /// requests is not.
  Future<AttentionView> load({bool refresh = false}) {
    final clientId = AuthSessionController.instance.clientId;
    if (_forClientId != null && _forClientId != clientId) _reset();

    if (!refresh && _view != null) return Future.value(_view);
    final existing = _inFlight;
    if (existing != null) return existing;

    _loading = true;
    _error = null;
    // Deferred so a caller inside build() does not synchronously rebuild the
    // tree it is already building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_loading) notifyListeners();
    });

    final future = _repository.fetch().then((value) {
      _view = value;
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

  /// Something happened that could have changed what is waiting.
  Future<void> refresh() async {
    try {
      await load(refresh: true);
    } catch (_) {
      // Listeners already have the error; a refresh is never fatal to whoever
      // asked for it.
    }
  }

  /// Read one message. Not cached: the body is fetched at the moment of
  /// reading and deliberately never held here.
  Future<SafeMessage> review(String id) => _repository.review(id);

  /// Record that someone dealt with an item, then re-read what is waiting.
  ///
  /// Returns the backend's own answer so a refusal stays a refusal rather than
  /// becoming a silent no-op.
  Future<Map<String, dynamic>> settle({
    required String id,
    required AttentionAction action,
  }) async {
    final result = await _repository.settle(id: id, action: action);
    if (result['ok'] == true) await refresh();
    return result;
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
    _view = null;
    _error = null;
    _loading = false;
    _forClientId = null;
    _inFlight = null;
  }

  /// Place a known answer without going to the network.
  ///
  /// A test seam, so every state can be rendered and read as a person would
  /// see it — including the ones production has not been in. Nothing in the app
  /// calls it.
  @visibleForTesting
  void seed(AttentionView? view, {Object? error}) {
    _reset();
    _view = view;
    _error = error;
    _forClientId = AuthSessionController.instance.clientId;
    notifyListeners();
  }
}
