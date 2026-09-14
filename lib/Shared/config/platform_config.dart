// lib/Shared/config/platform_config.dart
//
// Phase 5.1 of the Minimal Release Roadmap — "special" (blockchain/
// financial-literacy) articles are restricted to one organisation (Super
// Admin) for now. There's no admin/role infrastructure elsewhere in the
// app to hook into yet, so this file is the single place that identifies
// which org that is, until a real admin system exists.
//
// ── ACTION NEEDED ──────────────────────────────────────────────────────
// Replace the placeholder below with SHIELD International's actual
// `organizations/{orgId}` document id (Firestore console → organizations
// → find SHIELD's doc → copy its id from the URL/doc path). Until you do,
// [kSuperAdminOrgId] matches no real org, so the 'special' category stays
// hidden and the publish banner in Articles never appears — which is the
// safe default, not a broken one.
//
// This same literal value must also be pasted into firestore.rules'
// isSuperAdminOrg() function (search that file for "kSuperAdminOrgId") —
// Firestore rules can't import Dart constants, so the two are kept in
// sync by hand. If they ever drift, the rules value is what actually
// governs writes; this one only controls what the UI offers.
//
// Longer-term this should move to a real per-org role/flag in Firestore
// (the `organizations/{orgId}.isSuperAdmin` field this same gate already
// checks as a second path — see isSuperAdminOrg() in both
// create_article.dart and special_articles_banner.dart) instead of a
// single hardcoded id, once there's more than one org that could
// plausibly need this kind of platform-level permission.
const String kSuperAdminOrgId = 'REPLACE_WITH_SHIELD_ORG_ID';
