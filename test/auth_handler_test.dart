import 'package:test/test.dart';
import 'package:auth_handler/auth_handler.dart';

void main() {
  group('AuthHandler - Google Identity & Reporter Provenance', () {
    late AuthHandler auth;

    setUp(() async {
      auth = await AuthHandler.initialize();
    });

    tearDown(() {
      auth.dispose();
    });

    test('Initializes as unauthenticated when session is empty', () {
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
      expect(auth.status, equals(AuthStatus.unauthenticated));
    });

    test('Allows login with valid Gmail account and updates authenticated state', () async {
      final user = await auth.signInWithDevSandbox(
        email: 'rahul.delhi.reporter@gmail.com',
        displayName: 'Rahul Verma',
      );

      expect(auth.isAuthenticated, isTrue);
      expect(auth.status, equals(AuthStatus.authenticated));
      expect(user.email, equals('rahul.delhi.reporter@gmail.com'));
      expect(user.displayName, equals('Rahul Verma'));
      expect(user.isVerifiedEmail, isTrue);
    });

    test('Rejects non-Google email accounts strictly', () async {
      expect(
        () => auth.signInWithDevSandbox(
          email: 'unauthorized.user@yahoo.com',
          displayName: 'Yahoo User',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(auth.isAuthenticated, isFalse);
    });

    test('Generates verified reporter metadata for Teammate 2 hazard reports', () async {
      await auth.signInWithDevSandbox(
        email: 'ananya.civic@gmail.com',
        displayName: 'Ananya Sen',
      );

      final metadata = auth.getReporterProvenance();
      expect(metadata['reporter_email'], equals('ananya.civic@gmail.com'));
      expect(metadata['reporter_name'], equals('Ananya Sen'));
      expect(metadata['verified_account'], isTrue);
      expect(metadata['auth_provider'], equals('google'));
      expect(metadata['auth_timestamp'], isNotNull);
    });

    test('Throws StateError if attempting to get reporter provenance when logged out', () {
      expect(
        () => auth.getReporterProvenance(),
        throwsA(isA<StateError>()),
      );
    });

    test('Signs out cleanly and clears session', () async {
      await auth.signInWithDevSandbox();
      expect(auth.isAuthenticated, isTrue);

      await auth.signOut();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
      expect(auth.status, equals(AuthStatus.unauthenticated));
    });

    test('Restores session from SessionStore upon app restart', () async {
      final sharedStore = InMemorySessionStore();

      // First session: User logs in
      final firstAuth = await AuthHandler.initialize(sessionStore: sharedStore);
      await firstAuth.signInWithDevSandbox(
        email: 'persisted.reporter@gmail.com',
        displayName: 'Priya Nair',
      );
      firstAuth.dispose();

      // Second session (App reboot): automatically restores user
      final secondAuth = await AuthHandler.initialize(sessionStore: sharedStore);
      expect(secondAuth.isAuthenticated, isTrue);
      expect(secondAuth.currentUser?.email, equals('persisted.reporter@gmail.com'));
      expect(secondAuth.currentUser?.displayName, equals('Priya Nair'));
      secondAuth.dispose();
    });
  });
}
