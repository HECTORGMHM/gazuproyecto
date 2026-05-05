import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/business_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import 'business_registration_screen.dart';

// TODO(#2): Implement full business management (services, staff, stats)
// as part of Épica: Gestión de negocios.

/// Placeholder dashboard shown after a successful business registration.
///
/// Streams the owner's businesses from Firestore and displays basic info.
/// Related issue: #2 (Gestión de negocios – incluye Master Switch).
class BusinessDashboardScreen extends StatelessWidget {
  const BusinessDashboardScreen({super.key});

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
        title: const Text('Mi negocio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_outlined),
            tooltip: 'Registrar otro negocio',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const BusinessRegistrationScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<GazuBusiness>>(
        stream: firestoreService.businessesStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final businesses = snapshot.data ?? [];

          if (businesses.isEmpty) {
            return _EmptyDashboard(
              onRegister: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (_) => const BusinessRegistrationScreen()),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: businesses.length,
            itemBuilder: (_, i) => _BusinessCard(business: businesses[i]),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront_outlined,
                size: 80, color: Colors.white24),
            const SizedBox(height: 24),
            const Text(
              'Aún no tienes negocios registrados',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryOrange),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Registrar negocio'),
              onPressed: onRegister,
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.business});

  final GazuBusiness business;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (business.status) {
      BusinessStatus.active => Colors.green,
      BusinessStatus.inactive => Colors.orange,
      BusinessStatus.pending => Colors.blue,
    };

    final statusLabel = switch (business.status) {
      BusinessStatus.active => 'Activo',
      BusinessStatus.inactive => 'Inactivo',
      BusinessStatus.pending => 'Pendiente',
    };

    return Card(
      color: const Color(0xFF2C2C2C),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: business.logoUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  business.logoUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              )
            : const CircleAvatar(
                backgroundColor: Color(AppColors.primaryOrange),
                child: Icon(Icons.storefront, color: Colors.white),
              ),
        title: Text(
          business.nombre,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          business.categoria,
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: Chip(
          label: Text(statusLabel,
              style: const TextStyle(fontSize: 11)),
          backgroundColor: statusColor.withAlpha(40),
          side: BorderSide(color: statusColor.withAlpha(100)),
          labelStyle: TextStyle(color: statusColor),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
