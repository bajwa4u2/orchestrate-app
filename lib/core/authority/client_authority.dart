import 'package:flutter/material.dart';

import '../../data/repositories/client/client_authority_repository.dart';
import '../auth/auth_session.dart';

export '../../data/repositories/client/client_authority_repository.dart'
    show
        ActionAuthority,
        AreaStanding,
        AuthorityArea,
        AuthorityProjection,
        AuthorityRefusal,
        Consequence,
        EvidenceStanding,
        GrantProvenance,
        MissingStep,
        PerformedBy,
        Submission,
        SubmissionState;

/// THE ONE PLACE THE CLIENT APP KNOWS WHAT IT MAY DO.
///
/// Account, the designation journey, the command palette, and every
/// consequential surface a later chapter adds all need the same answer to the
/// same question. Left alone, each would fetch it, cache it differently, and
/// interpret it slightly differently — and the fourth one written would quietly
/// invent a fifth rule. So there is one owner, and it is deliberately small: it
/// holds standing authority and nothing else. It is not an application store,
/// and no unrelated state belongs in it.
///
/// It resolves nothing itself. Every answer here came from the backend, which
/// is the only place that knows why the answer is what it is.
class ClientAuthority extends ChangeNotifier {
  ClientAuthority._() {
    // Authority belongs to a business. When the session changes hands, the
    // previous answer is not stale — it is about someone else — so it is
    // dropped rather than left to expire.
    AuthSessionController.instance.addListener(_onSessionChanged);
  }

  static final ClientAuthority instance = ClientAuthority._();

  final ClientAuthorityRepository _repository = ClientAuthorityRepository();

  AuthorityProjection? _projection;
  Object? _error;
  bool _loading = false;

  /// The client this answer belongs to. Authority is per business, so an
  /// answer fetched for one must never be shown for another.
  String? _forClientId;

  Future<AuthorityProjection>? _inFlight;

  AuthorityProjection? get projection => _projection;
  Object? get error => _error;
  bool get isLoading => _loading;
  bool get hasAnswer => _projection != null;

  /// Load once, then serve from memory.
  ///
  /// Concurrent callers share one request rather than racing: three widgets
  /// building in the same frame is normal, and three identical calls is not.
  Future<AuthorityProjection> load({bool refresh = false}) {
    final clientId = AuthSessionController.instance.clientId;
    if (_forClientId != null && _forClientId != clientId) {
      // Signed in as someone else. The previous answer is not merely stale, it
      // is about a different business.
      _reset();
    }

    if (!refresh && _projection != null) return Future.value(_projection);
    final existing = _inFlight;
    if (existing != null) return existing;

    _loading = true;
    _error = null;
    // Deferred so a caller inside build() does not trigger a synchronous
    // rebuild of the tree it is already building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_loading) notifyListeners();
    });

    final future = _repository.fetch().then((value) {
      _projection = value;
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

  /// Something happened that could have changed what this person may do — a
  /// designation submitted, a person recognised, a capability revoked.
  ///
  /// Callers say so rather than each deciding how long an answer stays true.
  Future<void> refresh() async {
    try {
      await load(refresh: true);
    } catch (_) {
      // The listeners already have the error; a refresh is never fatal to the
      // caller that asked for it.
    }
  }

  /// Whether a specific act may proceed.
  ///
  /// Not cached. Standing authority is stable enough to hold in memory; the
  /// answer at the moment of acting is asked at the moment of acting, because
  /// it is the answer a person is about to rely on.
  Future<ActionAuthority> can(
    Consequence consequence, {
    PerformedBy by = PerformedBy.human,
  }) {
    final seeded = _seededActions?['${consequence.wire}:${by.wire}'];
    if (seeded != null) return Future.value(seeded);
    return _repository.can(consequence: consequence, by: by);
  }

  Map<String, ActionAuthority>? _seededActions;

  /// Forget everything. Called when the session ends.
  void clear() {
    _reset();
    notifyListeners();
  }

  /// Place a known answer without going to the network.
  ///
  /// Exists so the authority states can be rendered and inspected as a person
  /// would see them, including the ones production has never been in. It is a
  /// test seam and nothing in the app calls it.
  @visibleForTesting
  void seed(AuthorityProjection? projection, {Object? error}) {
    _reset();
    _projection = projection;
    _error = error;
    _forClientId = AuthSessionController.instance.clientId;
    notifyListeners();
  }

  /// Known point-of-action answers, keyed `CONSEQUENCE:BY`.
  ///
  /// The companion to [seed], for rendering how an act presents itself when it
  /// is permitted and when it is refused.
  @visibleForTesting
  void seedActions(Map<String, ActionAuthority>? answers) {
    _seededActions = answers;
  }

  void _onSessionChanged() {
    final clientId = AuthSessionController.instance.clientId;
    if (_forClientId == null || _forClientId == clientId) return;
    _reset();
    notifyListeners();
  }

  void _reset() {
    _projection = null;
    _error = null;
    _loading = false;
    _forClientId = null;
    _inFlight = null;
  }
}

/// Builds against standing authority, loading it if nobody has yet.
///
/// Exists so a surface states what it needs authority *for* and gets the
/// answer, instead of every screen re-writing the same load-error-empty
/// scaffolding around the same call.
class AuthorityBuilder extends StatefulWidget {
  const AuthorityBuilder({
    super.key,
    required this.builder,
    this.loading,
    this.onError,
  });

  final Widget Function(BuildContext context, AuthorityProjection authority) builder;

  /// Shown while the first answer is on its way. A later refresh keeps the
  /// answer on screen rather than flashing back to a spinner.
  final Widget? loading;

  /// Shown when authority could not be read. Deliberately not optional-silent:
  /// a surface that cannot tell what someone may do must not guess that they
  /// may, and must not pretend the question was never asked.
  final Widget Function(BuildContext context, Object error)? onError;

  @override
  State<AuthorityBuilder> createState() => _AuthorityBuilderState();
}

class _AuthorityBuilderState extends State<AuthorityBuilder> {
  final ClientAuthority _authority = ClientAuthority.instance;

  @override
  void initState() {
    super.initState();
    _authority.addListener(_onChanged);
    if (!_authority.hasAnswer && !_authority.isLoading && _authority.error == null) {
      _authority.load().catchError((Object e) => throw e);
    }
  }

  @override
  void dispose() {
    _authority.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final projection = _authority.projection;
    if (projection != null) return widget.builder(context, projection);

    final error = _authority.error;
    if (error != null) {
      return widget.onError?.call(context, error) ??
          _AuthorityUnavailable(onRetry: () => _authority.refresh());
    }

    return widget.loading ??
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
  }
}

class _AuthorityUnavailable extends StatelessWidget {
  const _AuthorityUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'We could not check what you may do here.',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Nothing has changed. Rather than guess, we have left everything '
            'that needs authority unavailable until we can check again.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
