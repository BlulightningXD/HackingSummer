enum AuthStatus {
  unauthenticated,
  authenticating,
  authenticated,
  error,
}

class AuthUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? idToken;
  final String? accessToken;
  final DateTime authenticatedAt;
  final bool isVerifiedEmail;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.idToken,
    this.accessToken,
    required this.authenticatedAt,
    this.isVerifiedEmail = true,
  });

  /// Returns a clean provenance payload for attaching to community flood/hazard reports
  Map<String, dynamic> toReporterMetadata() {
    return {
      'reporter_id': id,
      'reporter_email': email,
      'reporter_name': displayName,
      'reporter_photo': photoUrl,
      'verified_account': isVerifiedEmail,
      'auth_provider': 'google',
      'auth_timestamp': authenticatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'id_token': idToken,
      'access_token': accessToken,
      'authenticated_at': authenticatedAt.millisecondsSinceEpoch,
      'is_verified_email': isVerifiedEmail ? 1 : 0,
    };
  }

  factory AuthUser.fromMap(Map<String, dynamic> map) {
    return AuthUser(
      id: map['id'] as String,
      email: map['email'] as String,
      displayName: map['display_name'] as String,
      photoUrl: map['photo_url'] as String?,
      idToken: map['id_token'] as String?,
      accessToken: map['access_token'] as String?,
      authenticatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['authenticated_at'] as int,
      ),
      isVerifiedEmail: (map['is_verified_email'] as int? ?? 1) == 1,
    );
  }

  AuthUser copyWith({
    String? displayName,
    String? photoUrl,
    String? idToken,
    String? accessToken,
  }) {
    return AuthUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      idToken: idToken ?? this.idToken,
      accessToken: accessToken ?? this.accessToken,
      authenticatedAt: authenticatedAt,
      isVerifiedEmail: isVerifiedEmail,
    );
  }

  @override
  String toString() => 'AuthUser($displayName, $email)';
}
