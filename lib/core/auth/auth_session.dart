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
    final value = ((_session?['setupSelectedPlan'] ?? _session?['selectedPlan']) as String?)?.trim();
    if (value == null || value.isEmpty) return null;
    return _normalizePlan(value);
  }

  String? get setupSelectedTier {
    final value = ((_session?['setupSelectedTier'] ?? _session?['selectedTier']) as String?)?.trim();
    if (value == null || value.isEmpty) return null;
    return _normalizeTier(value);
  }

  String? get selectedPlan => commercialPlan ?? setupSelectedPlan;

  String? get selectedTier => commercialTier ?? setupSelectedTier;

  String? get selectedPlanDisplay => _buildPlanDisplay(
    plan: commercialPlan ?? setupSelectedPlan,
    tier: commercialTier ?? setupSelectedTier,
  );

  String get subscriptionStatus => (_session?['subscriptionStatus'] as String?) ?? 'none';
  String get normalizedSubscriptionStatus => subscriptionStatus.trim().toLowerCase();

  Map<String, dynamic>? get setupDraft {
    final raw = _session?['setupDraft'];
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  String _resolveKey(String? surface) {
    return surface == 'operator' ? _operatorKey : _clientKey;
  }

  Future<void> init() async {
    if (_ready) return;

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
    final user = Map<String, dynamic>.from((payload['user'] as Map?) ?? const {});
    final workspace = Map<String, dynamic>.from((payload['workspace'] as Map?) ?? const {});
    final session = Map<String, dynamic>.from((payload['session'] as Map?) ?? const {});
    final setup = Map<String, dynamic>.from((payload['setup'] as Map?) ?? const {});
    final commercial = Map<String, dynamic>.from(
      ((payload['commercial'] ?? payload['subscription']) as Map?) ?? const {},
    );

    final newSurface = session['surface']?.toString() ?? previous['surface']?.toString() ?? 'client';
    final nextToken = payload['token']?.toString().trim();

    _session = {
      'token': (nextToken != null && nextToken.isNotEmpty)
          ? nextToken
          : previous['token']?.toString() ?? '',
      'surface': newSurface,
      'organizationId': workspace['organizationId']?.toString() ??
          session['organizationId']?.toString() ??
          previous['organizationId']?.toString() ??
          '',
      'clientId': session['clientId']?.toString() ?? previous['clientId']?.toString() ?? '',
      'memberRole': session['memberRole']?.toString() ?? previous['memberRole']?.toString() ?? '',
      'email': user['email']?.toString() ?? previous['email']?.toString() ?? '',
      'fullName': user['fullName']?.toString() ?? previous['fullName']?.toString() ?? '',
      'emailVerified': user.containsKey('emailVerified')
          ? user['emailVerified'] == true
          : previous['emailVerified'] == true,
      'workspaceName': workspace['displayName']?.toString() ?? previous['workspaceName']?.toString() ?? '',
      'setupCompleted': user['setupCompleted'] == true ||
          setup['setupCompleted'] == true ||
          previous['setupCompleted'] == true,
      'setupSelectedPlan': _normalizePlan(
        setup['selectedPlan']?.toString() ??
            user['selectedPlan']?.toString() ??
            previous['setupSelectedPlan']?.toString() ??
            previous['selectedPlan']?.toString(),
      ),
      'setupSelectedTier': _normalizeTier(
        setup['selectedTier']?.toString() ??
            user['selectedTier']?.toString() ??
            previous['setupSelectedTier']?.toString() ??
            previous['selectedTier']?.toString(),
      ),
      'commercialPlan': _normalizePlan(
        commercial['service']?.toString() ??
            commercial['lane']?.toString() ??
            previous['commercialPlan']?.toString(),
      ),
      'commercialTier': _normalizeTier(
        commercial['tier']?.toString() ??
            previous['commercialTier']?.toString(),
      ),
      'subscriptionStatus': (commercial['status']?.toString() ??
              user['subscriptionStatus']?.toString() ??
              setup['subscriptionStatus']?.toString() ??
              previous['subscriptionStatus']?.toString() ??
              'none')
          .toLowerCase(),
      'setup': setup.isNotEmpty ? setup : previous['setup'],
      'setupDraft': previous['setupDraft'],
    };

    await _persist();
  }

  Future<void> applyClientSetupResponse(Map<String, dynamic> payload) async {
    _session ??= {};
    final client = Map<String, dynamic>.from((payload['client'] as Map?) ?? const {});
    final commercial = Map<String, dynamic>.from((client['commercial'] as Map?) ?? const {});
    _session!['setupCompleted'] = client['setupCompleted'] == true;
    _session!['setupSelectedPlan'] = _normalizePlan(
      client['setupSelectedPlan']?.toString() ??
          client['selectedPlan']?.toString() ??
          _session!['setupSelectedPlan']?.toString() ??
          _session!['selectedPlan']?.toString(),
    );
    _session!['setupSelectedTier'] = _normalizeTier(
      client['setupSelectedTier']?.toString() ??
          client['selectedTier']?.toString() ??
          _session!['setupSelectedTier']?.toString() ??
          _session!['selectedTier']?.toString(),
    );
    _session!['commercialPlan'] = _normalizePlan(
      commercial['service']?.toString() ??
          commercial['lane']?.toString() ??
          _session!['commercialPlan']?.toString(),
    );
    _session!['commercialTier'] = _normalizeTier(
      commercial['tier']?.toString() ??
          _session!['commercialTier']?.toString(),
    );
    _session!['subscriptionStatus'] =
        (client['subscriptionStatus']?.toString() ?? _session!['subscriptionStatus'] ?? 'none')
            .toLowerCase();
    _session!['setup'] = client['setup'];

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

String? _normalizePlan(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == 'opportunity' || text == 'revenue') return text;
  return null;
}

String? _normalizeTier(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == 'focused') return 'focused';
  if (text == 'multi' || text == 'multi-market' || text == 'multi_market') return 'multi';
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
