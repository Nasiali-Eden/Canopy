/**
 * Deterministic canonicalization + hashing, used by anything that will
 * eventually be anchored on Cardano (Blockchain Stage 0, Week 2 of the
 * Cardano plan). Built now, in Week 1, because "agree the evidence schema"
 * requires knowing exactly how a record turns into stable bytes — but no
 * caller wires this into an anchor submission yet. That's Week 2/3 scope
 * (Merkle batching, Preprod submission) and stays out of this file.
 *
 * Sorting object keys recursively before stringifying is what makes the
 * hash reproducible regardless of field insertion order — the same logical
 * record must always hash identically, per the plan's Week 2 exit gate:
 * "identical logical evidence always yields identical bytes/hash."
 */

import { createHash } from "crypto";

export function canonicalize(value: unknown): string {
  return JSON.stringify(sortKeysDeep(value));
}

function sortKeysDeep(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(sortKeysDeep);
  }
  if (value !== null && typeof value === "object") {
    const sorted: Record<string, unknown> = {};
    for (const key of Object.keys(value as Record<string, unknown>).sort()) {
      sorted[key] = sortKeysDeep((value as Record<string, unknown>)[key]);
    }
    return sorted;
  }
  return value;
}

export function canonicalHash(value: unknown): string {
  return createHash("sha256").update(canonicalize(value)).digest("hex");
}

/**
 * Deny-list check for the privacy boundary the Cardano plan is explicit
 * about: "No PII, precise GPS, phone number, photo URL, Storage URL,
 * M-Pesa reference, or raw Firebase UID enters an anchor payload." This
 * throws rather than silently stripping fields, because a silent strip is
 * how a privacy bug ships unnoticed.
 */
const ANCHOR_PAYLOAD_DENY_LIST = [
  "phone",
  "phoneNumber",
  "email",
  "photoUrl",
  "photoUrls",
  "storageUrl",
  "gps",
  "latitude",
  "longitude",
  "mpesaReference",
  "uid",
  "userId",
  "authorId",
] as const;

export function assertAnchorPayloadIsSafe(value: Record<string, unknown>): void {
  const offending = ANCHOR_PAYLOAD_DENY_LIST.filter((key) => key in value);
  if (offending.length > 0) {
    throw new Error(
      `Refusing to hash payload for anchoring: contains denied field(s) ${offending.join(", ")}. ` +
        "Anchor payloads must be privacy-safe (opaque IDs and aggregate/derived fields only)."
    );
  }
}
