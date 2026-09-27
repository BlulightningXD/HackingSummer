library auth_handler;

export 'models/auth_user.dart';
export 'services/google_auth_service.dart';
export 'storage/session_store.dart';

import 'models/auth_user.dart';
import 'services/google_auth_service.dart';
import 'storage/session_store.dart';

class AuthHandler {
  final GoogleAuthService _authService;

  GoogleAuthService get service => _authService;
  AuthUser? get currentUser => _authService.currentUser;
  bool get isAuthenticated => _authService.isAuthenticated;
  AuthStatus get status => _authService.status;

  Stream<AuthUser?> get onAuthStateChanged => _authService.onAuthStateChanged;
  Stream<AuthStatus> get onStatusChanged => _authService.onStatusChanged;

  AuthHandler._(this._authService);

  /// Initializes the AuthHandler with optional Google OAuth credentials and session store
  static Future<AuthHandler> initialize({
    String? googleClientId,
    String? googleApiKey,
    SessionStore? sessionStore,
  }) async {
    final service = GoogleAuthService(
      googleClientId: googleClientId,
      googleApiKey: googleApiKey,
      sessionStore: sessionStore,
    );

    // Try restoring existing login session
    await service.restoreSession();

    return AuthHandler._(service);
  }

  /// Builds Google OAuth 2.0 Web Authorization URL for real Google Login
  static String buildGoogleOAuthUrl({
    required String clientId,
    required String redirectUri,
    String state = 'auth_flow',
  }) {
    return GoogleAuthService.buildGoogleOAuthUrl(
      clientId: clientId,
      redirectUri: redirectUri,
      state: state,
    );
  }

  /// Sign in using Google OAuth Access Token
  Future<AuthUser?> signInWithAccessToken(String token) {
    return _authService.signInWithGoogleAccessToken(token);
  }

  /// Instant test login with a verified Google/Gmail identity
  Future<AuthUser> signInWithDevSandbox({
    String email = 'reporter.delhi@gmail.com',
    String displayName = 'Aarav Sharma (Community Reporter)',
    String? photoUrl,
  }) {
    return _authService.signInWithDevSandbox(
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
    );
  }

  /// Sign out
  Future<void> signOut() {
    return _authService.signOut();
  }

  /// Extracts verified reporter metadata for Teammate 2's community hazard & flood reporting system
  Map<String, dynamic> getReporterProvenance() {
    if (!isAuthenticated || currentUser == null) {
      throw StateError(
        'Authentication required: A verified Google/Gmail account is required to file community hazard reports.',
      );
    }
    return currentUser!.toReporterMetadata();
  }

  void dispose() {
    _authService.dispose();
  }
}
