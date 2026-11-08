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

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  String getServerUrl() => _prefs.getString(_keyServerUrl) ?? defaultServerUrl;
  Future<void> setServerUrl(String url) => _prefs.setString(_keyServerUrl, url.trim());

  String? getToken() => _prefs.getString(_keyToken);
  Future<void> setToken(String? token) async {
    if (token == null) {
      await _prefs.remove(_keyToken);
    } else {
      await _prefs.setString(_keyToken, token);
    }
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

  String getHubName() => _prefs.getString(_keyHubName) ?? 'Laguna Mother Hub';
  Future<void> setHubName(String name) => _prefs.setString(_keyHubName, name);

  bool isDemoMode() => _prefs.getBool(_keyDemoMode) ?? false;
  Future<void> setDemoMode(bool value) => _prefs.setBool(_keyDemoMode, value);

  bool isContinuousScan() => _prefs.getBool(_keyContinuousScan) ?? true;
  Future<void> setContinuousScan(bool value) => _prefs.setBool(_keyContinuousScan, value);

  bool get isLoggedIn => getToken() != null || isDemoMode();

  Future<void> clearAuth() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyUserEmail);
    await _prefs.remove(_keyUserName);
    await _prefs.remove(_keyDemoMode);
  }
}
