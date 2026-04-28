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

  await db
    .collection("users")
    .doc(uid)
    .set(
      {
        email: email ?? "",
        displayName: displayName ?? "Usuario",
        photoUrl: photoURL ?? null,
        role: "user",
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: null,
      },
      { merge: true }
    );

  functions.logger.info(`User document created for ${uid}`);
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
