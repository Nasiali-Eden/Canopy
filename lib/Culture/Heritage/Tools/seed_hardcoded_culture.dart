// lib/Culture/Heritage/Tools/seed_hardcoded_culture.dart
//
// Phase 1.4 — DEV-ONLY, idempotent seed/migration.
//
// Converts the content that USED to be hardcoded in
// `lib/Community/Heritage/community_heritage_tab.dart` into real Firestore
// records owned by the single cultural-enabled organisation, so the new
// data-driven Heritage screens render genuine backend data instead of demo
// widgets.
//
// Guarantees:
//   • Idempotent — deterministic doc ids + a `seed_key` marker; re-runs skip
//     anything already present (and never clobber an org's uploaded image).
//   • Invents NO images — every seeded entry/node gets image fields = null
//     (the old data was emoji-only; emoji are removed). These surface as
//     "missing" in the org upload checklist (Phase 5.3).
//   • Owns everything by the resolved cultural org
//     (`org_id`, `created_by_uid` = org rep), `visibility = 'public'`.
//
// Run it ONLY in debug, e.g. from a hidden debug button:
//     if (kDebugMode) await runHeritageSeed();
// It aborts loudly if the cultural org can't be resolved uniquely.
//
// ⚠ Does NOT touch Firebase security rules or composite indexes.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

const String _kSeedKey = 'seed_hardcoded_culture_v1';
const String _kCountryId = 'country_kenya';
const String _kCountryName = 'Kenya';

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9]+"), '_')
    .replaceAll(RegExp(r"^_+|_+$"), '');

/// Resolves the cultural org, then seeds nodes + entries. Returns a short
/// summary string (also logged).
Future<String> runHeritageSeed({FirebaseFirestore? firestore}) async {
  final db = firestore ?? FirebaseFirestore.instance;

  // 1) Resolve the ONE cultural-enabled org.
  final orgSnap = await db
      .collection('organizations')
      .where('culturalStatus', isEqualTo: 'approved')
      .limit(2)
      .get();
  if (orgSnap.docs.isEmpty) {
    const msg = '[heritage-seed] ABORT: no org with culturalStatus==approved.';
    debugPrint(msg);
    return msg;
  }
  if (orgSnap.docs.length > 1) {
    const msg =
        '[heritage-seed] ABORT: multiple orgs with culturalStatus==approved — expected exactly one.';
    debugPrint(msg);
    return msg;
  }
  final orgDoc = orgSnap.docs.first;
  final orgId = orgDoc.id;
  final repUid = (orgDoc.data()['org_rep_uid'] as String?) ?? '';
  debugPrint('[heritage-seed] cultural org = $orgId (rep $repUid)');

  final now = Timestamp.now();
  int nodes = 0, entries = 0, skipped = 0;

  // Helper: merge a hierarchy node without clobbering an org-set bg image.
  Future<void> upsertNode(String id, Map<String, dynamic> data) async {
    final ref = db.collection('heritage_hierarchy').doc(id);
    final existing = await ref.get();
    final payload = <String, dynamic>{...data, 'seed_key': _kSeedKey};
    // Only seed a null bg if there isn't one already.
    if (!(existing.exists && existing.data()?['bg_image_url'] != null)) {
      payload['bg_image_url'] = existing.data()?['bg_image_url'];
    }
    payload.putIfAbsent('bg_image_url', () => null);
    await ref.set(payload, SetOptions(merge: true));
    nodes++;
  }

  // Helper: create an entry only if it doesn't already exist (idempotent).
  Future<void> seedEntry(
    String docId, {
    required String contentType,
    required String title,
    required String description,
    String? communityId,
    String? communityName,
    String? subGroupId,
    Map<String, dynamic> typeData = const {},
  }) async {
    final ref = db.collection('cultural_entries').doc(docId);
    if ((await ref.get()).exists) {
      skipped++;
      return;
    }
    await ref.set({
      'content_type': contentType,
      'org_id': orgId,
      'created_by_uid': repUid,
      'created_by': repUid,
      'title': title,
      'description': description,
      'visibility': 'public',
      'tags': const <String>[],
      'locality': {
        'country_id': _kCountryId,
        'region_id': null,
        'county_id': null,
        'community_id': communityId,
        'community_name': communityName,
        'community_unknown': communityId == null,
        'sub_group_id': subGroupId,
        'locality_notes': null,
      },
      'type_data': typeData,
      'cover_image_url': null,
      'cover_image_media_id': null,
      'media_count': 0,
      'comment_count': 0,
      'relation_count': 0,
      'view_count': 0,
      'has_active_dispute': false,
      'is_seeking_contributors': false,
      'is_endangered': false,
      'is_contested': false,
      'version_count': 1,
      'seed_key': _kSeedKey,
      'created_at': now,
      'updated_at': now,
      'last_activity_at': now,
    });
    entries++;
  }

  // 2) Country node (preserve any org-uploaded bg).
  await upsertNode(_kCountryId, {
    'node_type': 'country',
    'name': _kCountryName,
    'country_id': _kCountryId,
    'is_live': true,
  });

  // 3) Community nodes — the 14 documented Kenyan communities (real data:
  //    name + region + counties; no invented content/images).
  for (final c in _kenyaCommunities) {
    final id = 'community_${_kCountryId}_${_slug(c.name)}';
    await upsertNode(id, {
      'node_type': 'community',
      'name': c.name,
      'country_id': _kCountryId,
      'region': c.region,
      'counties': c.counties,
    });
  }

  // 4) Luhya sub-group nodes (18).
  const luhyaCommunityId = 'community_${_kCountryId}_luhya';
  for (final sg in _luhyaSubGroups) {
    final id = 'subgroup_luhya_${_slug(sg.$1)}';
    await upsertNode(id, {
      'node_type': 'sub_group',
      'name': sg.$1,
      'country_id': _kCountryId,
      'parent_community_id': luhyaCommunityId,
      'locality': sg.$2,
    });
  }

  // 5) Kenya food traditions (country-level; community attributed where known).
  for (final f in _kenyaFoods) {
    await seedEntry(
      'seed_food_${_slug(f.name)}',
      contentType: 'food_tradition',
      title: f.name,
      description: f.note,
      communityId: f.communitySlug == null
          ? null
          : 'community_${_kCountryId}_${f.communitySlug}',
      communityName: f.communityName,
      typeData: {'subcategory': 'staple_dish'},
    );
  }

  // 6) Kenya history → place_knowledge entries (real historical accounts).
  for (final e in _kenyaHistory) {
    await seedEntry(
      'seed_history_${_slug(e.title)}',
      contentType: 'place_knowledge',
      title: '${e.year} · ${e.title}',
      description: e.body,
      typeData: {'subcategory': 'historical_account', 'period': e.year},
    );
  }

  // 7) Luhya rich content → real entries under the Luhya community.
  for (final s in _luhyaStories) {
    await seedEntry(
      'seed_story_${_slug(s.title)}',
      contentType: 'oral_tradition',
      title: s.title,
      description: s.body,
      communityId: luhyaCommunityId,
      communityName: 'Luhya',
      typeData: {
        'subcategory': s.subcategory,
        'body': s.body,
        'meta': s.meta,
      },
    );
  }
  for (final m in _luhyaMusic) {
    await seedEntry(
      'seed_music_${_slug(m.$1)}',
      contentType: 'music_tradition',
      title: m.$1,
      description: m.$2,
      communityId: luhyaCommunityId,
      communityName: 'Luhya',
      typeData: {'subcategory': 'ceremony_song', 'language': m.$3},
    );
  }
  await seedEntry(
    'seed_language_luhya_oluhya',
    contentType: 'language_entry',
    title: 'Oluhya — dialect continuum',
    description: _luhyaLanguageBody,
    communityId: luhyaCommunityId,
    communityName: 'Luhya',
    typeData: {'subcategory': 'language_overview'},
  );
  await seedEntry(
    'seed_food_luhya_traditions',
    contentType: 'food_tradition',
    title: 'Luhya food traditions',
    description: _luhyaFoodBody,
    communityId: luhyaCommunityId,
    communityName: 'Luhya',
    typeData: {'subcategory': 'staple_dish'},
  );

  final summary =
      '[heritage-seed] done — org=$orgId nodes=$nodes entries=$entries skipped=$skipped';
  debugPrint(summary);
  return summary;
}

// ─────────────────────────────────────────────────────────────────────────────
// HARDCODED CONTENT (transcribed verbatim from the old community_heritage_tab)
// ─────────────────────────────────────────────────────────────────────────────

class _Community {
  final String name;
  final String region;
  final List<String> counties;
  const _Community(this.name, this.region, this.counties);
}

const _kenyaCommunities = <_Community>[
  _Community('Luhya', 'Western Kenya',
      ['Kakamega', 'Bungoma', 'Vihiga', 'Trans Nzoia']),
  _Community('Luo', 'Western Kenya', ['Kisumu', 'Siaya', 'Homa Bay', 'Migori']),
  _Community('Kipsigis', 'Western Kenya', ['Kericho', 'Bomet']),
  _Community('Kikuyu', 'Central Kenya',
      ['Kiambu', 'Muranga', 'Nyeri', 'Kirinyaga']),
  _Community('Meru', 'Central Kenya', ['Meru', 'Tharaka-Nithi']),
  _Community('Embu', 'Central Kenya', ['Embu']),
  _Community('Kamba', 'Eastern & Coast', ['Machakos', 'Kitui', 'Makueni']),
  _Community('Mijikenda', 'Eastern & Coast',
      ['Mombasa', 'Kilifi', 'Kwale', 'Lamu']),
  _Community('Swahili', 'Eastern & Coast', ['Mombasa Old Town', 'Lamu']),
  _Community('Maasai', 'Rift Valley', ['Kajiado', 'Narok']),
  _Community('Kalenjin', 'Rift Valley',
      ['Uasin Gishu', 'Elgeyo', 'Nandi', 'Baringo']),
  _Community('Turkana', 'Rift Valley', ['Turkana']),
  _Community('Somali', 'North-Eastern', ['Garissa', 'Wajir', 'Mandera']),
  _Community('Borana', 'North-Eastern', ['Marsabit', 'Isiolo']),
];

// (sub-group name, locality)
const _luhyaSubGroups = <(String, String)>[
  ('Bukusu', 'Bungoma County'), ('Maragoli', 'Vihiga County'),
  ('Banyore', 'Vihiga County'), ('Batsotso', 'Kakamega'),
  ('Idakho', 'Kakamega'), ('Isukha', 'Kakamega'),
  ('Kabras', 'Kakamega'), ('Tiriki', 'Vihiga'),
  ('Wanga', 'Mumias, Kakamega'), ('Marachi', 'Busia County'),
  ('Samia', 'Busia County'), ('Kisa', 'Kakamega'),
  ('Marama', 'Kakamega'), ('Tachoni', 'Bungoma'),
  ('Nyala', 'Kakamega'), ('Banyala', 'Kakamega'),
  ('Khayo', 'Busia'), ('Nyore', 'Vihiga'),
];

class _Food {
  final String name;
  final String note;
  final String? communitySlug;
  final String? communityName;
  const _Food(this.name, this.note, [this.communitySlug, this.communityName]);
}

const _kenyaFoods = <_Food>[
  _Food('Ugali', 'National staple · all regions'),
  _Food('Nyama choma', 'Grilled meat tradition'),
  _Food('Mukimo', 'Kikuyu · Central highlands', 'kikuyu', 'Kikuyu'),
  _Food('Pilau', 'Swahili · Coastal tradition', 'swahili', 'Swahili'),
  _Food('Isombe', 'Luhya · Western Kenya', 'luhya', 'Luhya'),
  _Food('Githeri', 'Kikuyu · maize + beans', 'kikuyu', 'Kikuyu'),
  _Food('Ugali wa wimbi', 'Finger millet ugali'),
  _Food('Nyoyo', 'Maize + beans mix'),
];

class _HistoryEvent {
  final String year;
  final String title;
  final String body;
  const _HistoryEvent(this.year, this.title, this.body);
}

const _kenyaHistory = <_HistoryEvent>[
  _HistoryEvent('~3000 BC', 'Cushitic peoples arrive',
      'Early Cushitic communities settle in the northern and eastern regions, bringing pastoralism and trade routes through the Horn of Africa.'),
  _HistoryEvent('~1000 AD', 'Swahili coast trade networks',
      'Arab, Persian, and Indian traders establish coastal settlements. The Swahili culture emerges — a blend of Bantu and Islamic traditions that still defines Mombasa and Lamu.'),
  _HistoryEvent('1400s', 'Bantu migration south',
      'Bantu-speaking communities including the Kikuyu, Luhya, Luo, and Kamba settle across the highlands and lake basin, establishing clan systems still intact today.'),
  _HistoryEvent('1895', 'British East Africa Protectorate',
      'Colonial boundaries drawn with no regard for ethnic territories — communities divided, languages suppressed, land alienated in the highlands.'),
  _HistoryEvent('1952', 'Mau Mau uprising',
      "Predominantly Kikuyu-led resistance against colonial land theft. Declared a state of emergency. A defining moment in Kenya's path to independence."),
  _HistoryEvent('1963', 'Independence — Uhuru',
      'Kenya gains independence on December 12th. Jomo Kenyatta becomes the first Prime Minister. 45 ethnic communities now share one nation-state.'),
];

class _Story {
  final String title;
  final String body;
  final String meta;
  final String subcategory;
  const _Story(this.title, this.body, this.meta, this.subcategory);
}

const _luhyaStories = <_Story>[
  _Story(
    'Mwambu and Sela — the first Luhya man and woman',
    'In the beginning, Were — the supreme creator — made Mwambu, the first man, and placed him on earth. He gave him Sela for a wife. Mwambu and Sela were the ancestors of the Abaluyia. Were told them: "The land is yours, tend it well. The cattle are yours, care for them. Your children shall fill the earth."\n\nMwambu and Sela had many children, and as the family grew they spread across the western highlands. Each child became the founder of a sub-group — Bukusu, Maragoli, Wanga — each carrying a part of the original instruction from Were. The Luhya say: Omwana ka omukana — a child is the child of everyone.',
    'Oral tradition · documented in Oluhya and English · Western Kenya',
    'origin_myth',
  ),
  _Story(
    'Maina wa Mutsembi and the Bukusu circumcision rite',
    'The Bukusu circumcision — Imbalu — is performed every even-numbered year and is among the most significant cultural events in western Kenya. Young men are circumcised publicly without anaesthetic as a test of courage and entry into adulthood.\n\nThe ceremony begins with the candidate smearing white clay on their body and dancing through the village before dawn. Elders, family, and community gather to witness. A man who flinches is considered to have shamed his lineage. The scar is permanent — it is the mark of having stood.',
    'Documented by Luhya Cultural Council · Bungoma County',
    'historical_account',
  ),
];

// (title, subtitle, language)
const _luhyaMusic = <(String, String, String)>[
  ('Imbalu circumcision chant', 'Pre-dawn ceremony song · Bukusu sub-group',
      'Lubukusu'),
  ('Isukuti drum ensemble',
      'Traditional celebration drumming · weddings and harvest', 'Oluhya'),
  ('Omwana alilira', 'Lullaby · sung by mothers during harvest season',
      'Luragoli'),
];

const _luhyaLanguageBody =
    'Oluhya is not a single language but a dialect continuum — a family of related Bantu dialects that are mutually intelligible to varying degrees. Lubukusu (spoken by the Bukusu) and Luragoli (spoken by the Maragoli) are the most divergent.\n\nKey phrases in Oluhya:\n· Oli otyani? — How are you?\n· Ndi mwega — I am fine\n· Amina — Amen / so be it\n· Mwana wange — my child';

const _luhyaFoodBody =
    'Luhya cuisine is rooted in the fertile agricultural land of western Kenya. Staple foods include ugali made from maize or sorghum flour, served with isombe (cassava leaves), kunde (cowpeas), mrenda (a mucilaginous vegetable), and ekeberi (cow innards).\n\nThe Luhya are also known for their love of chicken — ingokho — reserved for honoured guests and special occasions.';
