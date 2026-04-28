import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../profile/update_profile_screen.dart';

/// Home screen that adapts its content based on the current user's [UserRole].
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final firebaseUser = authService.currentUser!;

    return StreamBuilder<GazuUser?>(
      stream: firestoreService.userStream(firebaseUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        final role = user?.role ?? UserRole.user;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Gazu'),
            actions: [
              // Profile icon
              IconButton(
                icon: const Icon(Icons.account_circle_outlined),
                tooltip: 'Mi perfil',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UpdateProfileScreen()),
                  );
                },
              ),
              // Sign out
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Cerrar sesión',
                onPressed: () => _confirmSignOut(context, authService),
              ),
            ],
          ),
          body: _buildBodyForRole(context, role, firebaseUser, user),
        );
      },
    );
  }

  Widget _buildBodyForRole(
    BuildContext context,
    UserRole role,
    User firebaseUser,
    GazuUser? gazuUser,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          Text(
            'Hola, ${gazuUser?.displayName ?? firebaseUser.displayName ?? 'Usuario'} 👋',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _RoleBadge(role: role),
          const Divider(height: 32),

          // Role-specific content
          Expanded(child: _RoleContent(role: role)),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(
      BuildContext context, AuthService authService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await authService.signOut();
    }
  }
}

// ---------------------------------------------------------------------------
// Role badge
// ---------------------------------------------------------------------------

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      UserRole.business => ('Negocio / Admin', Colors.deepPurple),
      UserRole.staff => ('Staff', Colors.teal),
      UserRole.user => ('Usuario', Colors.blue),
    };

    return Chip(
      label: Text(label),
      backgroundColor: color.withAlpha(30),
      side: BorderSide(color: color.withAlpha(80)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

// ---------------------------------------------------------------------------
// Role-specific content panels
// ---------------------------------------------------------------------------

class _RoleContent extends StatelessWidget {
  const _RoleContent({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return switch (role) {
      UserRole.business => const _BusinessPanel(),
      UserRole.staff => const _StaffPanel(),
      UserRole.user => const _UserPanel(),
    };
  }
}

class _UserPanel extends StatelessWidget {
  const _UserPanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        _HomeCard(
          icon: Icons.search,
          title: 'Explorar negocios',
          subtitle: 'Encuentra servicios cerca de ti',
        ),
        _HomeCard(
          icon: Icons.calendar_today,
          title: 'Mis reservas',
          subtitle: 'Consulta y gestiona tus citas',
        ),
        _HomeCard(
          icon: Icons.favorite_outline,
          title: 'Favoritos',
          subtitle: 'Negocios y servicios guardados',
        ),
      ],
    );
  }
}

class _StaffPanel extends StatelessWidget {
  const _StaffPanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        _HomeCard(
          icon: Icons.calendar_month,
          title: 'Agenda del día',
          subtitle: 'Citas asignadas a tu agenda',
        ),
        _HomeCard(
          icon: Icons.people_outline,
          title: 'Clientes',
          subtitle: 'Historial y notas de clientes',
        ),
      ],
    );
  }
}

class _BusinessPanel extends StatelessWidget {
  const _BusinessPanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        _HomeCard(
          icon: Icons.storefront,
          title: 'Mi negocio',
          subtitle: 'Gestiona información y servicios',
        ),
        _HomeCard(
          icon: Icons.group,
          title: 'Equipo / Staff',
          subtitle: 'Administra tu personal',
        ),
        _HomeCard(
          icon: Icons.bar_chart,
          title: 'Reportes',
          subtitle: 'Estadísticas y métricas del negocio',
        ),
        _HomeCard(
          icon: Icons.settings,
          title: 'Configuración',
          subtitle: 'Ajustes de la cuenta y del negocio',
        ),
      ],
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}
