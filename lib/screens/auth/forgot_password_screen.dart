import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';

/// Screen that lets the user request a password-reset email.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _loading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result = await context
        .read<AuthService>()
        .sendPasswordResetEmail(_emailController.text);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result == AuthResult.success) {
      setState(() => _emailSent = true);
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
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: _emailSent ? _buildSuccessView(theme) : _buildForm(theme),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_reset, size: 64, color: Colors.blue),
          const SizedBox(height: 24),
          Text(
            'Recupera tu contraseña',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Ingresa tu correo y te enviaremos las instrucciones para '
            'restablecer tu contraseña.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          TextFormField(
            key: const Key('forgotPasswordEmailField'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _sendResetEmail(),
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: Validators.email,
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('sendResetEmailButton'),
            onPressed: _loading ? null : _sendResetEmail,
            child: _loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar correo de recuperación'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read, size: 80, color: Colors.green),
        const SizedBox(height: 24),
        Text(
          '¡Correo enviado!',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'Revisa tu bandeja de entrada en ${_emailController.text} y sigue '
          'las instrucciones para restablecer tu contraseña.',
          textAlign: TextAlign.center,
          style:
              theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver al inicio de sesión'),
        ),
      ],
    );
  }
}
