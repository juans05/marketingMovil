import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  StorageService._(this._prefs);

  final SharedPreferences _prefs;
  static const _userKey = 'vidalis_user';
  static const _apiUrlKey = 'vidalis_api_url';

  static Future<StorageService> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  // User
  Future<void> saveUser(UserModel user) async {
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  UserModel? getUser() {
    final raw = _prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUser() async {
    await _prefs.remove(_userKey);
  }

  bool get isLoggedIn => _prefs.containsKey(_userKey);

  // API URL
  String get apiUrl =>
      _prefs.getString(_apiUrlKey) ??
      'https://backend-vidalis-production.up.railway.app';

  Future<void> saveApiUrl(String url) async {
    await _prefs.setString(_apiUrlKey, url);
  }
}
