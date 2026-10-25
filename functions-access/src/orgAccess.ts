/**
 * Organisation access: more than one person can run an organisation.
 *
 *  - The person who registers the organisation is its owner.
 *  - The owner (or an admin they appoint) invites others by email.
 *  - An invite grants nothing until the invited person signs in with a
 *    VERIFIED email that matches the invite and accepts it.
 *  - Access is `Users/{uid}.orgId` plus an `org_rep/{uid}` record, both of which
 *    clients cannot write — hence these functions.
 */

import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const ACCESS_ROLES = ["admin", "editor"] as const;
type AccessRole = (typeof ACCESS_ROLES)[number];

// Roster role shown in People & teams for each access role.
const ROSTER_ROLE: Record<AccessRole, string> = { admin: "admin", editor: "coordinator" };

const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

/** Owner (the registering rep) or an admin the owner appointed. */
export async function requireOrgAdmin(uid: string, orgId: string): Promise<void> {
  const db = getFirestore();
  const org = (await db.collection("organizations").doc(orgId).get()).data();
  if (!org) throw new HttpsError("not-found", "Organisation not found.");
  if (org.org_rep_uid === uid) return;
  const rep = (await db.collection("org_rep").doc(uid).get()).data();
  if (rep?.orgId === orgId && rep?.accessRole === "admin") return;
  throw new HttpsError("permission-denied", "Only an owner or admin can manage who has access.");
}

/**
 * What access a person has in an organisation: 'owner' (they registered it), an
 * access role from an accepted invite, or null.
 */
async function accessIn(uid: string, orgId: string): Promise<{ role: string; org: FirebaseFirestore.DocumentData } | null> {
  const db = getFirestore();
  const org = (await db.collection("organizations").doc(orgId).get()).data();
  if (!org) return null;
  if (org.org_rep_uid === uid) return { role: "owner", org };
  const q = await db
    .collection("OrgMembers")
    .where("orgId", "==", orgId)
    .where("userId", "==", uid)
    .where("grantsAccess", "==", true)
    .where("status", "==", "active")
    .limit(1)
    .get();
  if (q.empty) return null;
  return { role: String(q.docs[0].data().accessRole ?? "editor"), org };
}

/** Points the person's account at one organisation (the one they're working in). */
async function activate(uid: string, orgId: string, role: string, org: FirebaseFirestore.DocumentData): Promise<void> {
  const db = getFirestore();
  const orgName = String(org.org_name ?? org.name ?? "Organisation");
  const user = (await db.collection("Users").doc(uid).get()).data() ?? {};
  const email = String(user.email ?? "");
  const name = String(user.name ?? [user.FirstName, user.LastName].filter(Boolean).join(" ") ?? "").trim();
  const batch = db.batch();
  batch.set(db.collection("Users").doc(uid), { orgId, orgName, role: "Org Rep" }, { merge: true });
  batch.set(db.collection("org_rep").doc(uid), {
    uid,
    email,
    name: name || email,
    org_name: orgName,
    orgId,
    accessRole: role === "owner" ? "admin" : role,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
}

/** Every organisation this person can work in. */
async function orgsFor(uid: string): Promise<string[]> {
  const db = getFirestore();
  const ids = new Set<string>();
  (await db.collection("organizations").where("org_rep_uid", "==", uid).get()).docs.forEach(d => ids.add(d.id));
  (await db.collection("OrgMembers").where("userId", "==", uid).where("grantsAccess", "==", true).where("status", "==", "active").get())
    .docs.forEach(d => ids.add(String(d.data().orgId)));
  return [...ids];
}

export async function switchActiveOrgImpl(data: { orgId?: string }, caller: { uid: string }): Promise<{ orgId: string; orgName: string }> {
  const orgId = data?.orgId;
  if (!orgId || typeof orgId !== "string" || orgId.includes("/")) throw new HttpsError("invalid-argument", "A valid organisation is required.");
  const access = await accessIn(caller.uid, orgId);
  if (!access) throw new HttpsError("permission-denied", "You don't have access to that organisation.");
  await activate(caller.uid, orgId, access.role, access.org);
  return { orgId, orgName: String(access.org.org_name ?? access.org.name ?? "Organisation") };
}

export async function inviteOrgRepImpl(
  data: { email?: string; accessRole?: string; teamId?: string | null; teamName?: string | null },
  caller: { uid: string; orgId: string | null }
): Promise<{ id: string }> {
  if (!caller.orgId) throw new HttpsError("failed-precondition", "You are not part of an organisation.");
  await requireOrgAdmin(caller.uid, caller.orgId);

  const email = (data?.email ?? "").trim().toLowerCase();
  if (!EMAIL.test(email)) throw new HttpsError("invalid-argument", "Enter a valid email.");
  const role = data?.accessRole as AccessRole;
  if (!ACCESS_ROLES.includes(role)) throw new HttpsError("invalid-argument", "Choose Admin or Editor.");

  const db = getFirestore();
  const existing = await db
    .collection("OrgMembers")
    .where("orgId", "==", caller.orgId)
    .where("contact", "==", email)
    .get();
  const live = existing.docs.find(d => ["invited", "active"].includes(d.data().status) && d.data().grantsAccess === true);
  if (live) throw new HttpsError("already-exists", "That person already has an invite or access.");

  const ref = db.collection("OrgMembers").doc();
  await ref.set({
    orgId: caller.orgId,
    contact: email,
    contactType: "email",
    name: null,
    role: ROSTER_ROLE[role],
    status: "invited",
    grantsAccess: true,
    accessRole: role,
    ...(data.teamId ? { teamId: data.teamId } : {}),
    ...(data.teamName ? { teamName: data.teamName } : {}),
    invitedBy: caller.uid,
    invitedAt: FieldValue.serverTimestamp(),
  });
  return { id: ref.id };
}

export async function acceptOrgInviteImpl(
  data: { inviteId?: string },
  caller: { uid: string; orgId: string | null },
  token: { email?: string; email_verified?: boolean }
): Promise<{ orgId: string; orgName: string }> {
  const inviteId = data?.inviteId;
  if (!inviteId || typeof inviteId !== "string" || inviteId.includes("/")) {
    throw new HttpsError("invalid-argument", "A valid invite is required.");
  }
  const email = (token.email ?? "").toLowerCase();
  if (!email) throw new HttpsError("failed-precondition", "Your account has no email.");
  // Without this, anyone could register an unverified account with an invited
  // address and claim the invite.
  if (token.email_verified !== true) {
    throw new HttpsError("failed-precondition", "email-not-verified");
  }

  const db = getFirestore();
  const inviteRef = db.collection("OrgMembers").doc(inviteId);
  const invite = (await inviteRef.get()).data();
  if (
    !invite ||
    invite.status !== "invited" ||
    invite.grantsAccess !== true ||
    invite.contactType !== "email" ||
    String(invite.contact).toLowerCase() !== email
  ) {
    throw new HttpsError("not-found", "This invite is no longer valid.");
  }
  const orgId = String(invite.orgId);
  const org = (await db.collection("organizations").doc(orgId).get()).data();
  if (!org) throw new HttpsError("not-found", "Organisation not found.");
  const orgName = String(org.org_name ?? org.name ?? "Organisation");

  const userRef = db.collection("Users").doc(caller.uid);
  const user = (await userRef.get()).data() ?? {};
  const name = String(user.name ?? [user.FirstName, user.LastName].filter(Boolean).join(" ") ?? "").trim();

  const batch = db.batch();
  // They may already run other organisations; the one they just accepted becomes
  // the one they're working in, and they can switch back at any time.
  batch.set(userRef, { orgId, orgName, role: "Org Rep" }, { merge: true });
  batch.set(db.collection("org_rep").doc(caller.uid), {
    uid: caller.uid,
    email,
    name: name || email,
    org_name: orgName,
    orgId,
    accessRole: invite.accessRole,
    createdAt: FieldValue.serverTimestamp(),
  });
  batch.update(inviteRef, {
    status: "active",
    userId: caller.uid,
    name: name || null,
    joinedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return { orgId, orgName };
}

export async function removeOrgAccessImpl(
  data: { memberId?: string },
  caller: { uid: string; orgId: string | null }
): Promise<{ ok: true }> {
  const memberId = data?.memberId;
  if (!memberId || typeof memberId !== "string" || memberId.includes("/")) {
    throw new HttpsError("invalid-argument", "A valid member is required.");
  }
  if (!caller.orgId) throw new HttpsError("failed-precondition", "You are not part of an organisation.");
  await requireOrgAdmin(caller.uid, caller.orgId);

  const db = getFirestore();
  const ref = db.collection("OrgMembers").doc(memberId);
  const member = (await ref.get()).data();
  if (!member || member.orgId !== caller.orgId) throw new HttpsError("not-found", "Member not found.");

  const org = (await db.collection("organizations").doc(caller.orgId).get()).data();
  const targetUid = typeof member.userId === "string" ? member.userId : null;
  if (targetUid && org?.org_rep_uid === targetUid) {
    throw new HttpsError("failed-precondition", "The owner can't be removed.");
  }

  await ref.update({ status: "removed", removedAt: FieldValue.serverTimestamp(), removedBy: caller.uid });
  if (targetUid && member.grantsAccess === true) {
    const target = (await db.collection("Users").doc(targetUid).get()).data() ?? {};
    if (target.orgId === caller.orgId) {
      // They were working in this organisation: move them to another one they
      // still have access to, or back to a plain member account.
      const others = (await orgsFor(targetUid)).filter(id => id !== caller.orgId);
      const next = others.length ? await accessIn(targetUid, others[0]) : null;
      if (next) {
        await activate(targetUid, others[0], next.role, next.org);
      } else {
        await db.collection("Users").doc(targetUid).set({ orgId: FieldValue.delete(), orgName: FieldValue.delete(), role: "User" }, { merge: true });
        await db.collection("org_rep").doc(targetUid).delete();
      }
    }
  }
  return { ok: true };
}
