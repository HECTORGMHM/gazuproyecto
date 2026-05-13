import 'package:cloud_firestore/cloud_firestore.dart';

// TODO(#2): Expand model once Épica: Gestión de negocios is fully implemented.

/// Status values for a [GazuBusiness] document.
enum BusinessStatus {
  /// Awaiting admin approval.
  pending,

  /// Visible and bookable by clients.
  active,

  /// Temporarily hidden by the owner (Master Switch off).
  inactive,
}

/// Extension helpers for [BusinessStatus].
extension BusinessStatusX on BusinessStatus {
  String get value {
    switch (this) {
      case BusinessStatus.pending:
        return 'pending';
      case BusinessStatus.active:
        return 'active';
      case BusinessStatus.inactive:
        return 'inactive';
    }
  }

  static BusinessStatus fromString(String? v) {
    switch (v) {
      case 'active':
        return BusinessStatus.active;
      case 'inactive':
        return BusinessStatus.inactive;
      default:
        return BusinessStatus.pending;
    }
  }
}

/// Domain model for a Gazu business document stored in `/negocios/{id}`.
///
/// Related issues: #2 (Gestión de negocios), #10 (Geolocalización y mapa).
class GazuBusiness {
  final String? id;
  final String ownerId;
  final String nombre;
  final String descripcion;
  final String categoria;
  final GeoPoint? ubicacion;

  /// Schedule map: `{ 'lunes': {'open': '09:00', 'close': '18:00'}, ... }`.
  final Map<String, Map<String, String>> horarios;

  final BusinessStatus status;
  final String? masterSwitchReason;
  final String? logoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const GazuBusiness({
    this.id,
    required this.ownerId,
    required this.nombre,
    this.descripcion = '',
    required this.categoria,
    this.ubicacion,
    this.horarios = const {},
    this.status = BusinessStatus.pending,
    this.masterSwitchReason,
    this.logoUrl,
    required this.createdAt,
    this.updatedAt,
  });

  /// Converts this business to a map suitable for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'nombre': nombre,
      'descripcion': descripcion,
      'categoria': categoria,
      if (ubicacion != null) 'ubicacion': ubicacion,
      'horarios': horarios.map((day, times) => MapEntry(day, times)),
      'status': status.value,
      if (masterSwitchReason != null) 'masterSwitchReason': masterSwitchReason,
      if (logoUrl != null) 'logoUrl': logoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt':
          updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Creates a [GazuBusiness] from a Firestore document snapshot.
  factory GazuBusiness.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Safely cast the nested horarios map.
    final rawHorarios = data['horarios'] as Map<String, dynamic>? ?? {};
    final horarios = rawHorarios.map((day, value) {
      final times = (value as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as String? ?? ''));
      return MapEntry(day, times);
    });

    return GazuBusiness(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      categoria: data['categoria'] as String? ?? '',
      ubicacion: data['ubicacion'] as GeoPoint?,
      horarios: horarios,
      status: BusinessStatusX.fromString(data['status'] as String?),
      masterSwitchReason: data['masterSwitchReason'] as String?,
      logoUrl: data['logoUrl'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  GazuBusiness copyWith({
    String? nombre,
    String? descripcion,
    String? categoria,
    GeoPoint? ubicacion,
    Map<String, Map<String, String>>? horarios,
    BusinessStatus? status,
    String? masterSwitchReason,
    String? logoUrl,
    DateTime? updatedAt,
  }) {
    return GazuBusiness(
      id: id,
      ownerId: ownerId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      categoria: categoria ?? this.categoria,
      ubicacion: ubicacion ?? this.ubicacion,
      horarios: horarios ?? this.horarios,
      status: status ?? this.status,
      masterSwitchReason: masterSwitchReason ?? this.masterSwitchReason,
      logoUrl: logoUrl ?? this.logoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
