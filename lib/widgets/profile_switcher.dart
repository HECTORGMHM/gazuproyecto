import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../screens/business/business_dashboard_screen.dart';
import '../screens/business/business_registration_screen.dart';

/// Widget that reads the `hasBusiness` flag from the current user's Firestore
/// document and lets the user switch between customer and business-owner modes.
///
/// Place this widget in any screen that should expose the profile switcher
/// (e.g. the home screen, a settings/drawer panel).
///
/// Related issue: #2 (Gestión de negocios – Master Switch / Profile Switcher).
class ProfileSwitcher extends StatelessWidget {
  const ProfileSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final uid = authService.currentUser?.uid;

    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<GazuUser?>(
      stream: firestoreService.userStream(uid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final hasBusiness = user?.hasBusiness ?? false;

        return ListTile(
          leading: const Icon(Icons.swap_horiz_outlined),
          title: Text(
            hasBusiness ? 'Ir a mi negocio' : 'Registrar un negocio',
          ),
          subtitle: Text(
            hasBusiness
                ? 'Cambia al panel de tu negocio'
                : 'Conviértete en propietario',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _handleTap(context, hasBusiness),
        );
      },
    );
  }

  void _handleTap(BuildContext context, bool hasBusiness) {
    final destination = hasBusiness
        ? const BusinessDashboardScreen()
        : const BusinessRegistrationScreen();

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => destination),
    );
  }
}
