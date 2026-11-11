import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyServerUrl = 'bagoo_server_url';
  static const String _keyToken = 'bagoo_auth_token';
  static const String _keyUserEmail = 'bagoo_user_email';
  static const String _keyUserName = 'bagoo_user_name';
  static const String _keyHubId = 'bagoo_hub_id';
  static const String _keyHubName = 'bagoo_hub_name';
  static const String _keyDemoMode = 'bagoo_demo_mode';
  static const String _keyContinuousScan = 'bagoo_continuous_scan';

  static const String defaultServerUrl = 'http://10.0.2.2:8000';
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;
  String? _token;

  StorageService(this._prefs, {FlutterSecureStorage? secureStorage})
    : _secure = secureStorage ?? const FlutterSecureStorage();

  static Future<StorageService> init() async {
    final service = StorageService(await SharedPreferences.getInstance());
    await service._prefs.remove(_keyToken);
    service._token = await service._secure.read(key: _keyToken);
    return service;
  }

  String getServerUrl() => _prefs.getString(_keyServerUrl) ?? defaultServerUrl;
  Future<void> setServerUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException(
        'Enter the server origin, including http:// or https://, without an account, path or query.',
      );
    }
    final normalized = uri.replace(path: '').toString();
    if (normalized != getServerUrl()) {
      await clearAuth();
      await _prefs.setString(_keyServerUrl, normalized);
    }
  }

  String? getToken() => _token;
  Future<void> setToken(String? token) async {
    if (token == null) {
      await _secure.delete(key: _keyToken);
    } else {
      await _secure.write(key: _keyToken, value: token);
    }
    _token = token;
  }

  String? getUserEmail() => _prefs.getString(_keyUserEmail);
  Future<void> setUserEmail(String? email) async {
    if (email == null) {
      await _prefs.remove(_keyUserEmail);
    } else {
      await _prefs.setString(_keyUserEmail, email);
    }
  }

  String? getUserName() => _prefs.getString(_keyUserName);
  Future<void> setUserName(String? name) async {
    if (name == null) {
      await _prefs.remove(_keyUserName);
    } else {
      await _prefs.setString(_keyUserName, name);
    }
  }

  int? getHubId() => _prefs.getInt(_keyHubId);
  Future<void> setHubId(int? hubId) async {
    if (hubId == null) {
      await _prefs.remove(_keyHubId);
    } else {
      await _prefs.setInt(_keyHubId, hubId);
    }
  }

  String getHubName() => _prefs.getString(_keyHubName) ?? 'No hub selected';
  Future<void> setHubName(String name) async =>
      _prefs.setString(_keyHubName, name);
  bool isDemoMode() => _prefs.getBool(_keyDemoMode) ?? false;
  Future<void> setDemoMode(bool value) async {
    if (value) await setToken(null);
    await _prefs.setBool(_keyDemoMode, value);
  }

  bool isContinuousScan() => _prefs.getBool(_keyContinuousScan) ?? true;
  Future<void> setContinuousScan(bool value) async =>
      _prefs.setBool(_keyContinuousScan, value);
  bool get isLoggedIn => (_token?.isNotEmpty ?? false) || isDemoMode();

  Future<void> clearAuth() async {
    await setToken(null);
    for (final key in [
      _keyToken,
      _keyUserEmail,
      _keyUserName,
      _keyDemoMode,
      _keyHubId,
      _keyHubName,
    ]) {
      await _prefs.remove(key);
    }
  }
}
