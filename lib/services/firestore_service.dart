import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_model.dart';
import '../models/service_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

/// Service for Firestore user data operations.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  final FirebaseFirestore? _injectedFirestore;

  /// Returns the injected Firestore instance or the default singleton.
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(AppCollections.users);

  CollectionReference<Map<String, dynamic>> get _negociosRef =>
      _firestore.collection(AppCollections.negocios);

  // ---------------------------------------------------------------------------
  // User CRUD
  // ---------------------------------------------------------------------------

  /// Creates or overwrites a user document in Firestore.
  Future<void> createUser(GazuUser user) async {
    await _usersRef.doc(user.uid).set(user.toFirestore());
  }

  /// Retrieves a [GazuUser] by [uid]. Returns `null` if not found.
  Future<GazuUser?> getUser(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) return null;
    return GazuUser.fromFirestore(doc);
  }

  /// Updates only the provided fields for the user with [uid].
  Future<void> updateUser(
    String uid, {
    String? displayName,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      if (displayName != null) 'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
    await _usersRef.doc(uid).update(updates);
  }

  /// Streams real-time updates for the user with [uid].
  Stream<GazuUser?> userStream(String uid) {
    return _usersRef.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return GazuUser.fromFirestore(snap);
    });
  }

  // ---------------------------------------------------------------------------
  // Failed-login attempt tracking (edge-case: account lockout support)
  // ---------------------------------------------------------------------------

  /// Increments the failed login counter for [email].
  Future<void> recordFailedLoginAttempt(String email) async {
    final docRef = _firestore
        .collection('_loginAttempts')
        .doc(email.toLowerCase().trim());
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final now = DateTime.now();
      if (!snap.exists) {
        tx.set(docRef, {
          'count': 1,
          'firstAttempt': Timestamp.fromDate(now),
          'lastAttempt': Timestamp.fromDate(now),
        });
      } else {
        final data = snap.data()!;
        final firstAttempt =
            (data['firstAttempt'] as Timestamp?)?.toDate() ?? now;
        // Reset window if more than lockout duration has passed
        final windowExpired = now
            .difference(firstAttempt)
            .inMinutes >= kLockoutDurationMinutes;
        if (windowExpired) {
          tx.set(docRef, {
            'count': 1,
            'firstAttempt': Timestamp.fromDate(now),
            'lastAttempt': Timestamp.fromDate(now),
          });
        } else {
          tx.update(docRef, {
            'count': FieldValue.increment(1),
            'lastAttempt': Timestamp.fromDate(now),
          });
        }
      }
    });
  }

  /// Returns `true` if [email] is currently locked out.
  Future<bool> isLockedOut(String email) async {
    final snap = await _firestore
        .collection('_loginAttempts')
        .doc(email.toLowerCase().trim())
        .get();
    if (!snap.exists) return false;
    final data = snap.data()!;
    final count = (data['count'] as num?)?.toInt() ?? 0;
    if (count < kMaxFailedLoginAttempts) return false;
    final lastAttempt =
        (data['lastAttempt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final minutesSince =
        DateTime.now().difference(lastAttempt).inMinutes;
    return minutesSince < kLockoutDurationMinutes;
  }

  /// Resets the failed-login counter for [email] after a successful login.
  Future<void> resetLoginAttempts(String email) async {
    await _firestore
        .collection('_loginAttempts')
        .doc(email.toLowerCase().trim())
        .delete();
  }

  // ---------------------------------------------------------------------------
  // Business CRUD (issue #2 – Gestión de negocios / Alta de Negocio)
  // ---------------------------------------------------------------------------

  /// Creates a new document in the `/negocios/` collection and returns its id.
  ///
  /// Also marks the owner's user document with `hasBusiness: true`.
  Future<String> createBusiness(GazuBusiness business) async {
    final docRef = await _negociosRef.add(business.toFirestore());
    await _markUserHasBusiness(business.ownerId, value: true);
    return docRef.id;
  }

  /// Retrieves a [GazuBusiness] by [id]. Returns `null` if not found.
  Future<GazuBusiness?> getBusiness(String id) async {
    final doc = await _negociosRef.doc(id).get();
    if (!doc.exists) return null;
    return GazuBusiness.fromFirestore(doc);
  }

  /// Updates only the provided fields for the business with [id].
  Future<void> updateBusiness(
    String id, {
    String? nombre,
    String? descripcion,
    String? categoria,
    String? logoUrl,
    Map<String, Map<String, String>>? horarios,
    BusinessStatus? status,
    String? masterSwitchReason,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      if (nombre != null) 'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (categoria != null) 'categoria': categoria,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (horarios != null)
        'horarios': horarios.map((day, times) => MapEntry(day, times)),
      if (status != null) 'status': status.value,
      if (masterSwitchReason != null) 'masterSwitchReason': masterSwitchReason,
    };
    await _negociosRef.doc(id).update(updates);
  }

  /// Updates the Master Switch status for a business.
  Future<void> setBusinessMasterSwitch(
    String id, {
    required bool enabled,
    String? reason,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'status': enabled ? BusinessStatus.active.value : BusinessStatus.inactive.value,
      if (!enabled && reason != null && reason.trim().isNotEmpty)
        'masterSwitchReason': reason.trim()
      else
        'masterSwitchReason': FieldValue.delete(),
    };
    await _negociosRef.doc(id).update(updates);
  }

  /// Streams real-time updates for businesses owned by [ownerId].
  Stream<List<GazuBusiness>> businessesStream(String ownerId) {
    return _negociosRef
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snap) =>
            snap.docs.map(GazuBusiness.fromFirestore).toList());
  }

  /// Sets `hasBusiness` flag on the user document.
  Future<void> _markUserHasBusiness(String uid, {required bool value}) async {
    await _usersRef.doc(uid).update({
      'hasBusiness': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Publicly exposed wrapper so [ProfileSwitcher] can toggle the flag.
  Future<void> setUserHasBusiness(String uid, {required bool value}) =>
      _markUserHasBusiness(uid, value: value);

  // ---------------------------------------------------------------------------
  // Service CRUD (subcollection /negocios/{businessId}/servicios)
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _serviciosRef(String businessId) =>
      _negociosRef.doc(businessId).collection(AppCollections.servicios);

  /// Creates a new service document under the given business.
  /// Returns the new document id.
  Future<String> createService(GazuService service) async {
    final docRef = await _serviciosRef(service.businessId).add(service.toFirestore());
    return docRef.id;
  }

  /// Streams real-time updates for all services of [businessId].
  Stream<List<GazuService>> servicesStream(String businessId) {
    return _serviciosRef(businessId).snapshots().map(
          (snap) => snap.docs.map(GazuService.fromFirestore).toList(),
        );
  }

  /// Gets all services of [businessId] once.
  Future<List<GazuService>> getServices(String businessId) async {
    final snap = await _serviciosRef(businessId).get();
    return snap.docs.map(GazuService.fromFirestore).toList();
  }

  /// Updates editable fields for an existing service.
  Future<void> updateService(
    String businessId,
    String serviceId, {
    String? nombre,
    String? descripcion,
    double? precio,
    int? duracion,
    String? categoria,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      if (nombre != null) 'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (precio != null) 'precio': precio,
      if (duracion != null) 'duracion': duracion,
      if (categoria != null) 'categoria': categoria,
      if (isActive != null) 'isActive': isActive,
    };
    await _serviciosRef(businessId).doc(serviceId).update(updates);
  }

  /// Deletes a service document.
  Future<void> deleteService(String businessId, String serviceId) async {
    await _serviciosRef(businessId).doc(serviceId).delete();
  }
}
