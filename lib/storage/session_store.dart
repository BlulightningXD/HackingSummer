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
