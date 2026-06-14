#!/usr/bin/env node
/*
 * CLI heritage seed — mirror of lib/Culture/Heritage/Tools/seed_hardcoded_culture.dart
 *
 * Writes the same doc ids + data as the in-app seed, so the two are
 * interchangeable and idempotent (re-running skips existing entries and never
 * clobbers an org-uploaded bg_image_url).
 *
 * Usage:
 *   cd tools/seed
 *   npm install
 *   node seed_heritage.js --key /abs/path/serviceAccount.json
 *     (or set GOOGLE_APPLICATION_CREDENTIALS and omit --key)
 *
 * The service account JSON comes from Firebase console →
 *   Project settings → Service accounts → Generate new private key.
 * Keep it OUT of git.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// ── args ────────────────────────────────────────────────────────────────────
const argv = process.argv.slice(2);
function arg(name) {
  const i = argv.indexOf(name);
  return i >= 0 && i + 1 < argv.length ? argv[i + 1] : null;
}

// Resolve a key path from --key, then GOOGLE_APPLICATION_CREDENTIALS, then a
// serviceAccount.json dropped next to this script (gitignored).
const localKey = path.join(__dirname, 'serviceAccount.json');
let keyPath = arg('--key') || process.env.GOOGLE_APPLICATION_CREDENTIALS || null;
if (!keyPath && fs.existsSync(localKey)) keyPath = localKey;

// ── init ──────────────────────────────────────────────────────────────────────
if (!keyPath) {
  console.error('No service-account credentials found.');
  console.error('Do ONE of:');
  console.error('  - Save the key as tools/seed/serviceAccount.json, then: node seed_heritage.js');
  console.error('  - node seed_heritage.js --key /abs/path/serviceAccount.json');
  console.error('  - set GOOGLE_APPLICATION_CREDENTIALS to the key path');
  console.error('Get the key: Firebase console -> Project settings -> Service accounts -> Generate new private key.');
  process.exit(1);
}
try {
  admin.initializeApp({
    credential: admin.credential.cert(require(path.resolve(keyPath))),
  });
} catch (e) {
  console.error('Failed to initialise firebase-admin with key:', keyPath);
  console.error(e.message);
  process.exit(1);
}
console.log(`[heritage-seed] using key: ${keyPath}`);

const db = admin.firestore();
// Force the REST transport — firebase-admin's default gRPC connection commonly
// stalls behind Windows/corporate networks & proxies (symptom: reads work, then
// writes hang). Must be set before any Firestore operation.
db.settings({ preferRest: true });
const Timestamp = admin.firestore.Timestamp;

const SEED_KEY = 'seed_hardcoded_culture_v1';
const COUNTRY_ID = 'country_kenya';
const COUNTRY_NAME = 'Kenya';

const slug = (s) =>
  s.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');

// ── data (verbatim from the Dart seed) ────────────────────────────────────────
const kenyaCommunities = [
  ['Luhya', 'Western Kenya', ['Kakamega', 'Bungoma', 'Vihiga', 'Trans Nzoia']],
  ['Luo', 'Western Kenya', ['Kisumu', 'Siaya', 'Homa Bay', 'Migori']],
  ['Kipsigis', 'Western Kenya', ['Kericho', 'Bomet']],
  ['Kikuyu', 'Central Kenya', ['Kiambu', 'Muranga', 'Nyeri', 'Kirinyaga']],
  ['Meru', 'Central Kenya', ['Meru', 'Tharaka-Nithi']],
  ['Embu', 'Central Kenya', ['Embu']],
  ['Kamba', 'Eastern & Coast', ['Machakos', 'Kitui', 'Makueni']],
  ['Mijikenda', 'Eastern & Coast', ['Mombasa', 'Kilifi', 'Kwale', 'Lamu']],
  ['Swahili', 'Eastern & Coast', ['Mombasa Old Town', 'Lamu']],
  ['Maasai', 'Rift Valley', ['Kajiado', 'Narok']],
  ['Kalenjin', 'Rift Valley', ['Uasin Gishu', 'Elgeyo', 'Nandi', 'Baringo']],
  ['Turkana', 'Rift Valley', ['Turkana']],
  ['Somali', 'North-Eastern', ['Garissa', 'Wajir', 'Mandera']],
  ['Borana', 'North-Eastern', ['Marsabit', 'Isiolo']],
];

const luhyaSubGroups = [
  ['Bukusu', 'Bungoma County'], ['Maragoli', 'Vihiga County'],
  ['Banyore', 'Vihiga County'], ['Batsotso', 'Kakamega'],
  ['Idakho', 'Kakamega'], ['Isukha', 'Kakamega'],
  ['Kabras', 'Kakamega'], ['Tiriki', 'Vihiga'],
  ['Wanga', 'Mumias, Kakamega'], ['Marachi', 'Busia County'],
  ['Samia', 'Busia County'], ['Kisa', 'Kakamega'],
  ['Marama', 'Kakamega'], ['Tachoni', 'Bungoma'],
  ['Nyala', 'Kakamega'], ['Banyala', 'Kakamega'],
  ['Khayo', 'Busia'], ['Nyore', 'Vihiga'],
];

// [name, note, communitySlug?, communityName?]
const kenyaFoods = [
  ['Ugali', 'National staple · all regions'],
  ['Nyama choma', 'Grilled meat tradition'],
  ['Mukimo', 'Kikuyu · Central highlands', 'kikuyu', 'Kikuyu'],
  ['Pilau', 'Swahili · Coastal tradition', 'swahili', 'Swahili'],
  ['Isombe', 'Luhya · Western Kenya', 'luhya', 'Luhya'],
  ['Githeri', 'Kikuyu · maize + beans', 'kikuyu', 'Kikuyu'],
  ['Ugali wa wimbi', 'Finger millet ugali'],
  ['Nyoyo', 'Maize + beans mix'],
];

const kenyaHistory = [
  ['~3000 BC', 'Cushitic peoples arrive',
    'Early Cushitic communities settle in the northern and eastern regions, bringing pastoralism and trade routes through the Horn of Africa.'],
  ['~1000 AD', 'Swahili coast trade networks',
    'Arab, Persian, and Indian traders establish coastal settlements. The Swahili culture emerges — a blend of Bantu and Islamic traditions that still defines Mombasa and Lamu.'],
  ['1400s', 'Bantu migration south',
    'Bantu-speaking communities including the Kikuyu, Luhya, Luo, and Kamba settle across the highlands and lake basin, establishing clan systems still intact today.'],
  ['1895', 'British East Africa Protectorate',
    'Colonial boundaries drawn with no regard for ethnic territories — communities divided, languages suppressed, land alienated in the highlands.'],
  ['1952', 'Mau Mau uprising',
    "Predominantly Kikuyu-led resistance against colonial land theft. Declared a state of emergency. A defining moment in Kenya's path to independence."],
  ['1963', 'Independence — Uhuru',
    'Kenya gains independence on December 12th. Jomo Kenyatta becomes the first Prime Minister. 45 ethnic communities now share one nation-state.'],
];

// [title, body, meta, subcategory]
const luhyaStories = [
  ['Mwambu and Sela — the first Luhya man and woman',
    'In the beginning, Were — the supreme creator — made Mwambu, the first man, and placed him on earth. He gave him Sela for a wife. Mwambu and Sela were the ancestors of the Abaluyia. Were told them: "The land is yours, tend it well. The cattle are yours, care for them. Your children shall fill the earth."\n\nMwambu and Sela had many children, and as the family grew they spread across the western highlands. Each child became the founder of a sub-group — Bukusu, Maragoli, Wanga — each carrying a part of the original instruction from Were. The Luhya say: Omwana ka omukana — a child is the child of everyone.',
    'Oral tradition · documented in Oluhya and English · Western Kenya',
    'origin_myth'],
  ['Maina wa Mutsembi and the Bukusu circumcision rite',
    'The Bukusu circumcision — Imbalu — is performed every even-numbered year and is among the most significant cultural events in western Kenya. Young men are circumcised publicly without anaesthetic as a test of courage and entry into adulthood.\n\nThe ceremony begins with the candidate smearing white clay on their body and dancing through the village before dawn. Elders, family, and community gather to witness. A man who flinches is considered to have shamed his lineage. The scar is permanent — it is the mark of having stood.',
    'Documented by Luhya Cultural Council · Bungoma County',
    'historical_account'],
];

// [title, subtitle, language]
const luhyaMusic = [
  ['Imbalu circumcision chant', 'Pre-dawn ceremony song · Bukusu sub-group', 'Lubukusu'],
  ['Isukuti drum ensemble', 'Traditional celebration drumming · weddings and harvest', 'Oluhya'],
  ['Omwana alilira', 'Lullaby · sung by mothers during harvest season', 'Luragoli'],
];

const luhyaLanguageBody =
  'Oluhya is not a single language but a dialect continuum — a family of related Bantu dialects that are mutually intelligible to varying degrees. Lubukusu (spoken by the Bukusu) and Luragoli (spoken by the Maragoli) are the most divergent.\n\nKey phrases in Oluhya:\n· Oli otyani? — How are you?\n· Ndi mwega — I am fine\n· Amina — Amen / so be it\n· Mwana wange — my child';

const luhyaFoodBody =
  'Luhya cuisine is rooted in the fertile agricultural land of western Kenya. Staple foods include ugali made from maize or sorghum flour, served with isombe (cassava leaves), kunde (cowpeas), mrenda (a mucilaginous vegetable), and ekeberi (cow innards).\n\nThe Luhya are also known for their love of chicken — ingokho — reserved for honoured guests and special occasions.';

// ── seed ──────────────────────────────────────────────────────────────────────
async function main() {
  // Resolve the ONE cultural-enabled org.
  const orgSnap = await db
    .collection('organizations')
    .where('culturalStatus', '==', 'approved')
    .limit(2)
    .get();
  if (orgSnap.empty) {
    console.error('[heritage-seed] ABORT: no org with culturalStatus==approved.');
    process.exit(2);
  }
  if (orgSnap.size > 1) {
    console.error('[heritage-seed] ABORT: multiple orgs with culturalStatus==approved — expected exactly one.');
    process.exit(2);
  }
  const orgDoc = orgSnap.docs[0];
  const orgId = orgDoc.id;
  const repUid = orgDoc.data().org_rep_uid || '';
  console.log(`[heritage-seed] cultural org = ${orgId} (rep ${repUid})`);

  const now = Timestamp.now();
  let nodes = 0, entries = 0, skipped = 0;

  async function upsertNode(id, data) {
    const ref = db.collection('heritage_hierarchy').doc(id);
    const existing = await ref.get();
    const payload = { ...data, seed_key: SEED_KEY };
    const existingBg = existing.exists ? existing.data().bg_image_url : undefined;
    payload.bg_image_url = existingBg !== undefined ? existingBg : null;
    await ref.set(payload, { merge: true });
    nodes++;
  }

  async function seedEntry(docId, e) {
    const ref = db.collection('cultural_entries').doc(docId);
    if ((await ref.get()).exists) { skipped++; return; }
    await ref.set({
      content_type: e.contentType,
      org_id: orgId,
      created_by_uid: repUid,
      created_by: repUid,
      title: e.title,
      description: e.description,
      visibility: 'public',
      tags: [],
      locality: {
        country_id: COUNTRY_ID,
        region_id: null,
        county_id: null,
        community_id: e.communityId ?? null,
        community_name: e.communityName ?? null,
        community_unknown: !e.communityId,
        sub_group_id: e.subGroupId ?? null,
        locality_notes: null,
      },
      type_data: e.typeData || {},
      cover_image_url: null,
      cover_image_media_id: null,
      media_count: 0,
      comment_count: 0,
      relation_count: 0,
      view_count: 0,
      has_active_dispute: false,
      is_seeking_contributors: false,
      is_endangered: false,
      is_contested: false,
      version_count: 1,
      seed_key: SEED_KEY,
      created_at: now,
      updated_at: now,
      last_activity_at: now,
    });
    entries++;
  }

  // Country node
  await upsertNode(COUNTRY_ID, {
    node_type: 'country', name: COUNTRY_NAME, country_id: COUNTRY_ID, is_live: true,
  });

  // Community nodes
  for (const [name, region, counties] of kenyaCommunities) {
    await upsertNode(`community_${COUNTRY_ID}_${slug(name)}`, {
      node_type: 'community', name, country_id: COUNTRY_ID, region, counties,
    });
  }

  // Luhya sub-groups
  const luhyaCommunityId = `community_${COUNTRY_ID}_luhya`;
  for (const [name, locality] of luhyaSubGroups) {
    await upsertNode(`subgroup_luhya_${slug(name)}`, {
      node_type: 'sub_group', name, country_id: COUNTRY_ID,
      parent_community_id: luhyaCommunityId, locality,
    });
  }

  // Foods
  for (const [name, note, cSlug, cName] of kenyaFoods) {
    await seedEntry(`seed_food_${slug(name)}`, {
      contentType: 'food_tradition', title: name, description: note,
      communityId: cSlug ? `community_${COUNTRY_ID}_${cSlug}` : null,
      communityName: cName ?? null,
      typeData: { subcategory: 'staple_dish' },
    });
  }

  // History
  for (const [year, title, body] of kenyaHistory) {
    await seedEntry(`seed_history_${slug(title)}`, {
      contentType: 'place_knowledge', title: `${year} · ${title}`, description: body,
      typeData: { subcategory: 'historical_account', period: year },
    });
  }

  // Luhya stories
  for (const [title, body, meta, subcategory] of luhyaStories) {
    await seedEntry(`seed_story_${slug(title)}`, {
      contentType: 'oral_tradition', title, description: body,
      communityId: luhyaCommunityId, communityName: 'Luhya',
      typeData: { subcategory, body, meta },
    });
  }

  // Luhya music
  for (const [title, subtitle, language] of luhyaMusic) {
    await seedEntry(`seed_music_${slug(title)}`, {
      contentType: 'music_tradition', title, description: subtitle,
      communityId: luhyaCommunityId, communityName: 'Luhya',
      typeData: { subcategory: 'ceremony_song', language },
    });
  }

  // Luhya language + food overviews
  await seedEntry('seed_language_luhya_oluhya', {
    contentType: 'language_entry', title: 'Oluhya — dialect continuum',
    description: luhyaLanguageBody, communityId: luhyaCommunityId,
    communityName: 'Luhya', typeData: { subcategory: 'language_overview' },
  });
  await seedEntry('seed_food_luhya_traditions', {
    contentType: 'food_tradition', title: 'Luhya food traditions',
    description: luhyaFoodBody, communityId: luhyaCommunityId,
    communityName: 'Luhya', typeData: { subcategory: 'staple_dish' },
  });

  console.log(`[heritage-seed] done — org=${orgId} nodes=${nodes} entries=${entries} skipped=${skipped}`);
  process.exit(0);
}

main().catch((e) => {
  console.error('[heritage-seed] ERROR:', e);
  process.exit(1);
});
