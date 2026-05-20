# Firestore Security Rules – Gazu

> **Related issues:** #14 (Épica: Seguridad – Firestore Rules), #2 (Gestión de negocios)

This document contains the recommended Firestore security rules for the Gazu
project. Copy the rules below into the **Firebase Console → Firestore → Rules**
tab (or into `firestore.rules` if you use the Firebase CLI).

---

## Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // -------------------------------------------------------------------------
    // Helper functions
    // -------------------------------------------------------------------------

    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(uid) {
      return isSignedIn() && request.auth.uid == uid;
    }

    // -------------------------------------------------------------------------
    // /users/{uid}
    // -------------------------------------------------------------------------
    match /users/{uid} {
      // A user can read and write only their own document.
      allow read, update, delete: if isOwner(uid);
      // Allow create so new users can be written on registration.
      allow create: if isSignedIn() && request.auth.uid == uid;
    }

    // -------------------------------------------------------------------------
    // /negocios/{businessId}
    // -------------------------------------------------------------------------
    match /negocios/{businessId} {
      // Any signed-in user can read active businesses.
      allow read: if isSignedIn();

      // Only the owner can create a business document.
      allow create: if isSignedIn()
                    && request.resource.data.ownerId == request.auth.uid;

      // Only the owner can update or delete their business.
      allow update, delete: if isSignedIn()
                            && resource.data.ownerId == request.auth.uid;
    }

    // -------------------------------------------------------------------------
    // /staff/{staffId}  (placeholder – Épica: Gestión de staff, issue #8)
    // -------------------------------------------------------------------------
    match /staff/{staffId} {
      allow read: if isSignedIn();
      allow write: if isSignedIn()
                   && get(/databases/$(database)/documents/negocios/$(resource.data.businessId)).data.ownerId == request.auth.uid;
    }

    // -------------------------------------------------------------------------
    // /appointments/{appointmentId}
    // -------------------------------------------------------------------------
    match /appointments/{appointmentId} {
      allow read: if isSignedIn();
      allow write: if false; // managed by secure flows / Cloud Functions
    }

    // -------------------------------------------------------------------------
    // /reviews/{reviewId}  (Gazu Trust)
    // -------------------------------------------------------------------------
    match /reviews/{reviewId} {
      allow read: if isSignedIn();

      // One review per appointment+author (doc id: "${appointmentId}_${authorId}")
      allow create: if isSignedIn()
                    && request.resource.data.authorId == request.auth.uid
                    && request.resource.data.rating is int
                    && request.resource.data.rating >= 1
                    && request.resource.data.rating <= 5
                    && request.resource.data.comment is string
                    && request.resource.data.comment.size() >= 10;

      // Only business/staff response can be updated by authenticated users.
      allow update: if isSignedIn()
                    && request.resource.data.authorId == resource.data.authorId;

      allow delete: if false;
    }

    // -------------------------------------------------------------------------
    // /reputationStats/{id}
    // -------------------------------------------------------------------------
    match /reputationStats/{id} {
      allow read: if isSignedIn();
      allow write: if false; // only Cloud Functions aggregate stats
    }

    // -------------------------------------------------------------------------
    // /_loginAttempts/{email}  (internal – account lockout tracking)
    // -------------------------------------------------------------------------
    match /_loginAttempts/{email} {
      // Only Cloud Functions / trusted server code should write here.
      // Deny all client reads/writes.
      allow read, write: if false;
    }
  }
}
```

---

## Firebase Storage Rules

Add the following to `storage.rules` to protect the logo uploads stored under
`negocios/{ownerId}/`:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // Logos stored during Alta de Negocio (issue #2).
    match /negocios/{ownerId}/{fileName} {
      // Only the authenticated owner can upload/replace their logo.
      allow write: if request.auth != null && request.auth.uid == ownerId
                   && request.resource.size < 2 * 1024 * 1024   // max 2 MB
                   && request.resource.contentType.matches('image/.*');

      // Any signed-in user can read business logos.
      allow read: if request.auth != null;
    }
  }
}
```

---

## Notes

- Rules are evaluated top-to-bottom; the **first matching rule wins**.
- The `/_loginAttempts/` collection is intentionally locked from client access
  and should only be written via **Cloud Functions** (issue #13).
- Reputation stats should be written by Cloud Functions only (`/reputationStats`
  and `reputation.*` in `/negocios` or `/staff`).
- Expand the `/staff/` rules once issue #8 (Gestión de staff) is implemented.
- For geospatial queries (issue #10), `/negocios/` must remain readable by
  signed-in users.
