import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/business_model.dart';
import '../../models/service_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import 'service_detail_screen.dart';

class BusinessCatalogDirectoryScreen extends StatelessWidget {
  const BusinessCatalogDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: const Color(AppColors.scaffoldCharcoal),
      appBar: AppBar(
        backgroundColor: const Color(AppColors.scaffoldCharcoal),
        foregroundColor: Colors.white,
        title: const Text('Catálogo de servicios'),
      ),
      body: StreamBuilder<List<GazuBusiness>>(
        stream: firestore.activeBusinessesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final businesses = snapshot.data ?? [];
          if (businesses.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay negocios activos disponibles.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: businesses.length,
            itemBuilder: (context, index) {
              final business = businesses[index];
              return Card(
                color: const Color(0xFF2C2C2C),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(
                    business.nombre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    business.categoria,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServiceCatalogScreen(
                        businessId: business.id ?? '',
                        businessName: business.nombre,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ServiceCatalogScreen extends StatefulWidget {
  const ServiceCatalogScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  final String businessId;
  final String businessName;

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen> {
  String _categoria = 'Todas';
  String _priceFilter = 'all';
  String _durationFilter = 'all';

  (double?, double?) _priceRange() {
    return switch (_priceFilter) {
      'lte200' => (null, 200),
      '200to500' => (200, 500),
      'gte500' => (500, null),
      _ => (null, null),
    };
  }

  (int?, int?) _durationRange() {
    return switch (_durationFilter) {
      'lte30' => (null, 30),
      '31to60' => (31, 60),
      'gte61' => (61, null),
      _ => (null, null),
    };
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final (minPrecio, maxPrecio) = _priceRange();
    final (minDuracion, maxDuracion) = _durationRange();

    return Scaffold(
      backgroundColor: const Color(AppColors.scaffoldCharcoal),
      appBar: AppBar(
        backgroundColor: const Color(AppColors.scaffoldCharcoal),
        foregroundColor: Colors.white,
        title: Text('Catálogo - ${widget.businessName}'),
      ),
      body: Column(
        children: [
          _CatalogFilters(
            categoria: _categoria,
            priceFilter: _priceFilter,
            durationFilter: _durationFilter,
            onCategoriaChanged: (value) => setState(() => _categoria = value),
            onPriceChanged: (value) => setState(() => _priceFilter = value),
            onDurationChanged: (value) =>
                setState(() => _durationFilter = value),
          ),
          Expanded(
            child: StreamBuilder<List<GazuService>>(
              stream: firestore.catalogServicesStream(
                widget.businessId,
                categoria: _categoria,
                minPrecio: minPrecio,
                maxPrecio: maxPrecio,
                minDuracion: minDuracion,
                maxDuracion: maxDuracion,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final services = snapshot.data ?? [];
                if (services.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay servicios disponibles con estos filtros.',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return _ServiceCard(service: service);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogFilters extends StatelessWidget {
  const _CatalogFilters({
    required this.categoria,
    required this.priceFilter,
    required this.durationFilter,
    required this.onCategoriaChanged,
    required this.onPriceChanged,
    required this.onDurationChanged,
  });

  final String categoria;
  final String priceFilter;
  final String durationFilter;
  final ValueChanged<String> onCategoriaChanged;
  final ValueChanged<String> onPriceChanged;
  final ValueChanged<String> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      color: const Color(0xFF2C2C2C),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: categoria,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF2C2C2C),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'Todas', child: Text('Todas')),
                    DropdownMenuItem(
                      value: 'Corte y peinado',
                      child: Text('Corte y peinado'),
                    ),
                    DropdownMenuItem(
                      value: 'Color y tinte',
                      child: Text('Color y tinte'),
                    ),
                    DropdownMenuItem(value: 'Masaje', child: Text('Masaje')),
                    DropdownMenuItem(value: 'Facial', child: Text('Facial')),
                    DropdownMenuItem(
                      value: 'Barbería',
                      child: Text('Barbería'),
                    ),
                    DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                  ],
                  onChanged: (value) {
                    if (value != null) onCategoriaChanged(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: priceFilter,
                  decoration: const InputDecoration(
                    labelText: 'Precio',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF2C2C2C),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todos')),
                    DropdownMenuItem(value: 'lte200', child: Text('Hasta \$200')),
                    DropdownMenuItem(value: '200to500', child: Text('\$200 - \$500')),
                    DropdownMenuItem(value: 'gte500', child: Text('Desde \$500')),
                  ],
                  onChanged: (value) {
                    if (value != null) onPriceChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: durationFilter,
                  decoration: const InputDecoration(
                    labelText: 'Duración',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF2C2C2C),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todas')),
                    DropdownMenuItem(value: 'lte30', child: Text('Hasta 30 min')),
                    DropdownMenuItem(value: '31to60', child: Text('31-60 min')),
                    DropdownMenuItem(value: 'gte61', child: Text('61+ min')),
                  ],
                  onChanged: (value) {
                    if (value != null) onDurationChanged(value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final GazuService service;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2C2C2C),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: service.imageUrl != null && service.imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: service.imageUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (context, _) => const SizedBox(
                    width: 56,
                    height: 56,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, _, __) => const _ServiceImageFallback(),
                )
              : const _ServiceImageFallback(),
        ),
        title: Text(
          service.nombre,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${service.duracion} min · ${service.categoria}\n${service.hasVariablePrice ? 'Desde' : 'Precio'}: \$${service.effectiveBasePrice.toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.white70),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right, color: Colors.white),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ServiceDetailScreen(service: service),
          ),
        ),
      ),
    );
  }
}

class _ServiceImageFallback extends StatelessWidget {
  const _ServiceImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      color: Colors.black26,
      child: const Icon(Icons.image_not_supported_outlined, color: Colors.white54),
    );
  }
}
