import { initializeApp } from "firebase-admin/app";
import { onCall } from "firebase-functions/v2/https";
import { withAuthedContext } from "./auth";
import { deleteMyAccountImpl } from "./accountDeletion";
import { inviteOrgRepImpl, acceptOrgInviteImpl, removeOrgAccessImpl, switchActiveOrgImpl } from "./orgAccess";

initializeApp();

// Organisation access: more than one representative, and more than one organisation.
export const inviteOrgRep = onCall(async request =>
  withAuthedContext(request, async (data: { email?: string; accessRole?: string; teamId?: string | null; teamName?: string | null }, ctx) =>
    inviteOrgRepImpl(data, ctx)));

export const acceptOrgInvite = onCall(async request =>
  withAuthedContext(request, async (data: { inviteId?: string }, ctx) =>
    acceptOrgInviteImpl(data, ctx, { email: request.auth?.token.email, email_verified: request.auth?.token.email_verified })));

export const removeOrgAccess = onCall(async request =>
  withAuthedContext(request, async (data: { memberId?: string }, ctx) => removeOrgAccessImpl(data, ctx)));

export const switchActiveOrg = onCall(async request =>
  withAuthedContext(request, async (data: { orgId?: string }, ctx) => switchActiveOrgImpl(data, ctx)));

// A person deleting their own account and personal data.
export const deleteMyAccount = onCall(async request =>
  withAuthedContext(request, async (_data: Record<string, never>, ctx) => deleteMyAccountImpl(ctx.uid)));
