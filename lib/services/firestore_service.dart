import 'package:cloud_firestore/cloud_firestore.dart';
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
    final count = data['count'] as int? ?? 0;
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
}
