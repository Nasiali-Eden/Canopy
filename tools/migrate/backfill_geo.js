#!/usr/bin/env node
/**
 * Canopy — geography + marketplace backfill
 *
 * Two jobs, both idempotent, both safe to re-run:
 *
 *   1. GEO BACKFILL
 *      Resolves every document's legacy free-text location onto the canonical
 *      registry in assets/geo/kenya.json and writes the flat geo_* fields the
 *      app now queries (geo_county_id, geo_region_id, geo_country_id,
 *      geo_area_id, geo_label, geo_point).
 *
 *      Before this, "where" was stored five incompatible ways —
 *      CommunityUser.location (free string), Organization.city (a String that
 *      defaults to the COUNTRY 'Kenya'), ActivityLocation {area, city, venue},
 *      MarketplaceListing {city, country, continent}, and market_listings
 *      .location_text — and only the Heritage layer had a real hierarchy.
 *      None of the others could be filtered on.
 *
 *   2. LISTING MIGRATION
 *      Converts the retired `market_listings` collection into unified
 *      /listings documents. market_listings was written as a snake_case mirror
 *      of `organizations/{id}/marketOrders` and read back filtered by
 *      `org_id == myOrg`, so buy orders were invisible to everyone except the
 *      organisation that posted them. In /listings they carry an explicit
 *      side + intent and are public within their geography.
 *
 * Usage (mirrors tools/seed):
 *   cd tools/migrate && npm install
 *   node backfill_geo.js --dry-run          # report only, writes nothing
 *   node backfill_geo.js                    # apply
 *   node backfill_geo.js --key /path/to/serviceAccount.json
 *   node backfill_geo.js --only=geo         # or --only=listings
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// ─────────────────────────────────────────────────────────────────────────────
// ARGS
// ─────────────────────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const DRY = args.includes('--dry-run');
const only = (args.find((a) => a.startsWith('--only=')) || '').split('=')[1] || 'all';
const keyArg = args.find((a) => a.startsWith('--key'));
const keyPath = keyArg
  ? (keyArg.includes('=') ? keyArg.split('=')[1] : args[args.indexOf(keyArg) + 1])
  : path.join(__dirname, 'serviceAccount.json');

if (!fs.existsSync(keyPath)) {
  console.error(`No service account key at ${keyPath}`);
  console.error('Firebase console → Project settings → Service accounts → Generate new private key');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// GEO REGISTRY — same asset the app loads, same resolution rules
// ─────────────────────────────────────────────────────────────────────────────

const registry = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../../assets/geo/kenya.json'), 'utf8')
);

const countyById = new Map();
const areaById = new Map();
const countyByName = new Map();
const areaByName = new Map();

for (const c of registry.counties) {
  countyById.set(c.id, c);
  countyByName.set(c.name.toLowerCase(), c);
  countyByName.set(c.name.toLowerCase().replace(/[^a-z ]/g, ''), c);
  for (const a of c.areas) {
    const withCounty = { ...a, countyId: c.id };
    areaById.set(a.id, withCounty);
    if (!areaByName.has(a.name.toLowerCase())) areaByName.set(a.name.toLowerCase(), withCounty);
    // Legacy town keys — "Eldoret" resolves to Uasin Gishu, "Thika" to Kiambu.
    if (a.legacy_city && !countyByName.has(a.legacy_city.toLowerCase())) {
      countyByName.set(a.legacy_city.toLowerCase(), c);
    }
  }
}

const clean = (s) => (typeof s === 'string' ? s.trim() : '');

function lookupCounty(name) {
  const k = clean(name).toLowerCase();
  if (!k) return null;
  return countyByName.get(k) || countyByName.get(k.replace(/\s*county\s*$/, '')) || null;
}

function lookupArea(name) {
  const k = clean(name).toLowerCase();
  return k ? areaByName.get(k) || null : null;
}

function locationForCounty(c, extra = {}) {
  return {
    geo_country_id: registry.country.id,
    geo_country_name: registry.country.name,
    geo_region_id: c.region_id,
    geo_region_name: c.region_name,
    geo_county_id: c.id,
    geo_county_name: c.name,
    geo_area_id: null,
    geo_area_name: null,
    ...extra,
  };
}

/** Mirrors GeoRegistry.resolve() in lib/Services/Geo/geo_registry.dart. */
function resolve({ area, county, country, freeText, lat, lng }) {
  let out = null;

  const a = lookupArea(area) || lookupArea(freeText);
  if (a) {
    const c = countyById.get(a.countyId);
    out = locationForCounty(c, { geo_area_id: a.id, geo_area_name: a.name });
    if (lat == null) { lat = a.lat; lng = a.lng; }
  }

  if (!out) {
    const c = lookupCounty(county) || lookupCounty(area) || lookupCounty(freeText);
    if (c) {
      out = locationForCounty(c);
      if (lat == null) { lat = c.lat; lng = c.lng; }
    }
  }

  // "Kibera, Nairobi" — split and retry.
  if (!out) {
    for (const raw of [freeText, area, county]) {
      if (!clean(raw) || !raw.includes(',')) continue;
      const parts = raw.split(',').map((s) => s.trim());
      const c = lookupCounty(parts[parts.length - 1]);
      if (c) {
        const inCounty = c.areas.find((x) => x.name.toLowerCase() === parts[0].toLowerCase());
        out = inCounty
          ? locationForCounty(c, { geo_area_id: inCounty.id, geo_area_name: inCounty.name })
          : locationForCounty(c);
        if (lat == null) { lat = (inCounty || c).lat; lng = (inCounty || c).lng; }
        break;
      }
      const a2 = lookupArea(parts[0]);
      if (a2) {
        out = locationForCounty(countyById.get(a2.countyId), {
          geo_area_id: a2.id, geo_area_name: a2.name,
        });
        break;
      }
    }
  }

  // Country only. Note this is where Organization.city === 'Kenya' lands —
  // a country name sitting in a city field, filed at the country tier rather
  // than invented into a county.
  if (!out && clean(country || county || freeText).toLowerCase() === 'kenya') {
    out = {
      geo_country_id: registry.country.id,
      geo_country_name: registry.country.name,
      geo_region_id: null, geo_region_name: null,
      geo_county_id: null, geo_county_name: null,
      geo_area_id: null, geo_area_name: null,
    };
  }

  if (!out) return null;

  const label = [out.geo_area_name, out.geo_county_name].filter(Boolean).join(', ')
    || out.geo_region_name || out.geo_country_name || '';
  out.geo_label = label;
  if (lat != null && lng != null) {
    out.geo_point = new admin.firestore.GeoPoint(lat, lng);
  }
  return out;
}

function resolveFromDoc(d) {
  const coords = d.coordinates || (d.location && typeof d.location === 'object' && d.location.lat != null ? d.location : null);
  const legacyPoint = d.location && d.location.latitude != null ? d.location : null;
  return resolve({
    area: d.area,
    county: d.city || d.county,
    country: d.country,
    freeText: typeof d.location === 'string' ? d.location : (d.location_text || d.locationText),
    lat: coords ? coords.lat : (legacyPoint ? legacyPoint.latitude : d.lat),
    lng: coords ? coords.lng : (legacyPoint ? legacyPoint.longitude : d.lng),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// JOB 1 — GEO BACKFILL
// ─────────────────────────────────────────────────────────────────────────────

// Nested-location collections read their sub-map instead of the doc root.
const GEO_TARGETS = [
  { col: 'Users' },
  { col: 'members' },
  { col: 'users' },
  { col: 'organizations' },
  { col: 'marketplace_sellers' },
  { col: 'activities', nested: 'location' },
  { col: 'listings' },
  { col: 'map_pins' },
];

async function backfillGeo() {
  let total = 0, written = 0, already = 0, unresolved = 0;
  const misses = new Map();

  for (const target of GEO_TARGETS) {
    let snap;
    try {
      snap = await db.collection(target.col).get();
    } catch (e) {
      console.log(`  ${target.col.padEnd(22)} skipped (${e.code || e.message})`);
      continue;
    }

    let colWritten = 0, colAlready = 0, colMiss = 0;
    let batch = db.batch();
    let pending = 0;

    for (const doc of snap.docs) {
      total++;
      const data = doc.data();
      if (data.geo_county_id || data.geo_country_id) { already++; colAlready++; continue; }

      const source = target.nested && data[target.nested] && typeof data[target.nested] === 'object'
        ? { ...data[target.nested], country: data.country }
        : data;
      const geo = resolveFromDoc(source);

      if (!geo) {
        unresolved++; colMiss++;
        const hint = clean(source.city) || clean(source.area) ||
          (typeof source.location === 'string' ? source.location : '') ||
          clean(source.location_text) || '(empty)';
        misses.set(hint, (misses.get(hint) || 0) + 1);
        continue;
      }

      if (!DRY) {
        batch.set(doc.ref, { ...geo, geo_backfilled_at: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        if (++pending >= 400) { await batch.commit(); batch = db.batch(); pending = 0; }
      }
      written++; colWritten++;
    }

    if (!DRY && pending > 0) await batch.commit();
    console.log(`  ${target.col.padEnd(22)} ${String(snap.size).padStart(5)} docs · ${colWritten} written · ${colAlready} already · ${colMiss} unresolved`);
  }

  console.log(`\n  TOTAL ${total} scanned · ${written} written · ${already} already tagged · ${unresolved} unresolved`);
  if (misses.size) {
    console.log('\n  Unresolved location values (add aliases to assets/geo/kenya.json if these matter):');
    [...misses.entries()].sort((a, b) => b[1] - a[1]).slice(0, 25)
      .forEach(([v, n]) => console.log(`    ${String(n).padStart(4)}×  "${v}"`));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JOB 2 — market_listings → /listings
// ─────────────────────────────────────────────────────────────────────────────

const INTENT = {
  buy_order: 'seeking',
  recurring_buy: 'seeking',
  sell_listing: 'offering',
};

async function migrateListings() {
  let snap;
  try {
    snap = await db.collection('market_listings').get();
  } catch (e) {
    console.log(`  market_listings unreadable (${e.code || e.message}) — nothing to migrate`);
    return;
  }

  let migrated = 0, skipped = 0;
  let batch = db.batch();
  let pending = 0;

  for (const doc of snap.docs) {
    const d = doc.data();
    const existing = await db.collection('listings').doc(doc.id).get();
    if (existing.exists) { skipped++; continue; }

    const geo = resolveFromDoc(d) || {};
    const qty = typeof d.quantity_kg === 'number' ? d.quantity_kg : null;
    const isRecurring = d.is_recurring === true;

    const listing = {
      side: 'supply',
      intent: INTENT[d.listing_type] || 'offering',
      status: d.status === 'active' ? 'active' : 'closed',
      title: d.sub_type_label || d.category_label || 'Material listing',
      story: d.notes || '',
      tagline: d.category_label || '',
      category: 'materials',
      materials: [],
      materialSubTypeId: d.sub_type_id || null,
      materialGrade: d.grade || null,
      images: d.image_url ? [d.image_url] : [],
      seller: {
        sellerId: d.posted_by_uid || '',
        shopName: d.org_name || '',
        shopLogoUrl: null,
        city: geo.geo_county_name || '',
        country: geo.geo_country_name || 'Kenya',
        badgeTier: 'none',
        averageRating: 0,
        totalSales: 0,
      },
      orgId: d.org_id || null,
      orgName: d.org_name || null,
      postedByUid: d.posted_by_uid || '',
      pricing: {
        amountKes: typeof d.price_per_unit === 'number' ? d.price_per_unit : 0,
        unit: d.unit === 'kg' ? 'perKg' : 'perItem',
        negotiable: false,
        originalAmountKes: null,
        currency: 'KES',
      },
      quantity: { quantityKg: qty, minimumKg: qty, filledKg: 0, stockCount: 1 },
      fulfilment: {
        willCollect: d.can_collect === true,
        acceptsDelivery: d.can_deliver === true,
        isRecurring,
      },
      materialDna: [],
      impact: { kgDiverted: 0, impactScore: 0, collectorsCredited: 0, royaltyPaidKes: 0 },
      circularBadge: 'none',
      tags: [],
      isFeatured: false,
      viewCount: 0,
      wishlistCount: 0,
      responseCount: typeof d.responses_count === 'number' ? d.responses_count : 0,
      averageRating: 0,
      reviewCount: 0,
      createdAt: d.created_at || admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      // Standing orders never expire; one-off buy orders get the same 30-day
      // window the app applies at creation.
      expiresAt: isRecurring || !d.created_at
        ? null
        : admin.firestore.Timestamp.fromMillis(d.created_at.toMillis() + 30 * 24 * 3600 * 1000),
      migratedFrom: 'market_listings',
      ...geo,
    };

    if (!DRY) {
      batch.set(db.collection('listings').doc(doc.id), listing);
      if (++pending >= 300) { await batch.commit(); batch = db.batch(); pending = 0; }
    }
    migrated++;
  }

  if (!DRY && pending > 0) await batch.commit();
  console.log(`  market_listings ${snap.size} docs · ${migrated} migrated · ${skipped} already in /listings`);
}

// ─────────────────────────────────────────────────────────────────────────────

(async () => {
  console.log(`\nCanopy backfill${DRY ? '  [DRY RUN — no writes]' : ''}`);
  console.log(`Registry: ${registry.counties.length} counties · ${registry.regions.length} regions\n`);

  if (only === 'all' || only === 'geo') {
    console.log('GEO BACKFILL');
    await backfillGeo();
    console.log('');
  }
  if (only === 'all' || only === 'listings') {
    console.log('LISTING MIGRATION');
    await migrateListings();
    console.log('');
  }

  console.log(DRY ? 'Dry run complete — re-run without --dry-run to apply.\n' : 'Done.\n');
  process.exit(0);
})().catch((e) => {
  console.error('\nFailed:', e);
  process.exit(1);
});
