// Tests for the Gazu authentication UI.
//
// These tests exercise screens and utilities without a real Firebase
// connection, using lightweight fake AuthService and FirestoreService
// implementations.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gazu/models/user_model.dart';
import 'package:gazu/screens/auth/email_verification_screen.dart';
import 'package:gazu/screens/auth/login_screen.dart';
import 'package:gazu/screens/auth/register_screen.dart';
import 'package:gazu/screens/auth/forgot_password_screen.dart';
import 'package:gazu/services/auth_service.dart';
import 'package:gazu/services/firestore_service.dart';
import 'package:gazu/utils/validators.dart';
import 'package:gazu/widgets/password_strength_indicator.dart';

// ---------------------------------------------------------------------------
// Fake services (no Firebase initialisation required)
// ---------------------------------------------------------------------------

/// Fake [FirestoreService] that overrides all methods to avoid Firestore calls.
class _FakeFirestoreService extends FirestoreService {
  _FakeFirestoreService() : super();

  @override
  Future<void> createUser(GazuUser user) async {}

  @override
  Future<GazuUser?> getUser(String uid) async => null;

  @override
  Future<void> updateUser(String uid,
      {String? displayName, String? photoUrl}) async {}

  @override
  Stream<GazuUser?> userStream(String uid) => Stream.value(GazuUser(
        uid: uid,
        email: 'test@test.com',
        displayName: 'Test User',
        createdAt: DateTime(2024),
      ));

  @override
  Future<bool> isLockedOut(String email) async => false;

  @override
  Future<void> recordFailedLoginAttempt(String email) async {}

  @override
  Future<void> resetLoginAttempts(String email) async {}
}

/// Fake [AuthService] that overrides all auth methods to avoid Firebase calls.
class _FakeAuthService extends AuthService {
  final AuthResult nextResult;

  _FakeAuthService({this.nextResult = AuthResult.success})
      : super(firestoreService: _FakeFirestoreService());

  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      nextResult;

  @override
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    UserRole role = UserRole.user,
  }) async =>
      nextResult;

  @override
  Future<AuthResult> sendPasswordResetEmail(String email) async => nextResult;

  @override
  Future<AuthResult> signInWithGoogle() async => nextResult;

  @override
  Future<AuthResult> signInWithApple() async => nextResult;

  @override
  Future<AuthResult> updateProfile({
    required String displayName,
    String? photoUrl,
  }) async =>
      nextResult;

  @override
  Future<AuthResult> sendEmailVerification() async => nextResult;

  @override
  Future<bool> reloadAndCheckEmailVerified() async =>
      nextResult == AuthResult.success;

  @override
  Future<void> signOut() async {}
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _wrap(Widget child, {_FakeAuthService? auth}) {
  return MultiProvider(
    providers: [
      Provider<FirestoreService>.value(value: _FakeFirestoreService()),
      Provider<AuthService>.value(value: auth ?? _FakeAuthService()),
    ],
    child: MaterialApp(home: child),
  );
}

// ===========================================================================
// Tests
// ===========================================================================

void main() {
  // -------------------------------------------------------------------------
  // Validator unit tests
  // -------------------------------------------------------------------------

  group('Validators.email', () {
    test('accepts valid email', () {
      expect(Validators.email('user@example.com'), isNull);
    });

    test('rejects empty value', () {
      expect(Validators.email(''), isNotNull);
    });

    test('rejects email without @', () {
      expect(Validators.email('notanemail'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('accepts strong password', () {
      expect(Validators.password('Abcdef12'), isNull);
    });

    test('rejects too-short password', () {
      expect(Validators.password('Ab1'), isNotNull);
    });

    test('rejects password with no digits', () {
      expect(Validators.password('AbcdefGh'), isNotNull);
    });

    test('rejects password with no letters', () {
      expect(Validators.password('12345678'), isNotNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('returns null when passwords match', () {
      expect(Validators.confirmPassword('Abcdef12', 'Abcdef12'), isNull);
    });

    test('returns error when passwords differ', () {
      expect(Validators.confirmPassword('Abcdef12', 'Different1'), isNotNull);
    });
  });

  group('Validators.displayName', () {
    test('accepts a valid name', () {
      expect(Validators.displayName('Ana García'), isNull);
    });

    test('rejects empty name', () {
      expect(Validators.displayName(''), isNotNull);
    });

    test('rejects single-character name', () {
      expect(Validators.displayName('A'), isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // UserRole tests
  // -------------------------------------------------------------------------

  group('UserRole', () {
    test('fromString returns user by default for unknown values', () {
      expect(UserRoleX.fromString(null), UserRole.user);
      expect(UserRoleX.fromString('unknown_role'), UserRole.user);
    });

    test('fromString returns staff', () {
      expect(UserRoleX.fromString('staff'), UserRole.staff);
    });

    test('fromString returns business', () {
      expect(UserRoleX.fromString('business'), UserRole.business);
    });

    test('name property returns correct strings', () {
      expect(UserRole.user.name, 'user');
      expect(UserRole.staff.name, 'staff');
      expect(UserRole.business.name, 'business');
    });
  });

  // -------------------------------------------------------------------------
  // GazuUser model tests
  // -------------------------------------------------------------------------

  group('GazuUser', () {
    final base = GazuUser(
      uid: 'uid1',
      email: 'a@b.com',
      displayName: 'Alice',
      createdAt: DateTime(2024),
    );

    test('copyWith changes displayName', () {
      final updated = base.copyWith(displayName: 'Bob');
      expect(updated.displayName, 'Bob');
      expect(updated.uid, base.uid);
      expect(updated.email, base.email);
    });

    test('copyWith changes role', () {
      final updated = base.copyWith(role: UserRole.staff);
      expect(updated.role, UserRole.staff);
    });

    test('toFirestore map contains expected keys', () {
      final map = base.toFirestore();
      expect(map['email'], 'a@b.com');
      expect(map['displayName'], 'Alice');
      expect(map['role'], 'user');
      expect(map['isActive'], true);
    });
  });

  // -------------------------------------------------------------------------
  // authResultMessage tests
  // -------------------------------------------------------------------------

  group('authResultMessage', () {
    test('success returns non-empty string', () {
      expect(authResultMessage(AuthResult.success), isNotEmpty);
    });

    test('canceled returns empty string (silent)', () {
      expect(authResultMessage(AuthResult.canceled), isEmpty);
    });

    test('emailAlreadyInUse returns non-empty string', () {
      expect(authResultMessage(AuthResult.emailAlreadyInUse), isNotEmpty);
    });

    test('emailNotVerified mentions verification', () {
      expect(authResultMessage(AuthResult.emailNotVerified),
          contains('verificar'));
    });

    test('lockedOut message mentions minutes', () {
      expect(authResultMessage(AuthResult.lockedOut), contains('minutos'));
    });
  });

  // -------------------------------------------------------------------------
  // PasswordStrengthIndicator tests
  // -------------------------------------------------------------------------

  group('evaluatePasswordStrength', () {
    test('empty password is empty', () {
      expect(evaluatePasswordStrength(''), PasswordStrength.empty);
    });

    test('short simple password is weak', () {
      expect(evaluatePasswordStrength('abc'), PasswordStrength.weak);
    });

    test('mixed-case + digits is at least medium', () {
      final s = evaluatePasswordStrength('Abcdef12');
      expect(s, anyOf(PasswordStrength.medium, PasswordStrength.strong));
    });

    test('all criteria met is strong', () {
      expect(evaluatePasswordStrength('Abcdef1!'), PasswordStrength.strong);
    });
  });

  testWidgets('PasswordStrengthIndicator renders nothing for empty password',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
          home: Scaffold(
              body: PasswordStrengthIndicator(password: ''))),
    );
    expect(find.text('Seguridad: Débil'), findsNothing);
  });

  testWidgets('PasswordStrengthIndicator shows Fuerte for strong password',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
          home: Scaffold(
              body: PasswordStrengthIndicator(password: 'Abcdef1!'))),
    );
    expect(find.text('Seguridad: Fuerte'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // LoginScreen widget tests
  // -------------------------------------------------------------------------

  group('LoginScreen', () {
    testWidgets('renders email field, password field and login button',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(find.byKey(const Key('loginEmailField')), findsOneWidget);
      expect(find.byKey(const Key('loginPasswordField')), findsOneWidget);
      expect(find.byKey(const Key('loginButton')), findsOneWidget);
    });

    testWidgets('shows social sign-in buttons', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(find.byKey(const Key('googleSignInButton')), findsOneWidget);
      expect(find.byKey(const Key('appleSignInButton')), findsOneWidget);
    });

    testWidgets('shows validation error when email is empty', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.tap(find.byKey(const Key('loginButton')));
      await tester.pump();
      expect(find.text('El correo es obligatorio'), findsOneWidget);
    });

    testWidgets('shows error snackbar on wrong-password result', (tester) async {
      final auth = _FakeAuthService(nextResult: AuthResult.wrongPassword);
      await tester.pumpWidget(_wrap(const LoginScreen(), auth: auth));

      await tester.enterText(
          find.byKey(const Key('loginEmailField')), 'user@test.com');
      await tester.enterText(
          find.byKey(const Key('loginPasswordField')), 'BadPass1');
      await tester.tap(find.byKey(const Key('loginButton')));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('does NOT show snackbar when Google sign-in is canceled',
        (tester) async {
      final auth = _FakeAuthService(nextResult: AuthResult.canceled);
      await tester.pumpWidget(_wrap(const LoginScreen(), auth: auth));

      await tester.tap(find.byKey(const Key('googleSignInButton')));
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('navigates to EmailVerificationScreen on emailNotVerified',
        (tester) async {
      final auth = _FakeAuthService(nextResult: AuthResult.emailNotVerified);
      await tester.pumpWidget(_wrap(const LoginScreen(), auth: auth));

      await tester.enterText(
          find.byKey(const Key('loginEmailField')), 'user@test.com');
      await tester.enterText(
          find.byKey(const Key('loginPasswordField')), 'Password1');
      await tester.tap(find.byKey(const Key('loginButton')));
      await tester.pumpAndSettle();

      expect(find.byType(EmailVerificationScreen), findsOneWidget);
    });

    testWidgets('navigates to RegisterScreen on tap', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.tap(find.byKey(const Key('goToRegisterButton')));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // RegisterScreen widget tests
  // -------------------------------------------------------------------------

  group('RegisterScreen', () {
    testWidgets('renders all form fields and strength indicator placeholder',
        (tester) async {
      await tester.pumpWidget(_wrap(const RegisterScreen()));
      expect(find.byKey(const Key('registerNameField')), findsOneWidget);
      expect(find.byKey(const Key('registerEmailField')), findsOneWidget);
      expect(find.byKey(const Key('registerPasswordField')), findsOneWidget);
      expect(find.byKey(const Key('registerConfirmPasswordField')),
          findsOneWidget);
      expect(find.byKey(const Key('registerButton')), findsOneWidget);
    });

    testWidgets('shows strength indicator after typing password', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterScreen()));
      await tester.enterText(
          find.byKey(const Key('registerPasswordField')), 'Abcdef1!');
      await tester.pump();
      expect(find.byType(PasswordStrengthIndicator), findsOneWidget);
      expect(find.text('Seguridad: Fuerte'), findsOneWidget);
    });

    testWidgets('navigates to EmailVerificationScreen after success',
        (tester) async {
      final auth = _FakeAuthService(nextResult: AuthResult.success);
      await tester.pumpWidget(_wrap(const RegisterScreen(), auth: auth));
      await tester.enterText(
          find.byKey(const Key('registerNameField')), 'Test User');
      await tester.enterText(
          find.byKey(const Key('registerEmailField')), 'test@test.com');
      await tester.enterText(
          find.byKey(const Key('registerPasswordField')), 'Password1');
      await tester.enterText(
          find.byKey(const Key('registerConfirmPasswordField')), 'Password1');
      await tester.tap(find.byKey(const Key('registerButton')));
      await tester.pumpAndSettle();
      expect(find.byType(EmailVerificationScreen), findsOneWidget);
    });

    testWidgets('shows mismatch error when passwords differ', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterScreen()));
      await tester.enterText(
          find.byKey(const Key('registerNameField')), 'Test User');
      await tester.enterText(
          find.byKey(const Key('registerEmailField')), 'test@test.com');
      await tester.enterText(
          find.byKey(const Key('registerPasswordField')), 'Password1');
      await tester.enterText(
          find.byKey(const Key('registerConfirmPasswordField')), 'Other1234');
      await tester.tap(find.byKey(const Key('registerButton')));
      await tester.pump();
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });

    testWidgets('shows snackbar on duplicate email', (tester) async {
      final auth =
          _FakeAuthService(nextResult: AuthResult.emailAlreadyInUse);
      await tester.pumpWidget(_wrap(const RegisterScreen(), auth: auth));
      await tester.enterText(
          find.byKey(const Key('registerNameField')), 'Test User');
      await tester.enterText(
          find.byKey(const Key('registerEmailField')), 'dup@test.com');
      await tester.enterText(
          find.byKey(const Key('registerPasswordField')), 'Password1');
      await tester.enterText(
          find.byKey(const Key('registerConfirmPasswordField')), 'Password1');
      await tester.tap(find.byKey(const Key('registerButton')));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // ForgotPasswordScreen widget tests
  // -------------------------------------------------------------------------

  group('ForgotPasswordScreen', () {
    testWidgets('renders email field and submit button', (tester) async {
      await tester.pumpWidget(_wrap(const ForgotPasswordScreen()));
      expect(
          find.byKey(const Key('forgotPasswordEmailField')), findsOneWidget);
      expect(find.byKey(const Key('sendResetEmailButton')), findsOneWidget);
    });

    testWidgets('shows validation error on empty email', (tester) async {
      await tester.pumpWidget(_wrap(const ForgotPasswordScreen()));
      await tester.tap(find.byKey(const Key('sendResetEmailButton')));
      await tester.pump();
      expect(find.text('El correo es obligatorio'), findsOneWidget);
    });

    testWidgets('shows success view after email is sent', (tester) async {
      final auth = _FakeAuthService(nextResult: AuthResult.success);
      await tester.pumpWidget(_wrap(const ForgotPasswordScreen(), auth: auth));
      await tester.enterText(
          find.byKey(const Key('forgotPasswordEmailField')), 'user@test.com');
      await tester.tap(find.byKey(const Key('sendResetEmailButton')));
      await tester.pump();
      expect(find.text('¡Correo enviado!'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // EmailVerificationScreen widget tests
  // -------------------------------------------------------------------------

  group('EmailVerificationScreen', () {
    testWidgets('renders verification buttons', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmailVerificationScreen(email: 'test@test.com'),
      ));
      expect(find.byKey(const Key('checkVerificationButton')), findsOneWidget);
      expect(
          find.byKey(const Key('resendVerificationButton')), findsOneWidget);
    });

    testWidgets('shows unverified snackbar when not yet verified',
        (tester) async {
      final auth = _FakeAuthService(nextResult: AuthResult.unknown);
      await tester.pumpWidget(_wrap(
        const EmailVerificationScreen(email: 'test@test.com'),
        auth: auth,
      ));
      await tester.tap(find.byKey(const Key('checkVerificationButton')));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
