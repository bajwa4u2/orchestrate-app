import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionController extends ChangeNotifier {
  AuthSessionController._();

  static final AuthSessionController instance = AuthSessionController._();
  static const _storageKey = 'orchestrate_auth_session_v1';

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
  String? get selectedPlan => (_session?['selectedPlan'] as String?)?.trim().isEmpty == true
      ? null
      : (_session?['selectedPlan'] as String?);
  String get subscriptionStatus => (_session?['subscriptionStatus'] as String?) ?? 'none';
  String get normalizedSubscriptionStatus => subscriptionStatus.trim().toLowerCase();

  Future<void> init() async {
    if (_ready) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        _session = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        _session = null;
      }
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

    _session = {
      'token': payload['token']?.toString() ?? '',
      'surface': session['surface']?.toString() ?? '',
      'organizationId': workspace['organizationId']?.toString() ?? '',
      'clientId': session['clientId']?.toString() ?? '',
      'memberRole': session['memberRole']?.toString() ?? '',
      'email': user['email']?.toString() ?? '',
      'fullName': user['fullName']?.toString() ?? '',
      'emailVerified': user['emailVerified'] == true,
      'workspaceName': workspace['displayName']?.toString() ?? '',
      'setupCompleted': user['setupCompleted'] == true ||
          setup['setupCompleted'] == true ||
          previous['setupCompleted'] == true,
      'selectedPlan': user['selectedPlan']?.toString() ??
          setup['selectedPlan']?.toString() ??
          previous['selectedPlan']?.toString(),
      'subscriptionStatus': (user['subscriptionStatus']?.toString() ??
              setup['subscriptionStatus']?.toString() ??
              previous['subscriptionStatus']?.toString() ??
              'none')
          .toLowerCase(),
      'setup': setup,
    };

    await _persist();
  }

  Future<void> applyClientSetupResponse(Map<String, dynamic> payload) async {
    _session ??= {};
    final client = Map<String, dynamic>.from((payload['client'] as Map?) ?? const {});
    _session!['setupCompleted'] = client['setupCompleted'] == true;
    _session!['selectedPlan'] = client['selectedPlan']?.toString() ?? _session!['selectedPlan'];
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

  Future<void> rememberSelectedPlan(String? plan) async {
    final normalized = plan?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return;

    _session ??= {};
    _session!['selectedPlan'] = normalized;

    await _persist();
  }

  Future<void> clear() async {
    _session = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_session));
    notifyListeners();
  }
}
