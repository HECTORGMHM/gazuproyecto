import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

/// Domain model for a service offered by a [GazuBusiness].
///
/// Stored as a subcollection: `/negocios/{businessId}/servicios/{id}`.
class GazuService {
  final String? id;
  final String businessId;
  final String ownerId;
  final String nombre;
  final String descripcion;
  final double precio;

  /// Duration of the service in minutes.
  final int duracion;
  final String categoria;
  final bool isActive;
  final bool hasStock;
  final String? imageUrl;
  final Map<String, double> staffPrices;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const GazuService({
    this.id,
    required this.businessId,
    required this.ownerId,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.duracion,
    required this.categoria,
    this.isActive = true,
    this.hasStock = true,
    this.imageUrl,
    this.staffPrices = const {},
    required this.createdAt,
    this.updatedAt,
  });

  /// Converts this service to a map suitable for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'ownerId': ownerId,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'duracion': duracion,
      'categoria': categoria,
      'isActive': isActive,
      'hasStock': hasStock,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      if (staffPrices.isNotEmpty) 'staffPrices': staffPrices,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Creates a [GazuService] from a Firestore document snapshot.
  factory GazuService.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawStaffPrices = (data['staffPrices'] ?? data['preciosPorStaff'])
        as Map<String, dynamic>? ?? {};
    final parsedStaffPrices = rawStaffPrices.map((k, v) {
      final value = (v as num?)?.toDouble() ?? 0;
      return MapEntry(k, value);
    });

    return GazuService(
      id: doc.id,
      businessId: data['businessId'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      precio: (data['precio'] as num?)?.toDouble() ?? 0.0,
      duracion: (data['duracion'] as num?)?.toInt() ?? 30,
      categoria: data['categoria'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      hasStock: data['hasStock'] as bool? ?? ((data['stock'] as num?) ?? 1) > 0,
      imageUrl: data['imageUrl'] as String?,
      staffPrices: parsedStaffPrices,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  GazuService copyWith({
    String? nombre,
    String? descripcion,
    double? precio,
    int? duracion,
    String? categoria,
    bool? isActive,
    bool? hasStock,
    String? imageUrl,
    Map<String, double>? staffPrices,
    DateTime? updatedAt,
  }) {
    return GazuService(
      id: id,
      businessId: businessId,
      ownerId: ownerId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      precio: precio ?? this.precio,
      duracion: duracion ?? this.duracion,
      categoria: categoria ?? this.categoria,
      isActive: isActive ?? this.isActive,
      hasStock: hasStock ?? this.hasStock,
      imageUrl: imageUrl ?? this.imageUrl,
      staffPrices: staffPrices ?? this.staffPrices,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasVariablePrice => staffPrices.isNotEmpty;

  double get effectiveBasePrice {
    if (staffPrices.isEmpty) return precio;
    return staffPrices.values.reduce(min);
  }
}
