import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'firestore_service.dart';

/// Possible outcomes of an authentication call.
enum AuthResult {
  success,
  canceled,
  emailNotVerified,
  emailAlreadyInUse,
  wrongPassword,
  userNotFound,
  userDisabled,
  tooManyRequests,
  lockedOut,
  networkError,
  unknown,
}

/// Authentication service wrapping Firebase Auth.
///
/// All public methods return [AuthResult] instead of throwing so that
/// callers can surface user-friendly messages without exposing internal error
/// details.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirestoreService? firestoreService,
  })  : _injectedAuth = auth,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _firestoreService = firestoreService ?? FirestoreService();

  final FirebaseAuth? _injectedAuth;
  final GoogleSignIn _googleSignIn;
  final FirestoreService _firestoreService;

  /// Returns the injected FirebaseAuth or the default singleton.
  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;

  /// The currently signed-in Firebase user, or `null`.
  User? get currentUser => _auth.currentUser;

  /// Stream of auth-state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // Email / Password
  // ---------------------------------------------------------------------------

  /// Registers a new user with [email] and [password].
  ///
  /// On success the user is persisted in Firestore and a verification email
  /// is sent to their address.
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    UserRole role = UserRole.user,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(displayName.trim());

      // Send email verification
      await credential.user?.sendEmailVerification();

      final gazuUser = GazuUser(
        uid: credential.user!.uid,
        email: email.trim(),
        displayName: displayName.trim(),
        role: role,
        createdAt: DateTime.now(),
      );
      await _firestoreService.createUser(gazuUser);
      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseAuthException(e);
    } catch (_) {
      return AuthResult.unknown;
    }
  }

  /// Signs in an existing user with [email] and [password].
  ///
  /// Checks for client-side lockout before calling Firebase.
  /// After a successful sign-in, blocks unverified accounts.
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final locked = await _firestoreService.isLockedOut(email);
      if (locked) return AuthResult.lockedOut;

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Block sign-in if the user has not verified their email address.
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await _auth.signOut();
        return AuthResult.emailNotVerified;
      }

      await _firestoreService.resetLoginAttempts(email);
      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'user-not-found') {
        await _firestoreService.recordFailedLoginAttempt(email);
      }
      return _mapFirebaseAuthException(e);
    } catch (_) {
      return AuthResult.unknown;
    }
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------

  /// Signs in (or registers) the user via Google.
  ///
  /// Returns [AuthResult.canceled] when the user dismisses the picker.
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return AuthResult.canceled;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _ensureFirestoreUser(userCredential.user!);
      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseAuthException(e);
    } catch (_) {
      return AuthResult.unknown;
    }
  }

  // ---------------------------------------------------------------------------
  // Apple Sign-In
  // ---------------------------------------------------------------------------

  /// Signs in (or registers) the user via Apple.
  ///
  /// Returns [AuthResult.canceled] when the user dismisses the picker.
  Future<AuthResult> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      await _ensureFirestoreUser(
        userCredential.user!,
        displayNameOverride:
            [appleCredential.givenName, appleCredential.familyName]
                .where((s) => s != null && s.isNotEmpty)
                .join(' '),
      );
      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseAuthException(e);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return AuthResult.canceled;
      return AuthResult.unknown;
    } catch (_) {
      return AuthResult.unknown;
    }
  }

  // ---------------------------------------------------------------------------
  // Password recovery
  // ---------------------------------------------------------------------------

  /// Sends a password-reset email to [email].
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseAuthException(e);
    } catch (_) {
      return AuthResult.unknown;
    }
  }

  // ---------------------------------------------------------------------------
  // Email verification
  // ---------------------------------------------------------------------------

  /// Sends an email-verification message to the currently signed-in user.
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return AuthResult.unknown;
      await user.sendEmailVerification();
      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseAuthException(e);
    } catch (_) {
      return AuthResult.unknown;
    }
  }

  /// Reloads the Firebase user and returns whether their email is verified.
  Future<bool> reloadAndCheckEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Profile update
  // ---------------------------------------------------------------------------

  /// Updates the current user's [displayName] and/or [photoUrl] in both
  /// Firebase Auth and Firestore.
  Future<AuthResult> updateProfile({
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return AuthResult.unknown;

      await user.updateDisplayName(displayName.trim());
      if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        await user.updatePhotoURL(photoUrl.trim());
      }

      await _firestoreService.updateUser(
        user.uid,
        displayName: displayName.trim(),
        photoUrl: photoUrl?.trim().isNotEmpty == true ? photoUrl!.trim() : null,
      );
      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseAuthException(e);
    } catch (_) {
      return AuthResult.unknown;
    }
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  /// Signs out the current user from Firebase and Google (if applicable).
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Creates a Firestore user document if one does not already exist.
  Future<void> _ensureFirestoreUser(
    User firebaseUser, {
    String? displayNameOverride,
  }) async {
    final existing = await _firestoreService.getUser(firebaseUser.uid);
    if (existing == null) {
      final gazuUser = GazuUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: displayNameOverride?.isNotEmpty == true
            ? displayNameOverride!
            : (firebaseUser.displayName ?? 'Usuario'),
        photoUrl: firebaseUser.photoURL,
        createdAt: DateTime.now(),
      );
      await _firestoreService.createUser(gazuUser);
    }
  }

  /// Maps a [FirebaseAuthException] to a typed [AuthResult].
  AuthResult _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return AuthResult.emailAlreadyInUse;
      case 'wrong-password':
      case 'invalid-credential':
        return AuthResult.wrongPassword;
      case 'user-not-found':
        return AuthResult.userNotFound;
      case 'user-disabled':
        return AuthResult.userDisabled;
      case 'too-many-requests':
        return AuthResult.tooManyRequests;
      case 'network-request-failed':
        return AuthResult.networkError;
      default:
        return AuthResult.unknown;
    }
  }
}

/// Returns a localized error message for an [AuthResult].
String authResultMessage(AuthResult result) {
  switch (result) {
    case AuthResult.success:
      return 'Éxito';
    case AuthResult.canceled:
      return '';
    case AuthResult.emailNotVerified:
      return 'Debes verificar tu correo antes de iniciar sesión. '
          'Revisa tu bandeja de entrada.';
    case AuthResult.emailAlreadyInUse:
      return 'Este correo ya está registrado. ¿Quieres iniciar sesión?';
    case AuthResult.wrongPassword:
      return 'Correo o contraseña incorrectos. Inténtalo de nuevo.';
    case AuthResult.userNotFound:
      return 'No existe una cuenta con ese correo.';
    case AuthResult.userDisabled:
      return 'Esta cuenta ha sido deshabilitada. Contacta al soporte.';
    case AuthResult.tooManyRequests:
      return 'Demasiados intentos. Espera un momento y vuelve a intentarlo.';
    case AuthResult.lockedOut:
      return 'Cuenta bloqueada temporalmente por múltiples intentos fallidos. '
          'Inténtalo en $kLockoutDurationMinutes minutos.';
    case AuthResult.networkError:
      return 'Error de red. Verifica tu conexión a internet.';
    case AuthResult.unknown:
      return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  }
}
