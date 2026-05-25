import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';

/// Shown to business owners whose KYC verification request has been submitted
/// and is awaiting admin review, or whose request was rejected.
class VerificationPendingScreen extends StatelessWidget {
  const VerificationPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final uid = authService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(AppColors.scaffoldCharcoal),
      appBar: AppBar(
        backgroundColor: const Color(AppColors.scaffoldCharcoal),
        foregroundColor: Colors.white,
        title: const Text('Estado de verificación'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<GazuUser?>(
        stream: firestoreService.userStream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final status =
              snap.data?.verificationStatus ?? BusinessVerificationStatus.pending;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatusIcon(status: status),
                  const SizedBox(height: 28),
                  Text(
                    _title(status),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _body(status),
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 32),
                  if (status == BusinessVerificationStatus.approved)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(AppColors.primaryOrange),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(200, 48),
                      ),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('Ir a mi panel de negocio'),
                      // AuthWrapper will route to HomeScreen automatically
                      // once the stream reflects approved status; sign-out +
                      // sign-in is not needed. This button is only shown as a
                      // manual refresh trigger while the stream catches up.
                      onPressed: () {},
                    ),
                  if (status == BusinessVerificationStatus.rejected)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(200, 48),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Enviar nueva verificación'),
                      // AuthWrapper already redirects rejected users to
                      // BusinessOwnerVerificationScreen automatically via
                      // the user stream. This button signs out so the stream
                      // re-evaluates on next login.
                      onPressed: () => authService.signOut(),
                    ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                    onPressed: () => authService.signOut(),
                  ),
                  const SizedBox(height: 40),
                  _SupportInfo(status: status),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _title(BusinessVerificationStatus s) {
    switch (s) {
      case BusinessVerificationStatus.pending:
        return 'Verificación en revisión';
      case BusinessVerificationStatus.approved:
        return '¡Cuenta verificada!';
      case BusinessVerificationStatus.rejected:
        return 'Verificación rechazada';
      case BusinessVerificationStatus.none:
        return 'Verificación pendiente';
    }
  }

  String _body(BusinessVerificationStatus s) {
    switch (s) {
      case BusinessVerificationStatus.pending:
        return 'Hemos recibido tu solicitud de verificación.\n'
            'Nuestro equipo revisará tu información en un plazo de 24 a 48 horas hábiles.\n\n'
            'Recibirás una notificación cuando tu cuenta sea aprobada y podrás '
            'comenzar a publicar tu negocio en Gazu.';
      case BusinessVerificationStatus.approved:
        return '¡Tu identidad ha sido verificada exitosamente! '
            'Ya puedes registrar tu negocio y ofrecer tus servicios en Gazu.';
      case BusinessVerificationStatus.rejected:
        return 'Lamentablemente tu solicitud de verificación no pudo ser aprobada. '
            'Esto puede deberse a información incompleta o documentos ilegibles.\n\n'
            'Por favor, vuelve a enviar tu solicitud con la información correcta.';
      case BusinessVerificationStatus.none:
        return 'Necesitas completar el proceso de verificación '
            'para poder publicar tu negocio.';
    }
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final BusinessVerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      BusinessVerificationStatus.pending => (
          Icons.hourglass_top_rounded,
          Colors.orange
        ),
      BusinessVerificationStatus.approved => (
          Icons.verified_rounded,
          Colors.green
        ),
      BusinessVerificationStatus.rejected => (
          Icons.cancel_rounded,
          Colors.red
        ),
      BusinessVerificationStatus.none => (
          Icons.pending_actions_rounded,
          Colors.blue
        ),
    };

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(30),
        border: Border.all(color: color.withAlpha(80), width: 2),
      ),
      child: Icon(icon, size: 52, color: color),
    );
  }
}

class _SupportInfo extends StatelessWidget {
  const _SupportInfo({required this.status});
  final BusinessVerificationStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == BusinessVerificationStatus.approved) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: const [
          Row(
            children: [
              Icon(Icons.support_agent_outlined,
                  color: Colors.white38, size: 18),
              SizedBox(width: 8),
              Text(
                '¿Tienes dudas?',
                style: TextStyle(
                    color: Colors.white60,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Contáctanos en soporte@gazu.mx\n'
            'Horario de atención: Lun–Vie 9:00–18:00 hrs.',
            style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
