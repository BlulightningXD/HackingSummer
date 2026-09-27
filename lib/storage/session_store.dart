import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_user.dart';
abstract class SessionStore {
  Future<void> saveUser(AuthUser user);
  Future<AuthUser?> loadUser();
  Future<void> clearUser();
}

class InMemorySessionStore implements SessionStore {
  AuthUser? _cachedUser;

  @override
  Future<void> saveUser(AuthUser user) async {
    _cachedUser = user;
  }

  @override
  Future<AuthUser?> loadUser() async {
    return _cachedUser;
  }

  @override
  Future<void> clearUser() async {
    _cachedUser = null;
  }
}

class SharedPrefsSessionStore implements SessionStore {
  static const String _key = 'auth_user_session';

  @override
  Future<void> saveUser(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(user.toMap()));
  }

  @override
  Future<AuthUser?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data != null) {
      try {
        final map = jsonDecode(data) as Map<String, dynamic>;
        return AuthUser.fromMap(map);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
