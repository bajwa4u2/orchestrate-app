import 'package:flutter/material.dart';

import '../../data/repositories/client/client_market_repository.dart';
import '../auth/auth_session.dart';

export '../../data/repositories/client/client_market_repository.dart'
    show
        BusinessIntent,
        Candidate,
        CandidateDepth,
        Certainty,
        MarketCounts,
        MarketView,
        Observation,
        PursuitDisposition;

/// THE ONE PLACE THE CLIENT APP KNOWS ITS MARKET.
///
/// The Market list, a candidate's depth, a Today item and the transition into
/// Relationship all need the same answer. Left alone each would fetch and
/// re-rank independently, and the list would disagree with the detail about
/// what the business had already decided.
///
/// Deliberately small: it holds the Market projection and nothing else. It
/// interprets nothing — ordering, certainty, reasoning and wording all come
/// from the server, which is the only side that can see the evidence.
class ClientMarket extends ChangeNotifier {
  ClientMarket._() {
    AuthSessionController.instance.addListener(_onSessionChanged);
  }

  static final ClientMarket instance = ClientMarket._();

  final ClientMarketRepository _repository = ClientMarketRepository();

  MarketView? _view;
  Object? _error;
  bool _loading = false;
  String? _forClientId;
  Future<MarketView>? _inFlight;

  MarketView? get view => _view;
  Object? get error => _error;
  bool get isLoading => _loading;
  bool get hasAnswer => _view != null;

  Future<MarketView> load({bool refresh = false}) {
    final clientId = AuthSessionController.instance.clientId;
    if (_forClientId != null && _forClientId != clientId) _reset();

    if (!refresh && _view != null) return Future.value(_view);
    final existing = _inFlight;
    if (existing != null) return existing;

    _loading = true;
    _error = null;
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

  Future<void> refresh() async {
    try {
      await load(refresh: true);
    } catch (_) {
      // Listeners already hold the error.
    }
  }

  Future<CandidateDepth> candidate(String key) => _repository.candidate(key);

  Future<Map<String, dynamic>> outreachReadiness(String key) =>
      _repository.outreachReadiness(key);

  /// Record the business's own view, then re-read the list.
  ///
  /// A judgement changes what the whole surface says about a company, so the
  /// shared answer is invalidated rather than each screen patching its own copy.
  Future<Map<String, dynamic>> setPursuit({
    required String key,
    required PursuitDisposition disposition,
    String? note,
  }) async {
    final result =
        await _repository.setPursuit(key: key, disposition: disposition, note: note);
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

  /// A test seam, so every Market state can be rendered and read as a person
  /// would see it. Nothing in the app calls it.
  @visibleForTesting
  void seed(MarketView? view, {Object? error}) {
    _reset();
    _view = view;
    _error = error;
    _forClientId = AuthSessionController.instance.clientId;
    notifyListeners();
  }
}
