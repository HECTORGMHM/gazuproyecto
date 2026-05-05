import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

/// Screen shown after registration, prompting the user to verify their email.
///
/// Offers a "Reenviar correo" button and a "Ya verifiqué mi correo" button that
/// reloads the Firebase user and, if verified, navigates away (the
/// [AuthWrapper] stream will handle the redirect to [HomeScreen]).
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, required this.email});

  final String email;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _checkingVerification = false;
  bool _resentEmail = false;

  Future<void> _checkVerification() async {
    setState(() => _checkingVerification = true);
    final verified =
        await context.read<AuthService>().reloadAndCheckEmailVerified();
    if (!mounted) return;
    setState(() => _checkingVerification = false);

    if (verified) {
      // Pop all the auth screens — AuthWrapper stream will push HomeScreen.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tu correo aún no ha sido verificado. '
            'Revisa tu bandeja de entrada o spam.',
          ),
        ),
      );
    }
  }

  Future<void> _resendEmail() async {
    final result =
        await context.read<AuthService>().sendEmailVerification();
    if (!mounted) return;
    if (result == AuthResult.success) {
      setState(() => _resentEmail = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Correo de verificación reenviado.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authResultMessage(result)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.mark_email_unread_outlined,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                '¡Verifica tu correo!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Enviamos un enlace de verificación a:\n${widget.email}\n\n'
                'Haz clic en el enlace del correo para activar tu cuenta. '
                'Después, regresa aquí y pulsa el botón de abajo.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                key: const Key('checkVerificationButton'),
                onPressed: _checkingVerification ? null : _checkVerification,
                icon: _checkingVerification
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined),
                label: const Text('Ya verifiqué mi correo'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('resendVerificationButton'),
                onPressed: _resentEmail ? null : _resendEmail,
                icon: const Icon(Icons.send_outlined),
                label: Text(
                  _resentEmail ? 'Correo reenviado' : 'Reenviar correo',
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  await context.read<AuthService>().signOut();
                  if (!mounted) return;
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Volver al inicio de sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
