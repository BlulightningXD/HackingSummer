import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/auth_user.dart';
import '../storage/session_store.dart';

class GoogleAuthService {
  final String? googleClientId;
  final String? googleApiKey;
  final SessionStore sessionStore;

  AuthUser? _currentUser;
  AuthStatus _status = AuthStatus.unauthenticated;
  String? _lastError;

  final _userStreamController = StreamController<AuthUser?>.broadcast();
  final _statusStreamController = StreamController<AuthStatus>.broadcast();

  AuthUser? get currentUser => _currentUser;
  AuthStatus get status => _status;
  bool get isAuthenticated => _currentUser != null && _status == AuthStatus.authenticated;
  String? get lastError => _lastError;

  Stream<AuthUser?> get onAuthStateChanged => _userStreamController.stream;
  Stream<AuthStatus> get onStatusChanged => _statusStreamController.stream;

  GoogleAuthService({
    this.googleClientId,
    this.googleApiKey,
    SessionStore? sessionStore,
  }) : sessionStore = sessionStore ?? InMemorySessionStore();

  /// Attempts to restore a previous Google login session from local storage
  Future<AuthUser?> restoreSession() async {
    _setStatus(AuthStatus.authenticating);
    try {
      final savedUser = await sessionStore.loadUser();
      if (savedUser != null) {
        _currentUser = savedUser;
        _setStatus(AuthStatus.authenticated);
        _userStreamController.add(_currentUser);
        return savedUser;
      }
    } catch (_) {
      // Ignore storage read error on initial start
    }
    _setStatus(AuthStatus.unauthenticated);
    _userStreamController.add(null);
    return null;
  }

  /// Exchanges and verifies a Google OAuth Access Token / ID Token against Google's UserInfo API
  Future<AuthUser?> signInWithGoogleAccessToken(String accessToken) async {
    _setStatus(AuthStatus.authenticating);
    _lastError = null;

    try {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final email = (data['email'] as String?) ?? '';

        // Strict Google / Gmail Domain Enforcement
        if (!_isAllowedGoogleDomain(email)) {
          _lastError = 'Access Denied: Account ($email) is not a permitted Google/Gmail address.';
          _setStatus(AuthStatus.error);
          throw ArgumentError('Only @gmail.com and @google.com accounts are permitted.');
        }

        final user = AuthUser(
          id: data['sub'] as String,
          email: email,
          displayName: (data['name'] as String?) ?? 'Google User',
          photoUrl: data['picture'] as String?,
          accessToken: accessToken,
          authenticatedAt: DateTime.now(),
          isVerifiedEmail: data['email_verified'] == true,
        );

        await sessionStore.saveUser(user);
        _currentUser = user;
        _setStatus(AuthStatus.authenticated);
        _userStreamController.add(user);
        return user;
      } else {
        _lastError = 'Google OAuth verification failed: ${response.statusCode}';
        _setStatus(AuthStatus.error);
        return null;
      }
    } catch (e) {
      _lastError = 'Network error contacting Google OAuth endpoint: $e';
      _setStatus(AuthStatus.error);
      rethrow;
    }
  }

  /// Builds the Google OAuth 2.0 Web Authorization URL for browser popup or redirect
  static String buildGoogleOAuthUrl({
    required String clientId,
    required String redirectUri,
    String state = 'auth_flow',
  }) {
    final encodedRedirect = Uri.encodeComponent(redirectUri);
    const scope = 'openid%20profile%20email';
    return 'https://accounts.google.com/o/oauth2/v2/auth'
        '?client_id=$clientId'
        '&redirect_uri=$encodedRedirect'
        '&response_type=token'
        '&scope=$scope'
        '&include_granted_scopes=true'
        '&state=$state'
        '&prompt=select_account';
  }

  bool _isAllowedGoogleDomain(String email) {
    final normalized = email.trim().toLowerCase();
    return normalized.endsWith('@gmail.com') || normalized.endsWith('@google.com');
  }

  /// Instant test & sandbox login using a simulated Google identity
  /// Perfect for developers to test flood/hazard reporting before Google Cloud Console keys are setup
  Future<AuthUser> signInWithDevSandbox({
    String email = 'reporter.delhi@gmail.com',
    String displayName = 'Aarav Sharma (Community Reporter)',
    String? photoUrl = 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&q=80',
  }) async {
    _setStatus(AuthStatus.authenticating);

    // Validate that the email is a google/gmail account as required
    if (!email.toLowerCase().endsWith('@gmail.com') && !email.toLowerCase().endsWith('@google.com')) {
      _lastError = 'Only Google / Gmail accounts are permitted.';
      _setStatus(AuthStatus.error);
      throw ArgumentError('Only Google / Gmail accounts are permitted for reporting.');
    }

    final user = AuthUser(
      id: 'google_sub_dev_${email.replaceAll('@', '_').replaceAll('.', '_')}',
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      idToken: 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}',
      authenticatedAt: DateTime.now(),
      isVerifiedEmail: true,
    );

    await sessionStore.saveUser(user);
    _currentUser = user;
    _setStatus(AuthStatus.authenticated);
    _userStreamController.add(user);
    return user;
  }

  /// Signs out of the Google session and clears stored credentials
  Future<void> signOut() async {
    await sessionStore.clearUser();
    _currentUser = null;
    _setStatus(AuthStatus.unauthenticated);
    _userStreamController.add(null);
  }

  void _setStatus(AuthStatus newStatus) {
    _status = newStatus;
    _statusStreamController.add(newStatus);
  }

  void dispose() {
    _userStreamController.close();
    _statusStreamController.close();
  }
}
