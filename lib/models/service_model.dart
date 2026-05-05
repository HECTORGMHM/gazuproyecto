import 'package:cloud_firestore/cloud_firestore.dart';

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
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Creates a [GazuService] from a Firestore document snapshot.
  factory GazuService.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
