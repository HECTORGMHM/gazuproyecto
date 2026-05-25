import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../utils/constants.dart';

class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({super.key, required this.service});

  final GazuService service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.scaffoldCharcoal),
      appBar: AppBar(
        backgroundColor: const Color(AppColors.scaffoldCharcoal),
        foregroundColor: Colors.white,
        title: const Text('Detalle del servicio'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: service.imageUrl != null && service.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: service.imageUrl!,
                    height: 220,
                    fit: BoxFit.cover,
                    errorWidget: (context, _, __) => _placeholder(220),
                    placeholder: (context, _) => const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                : _placeholder(220),
          ),
          const SizedBox(height: 16),
          Text(
            service.nombre,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            service.categoria,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                '${service.duracion} min',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.attach_money, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                '${service.hasVariablePrice ? 'Desde ' : ''}\$${service.effectiveBasePrice.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            service.descripcion.isEmpty
                ? 'Sin descripción disponible.'
                : service.descripcion,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          if (service.hasVariablePrice) ...[
            const SizedBox(height: 16),
            const Text(
              'Precios por staff',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...service.staffPrices.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${entry.key}: \$${entry.value.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholder(double height) {
    return Container(
      height: height,
      color: Colors.black26,
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined,
            size: 44, color: Colors.white54),
      ),
    );
  }
}
