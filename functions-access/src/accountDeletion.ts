/**
 * Account deletion: lets a person delete their own Canopy account and the
 * personal data attached to it. Runs on the server (Admin SDK) because it has to
 * remove the sign-in account, files in Storage and records the person's own
 * login is not allowed to touch.
 *
 * What goes: the profile, username reservation, notifications, their
 * contributions and point awards, their organisation memberships, support
 * messages, service listings they posted, their seller profile, and photos they
 * uploaded under their own folders. Comments they made on heritage entries are
 * kept but made anonymous.
 *
 * What blocks it: owning an organisation. An organisation has other people
 * and public records, so ownership is handed over or the organisation is closed
 * by Canopy first (the app tells them).
 */

import { getAuth } from "firebase-admin/auth";
import { getFirestore, Query } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { HttpsError } from "firebase-functions/v2/https";

async function deleteQuery(q: Query): Promise<number> {
  const db = getFirestore();
  let n = 0;
  // Page through in batches of 400 so no single commit gets too large.
  for (;;) {
    const snap = await q.limit(400).get();
    if (snap.empty) return n;
    const batch = db.batch();
    snap.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
    n += snap.size;
    if (snap.size < 400) return n;
  }
}

export async function deleteMyAccountImpl(uid: string): Promise<{ ok: true }> {
  const db = getFirestore();

  const owned = await db.collection("organizations").where("org_rep_uid", "==", uid).limit(1).get();
  if (!owned.empty) {
    throw new HttpsError(
      "failed-precondition",
      "You own an organisation. Contact Canopy to transfer or close it before deleting your account."
    );
  }

  // Firestore: personal records.
  await Promise.all([
    deleteQuery(db.collection("contributions").where("userId", "==", uid)),
    deleteQuery(db.collection("notifications").where("userId", "==", uid)),
    deleteQuery(db.collection("pointAwards").where("userId", "==", uid)),
    deleteQuery(db.collection("OrgMembers").where("userId", "==", uid)),
    deleteQuery(db.collection("support_requests").where("userId", "==", uid)),
    deleteQuery(db.collection("usernames").where("uid", "==", uid)),
    deleteQuery(db.collection("service_listings").where("postedByUid", "==", uid)),
    deleteQuery(db.collection("listings").where("postedByUid", "==", uid)),
  ]);

  // Comments are kept (they are part of an archive's discussion) but anonymised.
  const comments = await db.collection("cultural_comments").where("commenter_id", "==", uid).get();
  for (let i = 0; i < comments.docs.length; i += 400) {
    const batch = db.batch();
    comments.docs.slice(i, i + 400).forEach(d => batch.update(d.ref, { commenter_id: "", commenter_name: "Deleted member" }));
    await batch.commit();
  }

  // The profile records themselves, including anything under them.
  for (const path of [`Users/${uid}`, `users/${uid}`, `org_rep/${uid}`, `marketplace_sellers/${uid}`, `UserPrivate/${uid}`]) {
    await db.recursiveDelete(db.doc(path));
  }

  // Storage: files the person uploaded under their own folders.
  const bucket = getStorage().bucket();
  for (const prefix of [`users/${uid}/`, `contributions/${uid}/`, `planting_photos/${uid}/`, `service_provider_licenses/${uid}/`, `listings/${uid}/`, `marketplace_sellers/${uid}/`]) {
    try {
      await bucket.deleteFiles({ prefix });
    } catch (_) {
      // A missing folder is fine; keep going.
    }
  }

  // Last: the sign-in account, so a failure above can be retried.
  await getAuth().deleteUser(uid);
  return { ok: true };
}
