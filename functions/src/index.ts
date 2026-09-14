import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { withAuthedContext, requireOrgMember } from "./auth";
import { canonicalHash } from "./canonical";
import { calculatePoints, SCORING_VERSION } from "./scoring";
initializeApp();
export const pingTrustedApi = onCall(async request => withAuthedContext(request, async (_data, ctx) => ({ ok: true, ...ctx, serverTime: new Date().toISOString() })));

// Verifier authority comes from administrator-provisioned Auth claims.
export const confirmContribution = onCall(async request =>
  withAuthedContext(request, async (data: { contributionId: string }, ctx) => {
    if (!data || typeof data.contributionId !== "string" || !data.contributionId || data.contributionId.includes("/")) throw new HttpsError("invalid-argument", "A valid contributionId is required.");
    if (request.auth?.token.verifier !== true) throw new HttpsError("permission-denied", "An approved verifier is required.");
    const db = getFirestore();
    const ref = db.collection("contributions").doc(data.contributionId);
    return db.runTransaction(async tx => {
      const snap = await tx.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Contribution not found.");
      const c = snap.data()!;
      if (typeof c.activityId !== "string" || !c.activityId || c.activityId.includes("/") || c.deleted === true || typeof c.userId !== "string") throw new HttpsError("failed-precondition", "An active contribution linked to an organisation activity is required.");
      if (c.userId === ctx.uid) throw new HttpsError("permission-denied", "You cannot verify your own contribution.");
      const activity = await tx.get(db.collection("activities").doc(c.activityId));
      const orgId = activity.data()?.orgId;
      if (typeof orgId !== "string" || !orgId) throw new HttpsError("failed-precondition", "Activity has no organisation.");
      requireOrgMember(ctx, orgId);
      const awardRef = db.collection("pointAwards").doc(data.contributionId);
      const award = await tx.get(awardRef);
      if (award.exists) return { contributionId: data.contributionId, confirmedPoints: award.data()!.points, alreadyConfirmed: true };
      if (c.status !== "pending" || c.confirmationStatus === "confirmed") throw new HttpsError("failed-precondition", "Only pending contributions can be confirmed. Legacy confirmations require reconciliation.");
      let points: number;
      try { points = calculatePoints(c); }
      catch (error) { throw new HttpsError("invalid-argument", (error as Error).message); }
      const userRef = db.collection("Users").doc(c.userId);
      const user = await tx.get(userRef);
      if (!user.exists) throw new HttpsError("failed-precondition", "Contributor profile is missing.");
      // Legacy client-controlled totals never enter the verified ranking.
      const prior = user.data()!.rankingVersion === SCORING_VERSION ? Number(user.data()!.impact_points ?? 0) : 0;
      const evidenceHash = canonicalHash({ contributionId: data.contributionId, points, type: c.type, hours: c.hours ?? null, effort: c.effort ?? null, materials: c.materials ?? [], orgId, confirmedBy: ctx.uid, scoringVersion: SCORING_VERSION });
      tx.create(awardRef, { userId: c.userId, orgId, points, scoringVersion: SCORING_VERSION, evidenceHash, createdAt: FieldValue.serverTimestamp() });
      tx.update(ref, { confirmedImpactPoints: points, confirmationStatus: "confirmed", status: "verified", confirmedBy: ctx.uid, confirmedAt: FieldValue.serverTimestamp(), evidenceHash, scoringVersion: SCORING_VERSION });
      tx.update(userRef, { impact_points: prior + points, rankingVersion: SCORING_VERSION, verifiedContributions: user.data()!.rankingVersion === SCORING_VERSION ? Number(user.data()!.verifiedContributions ?? 0) + 1 : 1, pointsUpdatedAt: FieldValue.serverTimestamp() });
      return { contributionId: data.contributionId, confirmedPoints: points, alreadyConfirmed: false };
    });
  }));

// "Log Work" QR check-in (Events). An org creates an Event (client-writable —
// see firestore.rules) and displays its qrPayload as a QR code; a user scans
// it and this callable validates + awards points server-side, the same
// pattern as confirmContribution above. Client code never writes
// Events/{id}/checkins/{uid} or Users/{uid}.impact_points directly for this
// flow — firestore.rules denies both, on purpose, so this function is the
// only path that can award a check-in's points.
export const checkInToEvent = onCall(async request =>
  withAuthedContext(request, async (data: { eventId: string; token: string }, ctx) => {
    if (!data || typeof data.eventId !== "string" || !data.eventId || typeof data.token !== "string" || !data.token) {
      throw new HttpsError("invalid-argument", "eventId and token are required.");
    }
    const db = getFirestore();
    const eventRef = db.collection("Events").doc(data.eventId);
    const checkinRef = eventRef.collection("checkins").doc(ctx.uid);
    const userRef = db.collection("Users").doc(ctx.uid);
    return db.runTransaction(async tx => {
      const eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) throw new HttpsError("not-found", "This event code was not found.");
      const event = eventSnap.data()!;
      if (event.active !== true || event.qrToken !== data.token) {
        throw new HttpsError("failed-precondition", "This code has expired — the organiser has ended the event.");
      }
      const existing = await tx.get(checkinRef);
      if (existing.exists) {
        return { pointsAwarded: Number(existing.data()!.pointsAwarded ?? 0), alreadyCheckedIn: true };
      }
      const points = typeof event.pointsPerCheckin === "number" ? event.pointsPerCheckin : 10;
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw new HttpsError("failed-precondition", "Your profile is missing — sign in again and retry.");
      const priorPoints = Number(userSnap.data()!.impact_points ?? 0);
      tx.create(checkinRef, {
        userId: ctx.uid,
        checkedInAt: FieldValue.serverTimestamp(),
        pointsAwarded: points,
        eventTitle: typeof event.title === "string" ? event.title : null,
        orgName: typeof event.orgName === "string" ? event.orgName : null,
      });
      tx.update(userRef, { impact_points: priorPoints + points, pointsUpdatedAt: FieldValue.serverTimestamp() });
      return { pointsAwarded: points, alreadyCheckedIn: false };
    });
  }));
