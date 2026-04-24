import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionController extends ChangeNotifier {
  AuthSessionController._();

  static final AuthSessionController instance = AuthSessionController._();

  static const _clientKey = 'orch_client_session_v1';
  static const _operatorKey = 'orch_operator_session_v1';

  bool _ready = false;
  Map<String, dynamic>? _session;

  bool get isReady => _ready;
  bool get isAuthenticated => token.isNotEmpty;
  String get token => (_session?['token'] as String?) ?? '';
  String get surface => (_session?['surface'] as String?) ?? '';
  String get organizationId => (_session?['organizationId'] as String?) ?? '';
  String get clientId => (_session?['clientId'] as String?) ?? '';
  String get memberRole => (_session?['memberRole'] as String?) ?? '';
  String get email => (_session?['email'] as String?) ?? '';
  String get fullName => (_session?['fullName'] as String?) ?? '';
  bool get emailVerified => (_session?['emailVerified'] as bool?) ?? false;
  String get workspaceName => (_session?['workspaceName'] as String?) ?? '';
  bool get hasSetupCompleted => (_session?['setupCompleted'] as bool?) ?? false;

  String? get commercialPlan {
    final value = (_session?['commercialPlan'] as String?)?.trim();
    if (value == null || value.isEmpty) return null;
    return _normalizePlan(value);
  }

  String? get commercialTier {
    final value = (_session?['commercialTier'] as String?)?.trim();
    if (value == null || value.isEmpty) return null;
    return _normalizeTier(value);
  }

  String? get setupSelectedPlan {
    final value = ((_session?['setupSelectedPlan'] ?? _session?['selectedPlan'])
            as String?)
        ?.trim();
    if (value == null || value.isEmpty) return null;
    return _normalizePlan(value);
  }

  String? get setupSelectedTier {
    final value = ((_session?['setupSelectedTier'] ?? _session?['selectedTier'])
            as String?)
        ?.trim();
    if (value == null || value.isEmpty) return null;
    return _normalizeTier(value);
  }

  String? get selectedPlan => commercialPlan ?? setupSelectedPlan;

  String? get selectedTier => commercialTier ?? setupSelectedTier;

  String? get selectedPlanDisplay => _buildPlanDisplay(
        plan: commercialPlan ?? setupSelectedPlan,
        tier: commercialTier ?? setupSelectedTier,
      );

  String get subscriptionStatus =>
      (_session?['subscriptionStatus'] as String?) ?? 'none';
  String get normalizedSubscriptionStatus =>
      subscriptionStatus.trim().toLowerCase();

  Map<String, dynamic>? get setupDraft {
    final raw = _session?['setupDraft'];
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  String _resolveKey(String? currentSurface) {
    return currentSurface == 'operator' ? _operatorKey : _clientKey;
  }

  Future<void> init() async {
    if (_ready) return;
    if (_session != null &&
        (((_session?['token'] as String?)?.isNotEmpty ?? false) ||
            ((_session?['organizationId'] as String?)?.isNotEmpty ?? false) ||
            ((_session?['clientId'] as String?)?.isNotEmpty ?? false))) {
      _ready = true;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    final clientRaw = prefs.getString(_clientKey);
    final operatorRaw = prefs.getString(_operatorKey);

    if (clientRaw != null && clientRaw.isNotEmpty) {
      try {
        _session = Map<String, dynamic>.from(jsonDecode(clientRaw));
      } catch (_) {}
    }

    if (_session == null && operatorRaw != null && operatorRaw.isNotEmpty) {
      try {
        _session = Map<String, dynamic>.from(jsonDecode(operatorRaw));
      } catch (_) {}
    }

    _ready = true;
    notifyListeners();
  }

  Future<void> applyAuthResponse(Map<String, dynamic> payload) async {
    final previous = Map<String, dynamic>.from(_session ?? const {});
    final user = _mapOf(payload['user']);
    final workspace = _mapOf(payload['workspace']);
    final session = _mapOf(payload['session']);
    final setup = _mapOf(payload['setup']);
    final commercial = _mapOf(payload['commercial'] ?? payload['subscription']);
    final client = _mapOf(payload['client']);

    final newSurface = _readString(session, const ['surface']) ??
        previous['surface']?.toString() ??
        'client';
    final nextToken = payload['token']?.toString().trim() ??
        _readString(session, const ['token', 'accessToken']) ??
        _readString(client, const ['token', 'accessToken']) ??
        payload['accessToken']?.toString().trim();

    final resolvedOrganizationId =
        _readString(workspace, const ['organizationId']) ??
            _readString(session, const ['organizationId']) ??
            _readString(client, const ['organizationId']) ??
            payload['organizationId']?.toString() ??
            previous['organizationId']?.toString() ??
            '';

    final resolvedClientId = _readString(session, const ['clientId']) ??
        _readString(client, const ['id', 'clientId']) ??
        _readString(workspace, const ['clientId']) ??
        _readString(user, const ['clientId']) ??
        payload['clientId']?.toString() ??
        previous['clientId']?.toString() ??
        '';

    _session = {
      'token': (nextToken != null && nextToken.isNotEmpty)
          ? nextToken
          : previous['token']?.toString() ?? '',
      'surface': newSurface,
      'organizationId': resolvedOrganizationId,
      'clientId': resolvedClientId,
      'memberRole': _readString(session, const ['memberRole']) ??
          previous['memberRole']?.toString() ??
          '',
      'email': _readString(user, const ['email']) ??
          previous['email']?.toString() ??
          '',
      'fullName': _readString(user, const ['fullName', 'name']) ??
          previous['fullName']?.toString() ??
          '',
      'emailVerified': user.containsKey('emailVerified')
          ? user['emailVerified'] == true
          : previous['emailVerified'] == true,
      'workspaceName': _readString(workspace, const ['displayName', 'name']) ??
          _readString(client, const ['displayName', 'legalName']) ??
          previous['workspaceName']?.toString() ??
          '',
      'setupCompleted': user['setupCompleted'] == true ||
          setup['setupCompleted'] == true ||
          client['setupCompleted'] == true ||
          previous['setupCompleted'] == true,
      'setupSelectedPlan': _normalizePlan(
        _readString(setup, const ['selectedPlan']) ??
            _readString(client, const ['setupSelectedPlan', 'selectedPlan']) ??
            _readString(user, const ['selectedPlan']) ??
            previous['setupSelectedPlan']?.toString() ??
            previous['selectedPlan']?.toString(),
      ),
      'setupSelectedTier': _normalizeTier(
        _readString(setup, const ['selectedTier']) ??
            _readString(client, const ['setupSelectedTier', 'selectedTier']) ??
            _readString(user, const ['selectedTier']) ??
            previous['setupSelectedTier']?.toString() ??
            previous['selectedTier']?.toString(),
      ),
      'commercialPlan': _normalizePlan(
        _readString(commercial, const ['service', 'lane']) ??
            previous['commercialPlan']?.toString(),
      ),
      'commercialTier': _normalizeTier(
        _readString(commercial, const ['tier']) ??
            previous['commercialTier']?.toString(),
      ),
      'subscriptionStatus': (_readString(commercial, const ['status']) ??
              _readString(user, const ['subscriptionStatus']) ??
              _readString(setup, const ['subscriptionStatus']) ??
              _readString(client, const ['subscriptionStatus']) ??
              previous['subscriptionStatus']?.toString() ??
              'none')
          .toLowerCase(),
      'setup': setup.isNotEmpty ? setup : previous['setup'],
      'setupDraft': previous['setupDraft'],
    };

    _ready = true;
    await _persist();
  }

  Future<void> applyClientSetupResponse(Map<String, dynamic> payload) async {
    _session ??= {};
    final client = _mapOf(payload['client']);
    final commercial = _mapOf(client['commercial']);

    final nextClientId = _readString(client, const ['id', 'clientId']);
    final nextOrganizationId = _readString(client, const ['organizationId']);

    if (nextClientId != null && nextClientId.isNotEmpty) {
      _session!['clientId'] = nextClientId;
    }
    if (nextOrganizationId != null && nextOrganizationId.isNotEmpty) {
      _session!['organizationId'] = nextOrganizationId;
    }

    _session!['setupCompleted'] = client['setupCompleted'] == true;
    _session!['setupSelectedPlan'] = _normalizePlan(
      _readString(client, const ['setupSelectedPlan', 'selectedPlan']) ??
          _session!['setupSelectedPlan']?.toString() ??
          _session!['selectedPlan']?.toString(),
    );
    _session!['setupSelectedTier'] = _normalizeTier(
      _readString(client, const ['setupSelectedTier', 'selectedTier']) ??
          _session!['setupSelectedTier']?.toString() ??
          _session!['selectedTier']?.toString(),
    );
    _session!['commercialPlan'] = _normalizePlan(
      _readString(commercial, const ['service', 'lane']) ??
          _session!['commercialPlan']?.toString(),
    );
    _session!['commercialTier'] = _normalizeTier(
      _readString(commercial, const ['tier']) ??
          _session!['commercialTier']?.toString(),
    );
    _session!['subscriptionStatus'] =
        (_readString(client, const ['subscriptionStatus']) ??
                _session!['subscriptionStatus'] ??
                'none')
            .toLowerCase();
    _session!['setup'] = client['setup'];

    _ready = true;
    await _persist();
  }

  Future<void> setSubscriptionStatus(String status) async {
    _session ??= {};
    _session!['subscriptionStatus'] = status.trim().toLowerCase();
    await _persist();
  }

  Future<void> rememberSelection({String? plan, String? tier}) async {
    final normalizedPlan = _normalizePlan(plan);
    final normalizedTier = _normalizeTier(tier);

    _session ??= {};
    if (normalizedPlan != null && normalizedPlan.isNotEmpty) {
      _session!['setupSelectedPlan'] = normalizedPlan;
      _session!['selectedPlan'] = normalizedPlan;
    }
    if (normalizedTier != null && normalizedTier.isNotEmpty) {
      _session!['setupSelectedTier'] = normalizedTier;
      _session!['selectedTier'] = normalizedTier;
    }

    await _persist();
  }

  Future<void> rememberSelectedPlan(String? plan) async {
    await rememberSelection(plan: plan);
  }

  Future<void> rememberSelectedTier(String? tier) async {
    await rememberSelection(tier: tier);
  }

  Future<void> saveSetupDraft(Map<String, dynamic> draft) async {
    _session ??= {};
    _session!['setupDraft'] = draft;
    await _persist();
  }

  Future<void> clearSetupDraft() async {
    if (_session == null) return;
    _session!.remove('setupDraft');
    await _persist();
  }

  Future<void> clear() async {
    final key = _resolveKey(surface);
    _session = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);

    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _resolveKey(surface);

    await prefs.setString(key, jsonEncode(_session));
    notifyListeners();
  }
}

Map<String, dynamic> _mapOf(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

String? _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

String? _normalizePlan(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == 'opportunity' || text == 'revenue') return text;
  return null;
}

String? _normalizeTier(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == 'focused') return 'focused';
  if (text == 'multi' || text == 'multi-market' || text == 'multi_market') {
    return 'multi';
  }
  if (text == 'precision') return 'precision';
  return null;
}

String? _buildPlanDisplay({
  required String? plan,
  required String? tier,
}) {
  final normalizedPlan = _normalizePlan(plan);
  final normalizedTier = _normalizeTier(tier);

  if (normalizedPlan == null && normalizedTier == null) return null;
  if (normalizedPlan == null) return _humanizeTier(normalizedTier);
  if (normalizedTier == null) return _humanizePlan(normalizedPlan);

  return '${_humanizePlan(normalizedPlan)} · ${_humanizeTier(normalizedTier)}';
}

String _humanizePlan(String? value) {
  switch (_normalizePlan(value)) {
    case 'revenue':
      return 'Revenue';
    case 'opportunity':
      return 'Opportunity';
    default:
      return 'Not set';
  }
}

String _humanizeTier(String? value) {
  switch (_normalizeTier(value)) {
    case 'precision':
      return 'Precision';
    case 'multi':
      return 'Multi-Market';
    case 'focused':
      return 'Focused';
    default:
      return 'Not set';
  }
}
