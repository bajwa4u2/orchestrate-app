import 'package:flutter/widgets.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/data/repositories/client/client_today_repository.dart';

/// WHAT TODAY KNOWS, HELD ACROSS A VISIT.
///
/// Today used to fetch into the screen's own State, which is destroyed the
/// moment a person leaves it. So every return to the first destination in the
/// rail replaced the whole content area with a centred spinner and asked the
/// server again — a flash on the most-visited screen in the product, every
/// single time, including when nothing had changed.
///
/// Market and Relationships already worked this way; Today was the one that
/// did not. The rule the others follow, and this one now follows too: an
/// answer already given is painted immediately, and refreshing happens
/// underneath rather than behind a blank screen.
class ClientToday extends ChangeNotifier {
  ClientToday._() {
    AuthSessionController.instance.addListener(_onSessionChanged);
  }

  static final ClientToday instance = ClientToday._();

  final ClientTodayRepository _repository = ClientTodayRepository();

  TodayState? _state;
  Object? _error;
  bool _loading = false;
  String? _forClientId;
  Future<TodayState>? _inFlight;

  TodayState? get state => _state;
  Object? get error => _error;
  bool get isLoading => _loading;
  bool get hasAnswer => _state != null;

  Future<TodayState> load({bool refresh = false}) {
    final clientId = AuthSessionController.instance.clientId;
    if (_forClientId != null && _forClientId != clientId) _reset();

    if (!refresh && _state != null) return Future.value(_state);
    final existing = _inFlight;
    if (existing != null) return existing;

    _loading = true;
    _error = null;
    // Not synchronously: a surface asks for this while it is building, and
    // notifying there calls setState during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_loading) notifyListeners();
    });

    final future = _repository.load().then((value) {
      _state = value;
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
    _state = null;
    _error = null;
    _loading = false;
    _forClientId = null;
    _inFlight = null;
  }

  /// A test seam, so every state of Today can be rendered and read as a person
  /// would see it. Nothing in the app calls it.
  @visibleForTesting
  void seed(TodayState? state, {Object? error}) {
    _reset();
    _state = state;
    _error = error;
    _forClientId = AuthSessionController.instance.clientId;
    notifyListeners();
  }
}
