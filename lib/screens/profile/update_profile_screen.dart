import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';

/// Screen for updating the current user's display name and photo URL.
class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _photoUrlController;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _nameController =
        TextEditingController(text: user?.displayName ?? '');
    _photoUrlController =
        TextEditingController(text: user?.photoURL ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result = await context.read<AuthService>().updateProfile(
          displayName: _nameController.text,
          photoUrl: _photoUrlController.text.trim().isEmpty
              ? null
              : _photoUrlController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result == AuthResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
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
    final user = context.read<AuthService>().currentUser;
    // Only use the photo URL if it is a non-empty string.
    final hasPhoto = user?.photoURL?.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Actualizar perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage:
                        hasPhoto ? NetworkImage(user!.photoURL!) : null,
                    child: !hasPhoto
                        ? const Icon(Icons.person, size: 48)
                        : null,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Información personal',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Display name
                TextFormField(
                  key: const Key('updateNameField'),
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: Validators.displayName,
                ),
                const SizedBox(height: 16),

                // Email (read-only)
                TextFormField(
                  initialValue: user?.email ?? '',
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Photo URL
                TextFormField(
                  key: const Key('updatePhotoUrlField'),
                  controller: _photoUrlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'URL de foto de perfil (opcional)',
                    prefixIcon: Icon(Icons.image_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),

                FilledButton(
                  key: const Key('saveProfileButton'),
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
