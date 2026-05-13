import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/business/business_owner_verification_screen.dart';
import '../screens/business/verification_pending_screen.dart';

/// Listens to Firebase Auth state and routes the user to the correct screen:
///
/// - Not logged in → [LoginScreen]
/// - Logged in, role `business`, not verified → [BusinessOwnerVerificationScreen]
/// - Logged in, role `business`, verification pending → [VerificationPendingScreen]
/// - Logged in, any other case → [HomeScreen]
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return _loadingScaffold;
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) return const LoginScreen();

        // Logged in – read the Gazu user document to check role & verification.
        return StreamBuilder<GazuUser?>(
          stream: firestoreService.userStream(firebaseUser.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return _loadingScaffold;
            }

            final gazuUser = userSnapshot.data;

            // If the user document hasn't been created yet (e.g. during the
            // first social sign-in), fall through to HomeScreen which will
            // handle the empty state gracefully.
            if (gazuUser == null) return const HomeScreen();

            if (gazuUser.role == UserRole.business) {
              switch (gazuUser.verificationStatus) {
                case BusinessVerificationStatus.none:
                  return const BusinessOwnerVerificationScreen();
                case BusinessVerificationStatus.pending:
                  return const VerificationPendingScreen();
                case BusinessVerificationStatus.rejected:
                  return const BusinessOwnerVerificationScreen(
                    headerMessage:
                        'Tu verificación anterior fue rechazada. '
                        'Por favor, vuelve a enviar tus datos con la información correcta.',
                  );
                case BusinessVerificationStatus.approved:
                  return const HomeScreen();
              }
            }

            return const HomeScreen();
          },
        );
      },
    );
  }

  static Widget get _loadingScaffold => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}
