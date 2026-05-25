import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/business_model.dart';
import '../../models/service_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import 'business_registration_screen.dart';
import 'service_registration_screen.dart';

const double _statusChipBackgroundOpacity = 0.16;
const double _statusChipBorderOpacity = 0.39;

/// Dashboard for business owners to manage business details and services.
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

          final businesses = (snapshot.data ?? []).toList()
            ..sort((a, b) {
              final statusOrderA = _businessStatusOrder(a.status);
              final statusOrderB = _businessStatusOrder(b.status);
              if (statusOrderA != statusOrderB) {
                return statusOrderA.compareTo(statusOrderB);
              }
              final aDate = a.updatedAt ?? a.createdAt;
              final bDate = b.updatedAt ?? b.createdAt;
              return bDate.compareTo(aDate);
            });

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

int _businessStatusOrder(BusinessStatus status) {
  return switch (status) {
    BusinessStatus.active => 0,
    BusinessStatus.pending => 1,
    BusinessStatus.inactive => 2,
  };
}

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

class _BusinessCard extends StatefulWidget {
  const _BusinessCard({required this.business});
  final GazuBusiness business;

  @override
  State<_BusinessCard> createState() => _BusinessCardState();
}

class _BusinessCardState extends State<_BusinessCard> {
  bool _updatingMasterSwitch = false;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final business = widget.business;
    final businessId = business.id;
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
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
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.categoria,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  if (business.descripcion.trim().isNotEmpty)
                    Text(
                      business.descripcion,
                      style: const TextStyle(color: Colors.white70),
                    ),
                ],
              ),
              trailing: Chip(
                label: Text(statusLabel, style: const TextStyle(fontSize: 11)),
                backgroundColor:
                    statusColor.withOpacity(_statusChipBackgroundOpacity),
                side: BorderSide(
                  color: statusColor.withOpacity(_statusChipBorderOpacity),
                ),
                labelStyle: TextStyle(color: statusColor),
                padding: EdgeInsets.zero,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.power_settings_new,
                    size: 18, color: Colors.white70),
                const SizedBox(width: 6),
                const Text('Master Switch',
                    style: TextStyle(color: Colors.white70)),
                const Spacer(),
                Switch.adaptive(
                  value: business.status == BusinessStatus.active,
                  onChanged: businessId == null || _updatingMasterSwitch
                      ? null
                      : (enabled) =>
                          _handleMasterSwitch(context, businessId, enabled),
                ),
                TextButton.icon(
                  onPressed: businessId == null
                      ? null
                      : () => _openEditBusinessDialog(context, business),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Editar'),
                ),
              ],
            ),
            if (business.status == BusinessStatus.inactive &&
                business.masterSwitchReason != null &&
                business.masterSwitchReason!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Razón: ${business.masterSwitchReason}',
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
            const Divider(color: Colors.white24),
            Row(
              children: [
                const Icon(Icons.design_services_outlined,
                    size: 18, color: Colors.white70),
                const SizedBox(width: 6),
                const Text('Servicios',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ServiceRegistrationScreen()),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Alta'),
                ),
              ],
            ),
            if (businessId == null)
              const Text(
                'No se pudo cargar este negocio.',
                style: TextStyle(color: Colors.redAccent),
              )
            else
              StreamBuilder<List<GazuService>>(
                stream: firestoreService.servicesStream(businessId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: LinearProgressIndicator(),
                    );
                  }
                  final services = snapshot.data ?? [];
                  if (services.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Aún no hay servicios registrados.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }
                  return Column(
                    children: services
                        .map((service) => _ServiceTile(
                              businessId: businessId,
                              service: service,
                            ))
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMasterSwitch(
      BuildContext context, String businessId, bool enabled) async {
    if (_updatingMasterSwitch) return;
    final firestoreService = context.read<FirestoreService>();
    setState(() => _updatingMasterSwitch = true);
    try {
      String? reason;
      if (!enabled) {
        reason = await _askDisableReason(context);
        if (!context.mounted) return;
      }
      await firestoreService.setBusinessMasterSwitch(
        businessId,
        enabled: enabled,
        reason: reason,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar el Master Switch: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingMasterSwitch = false);
    }
  }

  Future<String?> _askDisableReason(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar temporalmente'),
        content: TextField(
          controller: controller,
          maxLength: 280,
          decoration: const InputDecoration(
            labelText: 'Razón (opcional)',
            hintText: 'Ej. mantenimiento, evento privado...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Omitir'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _openEditBusinessDialog(
      BuildContext context, GazuBusiness business) async {
    final firestoreService = context.read<FirestoreService>();
    final nameCtrl = TextEditingController(text: business.nombre);
    final categoryCtrl = TextEditingController(text: business.categoria);
    final descriptionCtrl = TextEditingController(text: business.descripcion);

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar negocio'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nombre del negocio'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Categoría'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (save == true && business.id != null) {
      try {
        await firestoreService.updateBusiness(
          business.id!,
          nombre: nameCtrl.text.trim(),
          categoria: categoryCtrl.text.trim(),
          descripcion: descriptionCtrl.text.trim(),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar el negocio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    nameCtrl.dispose();
    categoryCtrl.dispose();
    descriptionCtrl.dispose();
  }
}

class _ServiceTile extends StatefulWidget {
  const _ServiceTile({
    required this.businessId,
    required this.service,
  });

  final String businessId;
  final GazuService service;

  @override
  State<_ServiceTile> createState() => _ServiceTileState();
}

class _ServiceTileState extends State<_ServiceTile> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final service = widget.service;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(service.nombre, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        '${service.categoria} • \$${service.precio.toStringAsFixed(2)} • ${service.duracion} min',
        style: const TextStyle(color: Colors.white54),
      ),
      leading: Icon(
        service.isActive ? Icons.check_circle : Icons.pause_circle_filled,
        color: service.isActive ? Colors.green : Colors.orange,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch.adaptive(
            value: service.isActive,
            onChanged: _loading
                ? null
                : (v) => _updateService(context, isActive: v),
          ),
          IconButton(
            tooltip: 'Eliminar servicio',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _loading ? null : () => _deleteService(context),
          ),
        ],
      ),
    );
  }

  Future<void> _updateService(BuildContext context, {required bool isActive}) async {
    final firestoreService = context.read<FirestoreService>();
    if (widget.service.id == null) return;

    setState(() => _loading = true);
    try {
      await firestoreService.updateService(
        widget.businessId,
        widget.service.id!,
        isActive: isActive,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar el servicio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteService(BuildContext context) async {
    final firestoreService = context.read<FirestoreService>();
    if (widget.service.id == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: Text('¿Eliminar "${widget.service.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() => _loading = true);
    try {
      await firestoreService.deleteService(widget.businessId, widget.service.id!);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar el servicio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
