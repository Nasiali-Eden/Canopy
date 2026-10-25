/**
 * Canopy trusted API — auth & authorization helpers.
 *
 * These wrap firebase-functions' onCall handlers so every callable function
 * in this project enforces "signed in" and "correct role/org" the same way,
 * instead of each function re-implementing its own ad-hoc check (which is
 * how the current client-writes-everything state happened in the first
 * place — see CARDANO_INTEGRATION_ROADMAP.md, "Critical blockers").
 */

import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";

export interface AuthedContext {
  uid: string;
  orgId: string | null;
  role: string | null;
}

/** Throws HttpsError('unauthenticated', ...) if there's no verified caller. */
export function requireSignedIn(request: CallableRequest): string {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  return request.auth.uid;
}

/**
 * Reads the caller's own Users/{uid} doc via the Admin SDK (bypasses rules
 * by design) to resolve orgId/role server-side. Never trust an orgId or
 * role passed in the request payload — always resolve it here.
 */
export async function loadCallerContext(uid: string): Promise<AuthedContext> {
  const db = getFirestore();
  const snap = await db.collection("Users").doc(uid).get();
  const data = snap.data() ?? {};
  return {
    uid,
    orgId: typeof data.orgId === "string" ? data.orgId : null,
    role: typeof data.role === "string" ? data.role : null,
  };
}

/** Throws HttpsError('permission-denied', ...) unless the caller belongs to orgId. */
export function requireOrgMember(ctx: AuthedContext, orgId: string): void {
  if (ctx.orgId !== orgId) {
    throw new HttpsError(
      "permission-denied",
      `Caller is not a member of organisation ${orgId}.`
    );
  }
}

/**
 * Convenience wrapper: verifies sign-in, loads context, and hands both to
 * the handler. Every trusted-API endpoint should go through this rather
 * than reading request.auth directly, so the "how do we resolve identity"
 * logic only lives in one place.
 */
export async function withAuthedContext<TData, TResult>(
  request: CallableRequest<TData>,
  handler: (data: TData, ctx: AuthedContext) => Promise<TResult>
): Promise<TResult> {
  const uid = requireSignedIn(request);
  const ctx = await loadCallerContext(uid);
  return handler(request.data, ctx);
}
