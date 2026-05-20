/**
 * Gazu – Cloud Functions
 *
 * Advanced server-side authentication validation including:
 *  - Account lockout after N consecutive failed login attempts
 *  - Blocking sign-in for disabled accounts
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

/** Maximum failed login attempts within the lockout window. */
const MAX_FAILED_ATTEMPTS = 5;

/** Lockout window in milliseconds (15 minutes). */
const LOCKOUT_WINDOW_MS = 15 * 60 * 1000;
const LOW_RATING_THRESHOLD = 2;
const COORDINATED_ATTACK_THRESHOLD = 10;
const ATTACK_WINDOW_MS = 60 * 60 * 1000;
const OFFENSIVE_WORDS = [
  "idiota",
  "estupido",
  "estúpido",
  "pendejo",
  "mierda",
];

type ReviewData = {
  targetType?: string;
  targetId?: string;
  rating?: number;
  comment?: string;
  authorId?: string;
  createdAt?: admin.firestore.Timestamp;
};

// ---------------------------------------------------------------------------
// beforeSignIn blocking function
// ---------------------------------------------------------------------------

/**
 * Runs before every sign-in attempt.
 * Blocks users whose accounts are disabled or temporarily locked out
 * due to too many consecutive failed attempts.
 */
export const beforeSignIn = functions.auth
  .user()
  .beforeSignIn(async (user, _context) => {
    // 1. Block disabled accounts (Firebase Auth flag)
    if (user.disabled) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Esta cuenta ha sido deshabilitada. Contacta al soporte."
      );
    }

    // 2. Check client-side lockout record in Firestore
    const email = user.email?.toLowerCase().trim();
    if (!email) return; // Social sign-ins without email – skip

    const attemptRef = db.collection("_loginAttempts").doc(email);
    const snap = await attemptRef.get();

    if (!snap.exists) return; // No failed attempts recorded

    const data = snap.data()!;
    const count: number = data.count ?? 0;
    const lastAttempt: admin.firestore.Timestamp | undefined =
      data.lastAttempt;

    if (count >= MAX_FAILED_ATTEMPTS && lastAttempt) {
      const elapsed = Date.now() - lastAttempt.toMillis();
      if (elapsed < LOCKOUT_WINDOW_MS) {
        const remainingMinutes = Math.ceil(
          (LOCKOUT_WINDOW_MS - elapsed) / 60000
        );
        throw new functions.https.HttpsError(
          "resource-exhausted",
          `Cuenta bloqueada temporalmente. Inténtalo en ${remainingMinutes} minuto(s).`
        );
      }
    }
  });

// ---------------------------------------------------------------------------
// onCreate – create Firestore user document for new Firebase Auth users
// ---------------------------------------------------------------------------

/**
 * Triggered when a new Firebase Auth user is created.
 * Ensures a Firestore user document exists with the correct defaults.
 */
export const onUserCreated = functions.auth.user().onCreate(async (user) => {
  const { uid, email, displayName, photoURL } = user;

  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);

    // Only create the document if the Flutter app hasn't already done so.
    if (snap.exists) {
      return;
    }

    tx.set(userRef, {
      email: email ?? "",
      displayName: displayName ?? "Usuario",
      photoUrl: photoURL ?? null,
      role: "user",
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: null,
    });
  });

  functions.logger.info(`User document ensured for ${uid}`);
});

// ---------------------------------------------------------------------------
// onDelete – clean up Firestore data when a user deletes their account
// ---------------------------------------------------------------------------

/**
 * Triggered when a Firebase Auth user is deleted.
 * Removes the associated Firestore user document and login-attempt record.
 */
export const onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const { uid, email } = user;

  const batch = db.batch();
  batch.delete(db.collection("users").doc(uid));

  if (email) {
    batch.delete(
      db.collection("_loginAttempts").doc(email.toLowerCase().trim())
    );
  }

  await batch.commit();
  functions.logger.info(`Cleaned up data for deleted user ${uid}`);
});

// ---------------------------------------------------------------------------
// Gazu Trust – review moderation and reputation aggregation
// ---------------------------------------------------------------------------

function normalize(text: string): string {
  return text
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}

function containsOffensiveLanguage(comment: string): boolean {
  const normalized = normalize(comment);
  return OFFENSIVE_WORDS.some((word) => normalized.includes(normalize(word)));
}

async function getRecentLowRatingsCount(
  targetType: string,
  targetId: string
): Promise<number> {
  const thresholdDate = new Date(Date.now() - ATTACK_WINDOW_MS);
  const recentSnap = await db
    .collection("reviews")
    .where("targetType", "==", targetType)
    .where("targetId", "==", targetId)
    .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(thresholdDate))
    .get();

  return recentSnap.docs.reduce((count, doc) => {
    const rating = (doc.data().rating as number | undefined) ?? 0;
    return rating <= LOW_RATING_THRESHOLD ? count + 1 : count;
  }, 0);
}

export const moderateReviewOnCreate = functions.firestore
  .document("reviews/{reviewId}")
  .onCreate(async (snapshot) => {
    const data = (snapshot.data() ?? {}) as ReviewData;
    const targetType = data.targetType ?? "";
    const targetId = data.targetId ?? "";
    const comment = data.comment ?? "";

    if (!targetType || !targetId) {
      return;
    }

    const offensive = comment.length > 0 && containsOffensiveLanguage(comment);
    const recentLowRatings = await getRecentLowRatingsCount(targetType, targetId);
    const coordinatedAttack = recentLowRatings >= COORDINATED_ATTACK_THRESHOLD;

    await snapshot.ref.update({
      flaggedOffensive: offensive,
      flaggedCoordinatedAttack: coordinatedAttack,
      moderationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

export const updateReputationStats = functions.firestore
  .document("reviews/{reviewId}")
  .onWrite(async (change) => {
    const after = change.after.exists
      ? (change.after.data() as ReviewData)
      : undefined;
    const before = change.before.exists
      ? (change.before.data() as ReviewData)
      : undefined;

    const targetType = after?.targetType ?? before?.targetType;
    const targetId = after?.targetId ?? before?.targetId;
    if (!targetType || !targetId) {
      return;
    }

    const reviewsSnap = await db
      .collection("reviews")
      .where("targetType", "==", targetType)
      .where("targetId", "==", targetId)
      .get();

    const reviews = reviewsSnap.docs.map((doc) => doc.data() as ReviewData);
    const totalReviews = reviews.length;
    const sumRatings = reviews.reduce((sum, review) => {
      const rating = review.rating ?? 0;
      return sum + rating;
    }, 0);
    const averageRating = totalReviews > 0 ? sumRatings / totalReviews : 0;

    const lowRatingsLastHour = await getRecentLowRatingsCount(targetType, targetId);
    const possibleAttack = lowRatingsLastHour >= COORDINATED_ATTACK_THRESHOLD;

    const stats = {
      targetType,
      targetId,
      averageRating,
      totalReviews,
      lowRatingsLastHour,
      possibleAttack,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const targetCollection = targetType === "staff" ? "staff" : "negocios";
    await Promise.all([
      db.collection(targetCollection).doc(targetId).set(
        {
          reputation: {
            averageRating,
            totalReviews,
            lowRatingsLastHour,
            possibleAttack,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true }
      ),
      db.collection("reputationStats")
        .doc(`${targetType}_${targetId}`)
        .set(stats, { merge: true }),
    ]);
  });
