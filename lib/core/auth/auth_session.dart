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
    final user = Map<String, dynamic>.from((payload['user'] as Map?) ?? const {});
    final workspace = Map<String, dynamic>.from((payload['workspace'] as Map?) ?? const {});
    final session = Map<String, dynamic>.from((payload['session'] as Map?) ?? const {});
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
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_session));
    notifyListeners();
  }

  Future<void> clear() async {
    _session = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }
}
