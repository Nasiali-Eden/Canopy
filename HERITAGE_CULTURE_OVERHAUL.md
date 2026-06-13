# Heritage & Culture Overhaul — Cowork Workflow

> Long-running, multi-phase task. This document is the source of truth for the
> autonomous run. Each phase is independently shippable and ends with
> `flutter analyze` clean. Do **not** introduce new hardcoded cultural data —
> everything is Firestore-driven. The **only** image that stays static is the
> Heritage home background (`images/BG.png`).
>
> **Core principle — backend ⇄ frontend parity / NO placeholders:** every screen
> renders *exactly* what Firestore holds. There is **no sample/placeholder/fake
> data anywhere** — no fallback lists, no demo orgs, no static featured items, no
> decorative emoji stand-ins. Allowed (these are NOT "placeholders"): (a) loading
> skeletons/shimmers while a stream resolves, (b) genuine **empty-state messaging**
> ("Nothing yet — check back later"), and (c) a neutral **gradient** where an
> image is genuinely absent (no emoji). If the backend has nothing, the screen
> shows the empty state — never invented content.

---

## 0. Context discovered (don't re-derive)

**Canonical upload taxonomy — 12 content types** (from
`lib/Culture/Heritage/Create/type_data_form_builder.dart` `_schemas`):

| key | Display | Notes |
|---|---|---|
| `oral_tradition` | Stories | origin myth, oral history, fable, proverb… |
| `food_tradition` | Food | staple, ceremonial, fermented, street food… |
| `ingredient` | Ingredients | plant, root, grain, animal protein, spice… |
| `music_tradition` | Music | ceremony song, work song, lullaby, drumming… |
| `instrument` | Instruments | drum, string, wind, idiophone… |
| `ceremony` | Ceremonies | rite of passage, wedding, funeral, harvest… |
| `craft_technique` | Crafts | weaving, pottery, metalwork, beadwork… |
| `clothing_tradition` | Dress | everyday, ceremonial, body adornment… |
| `language_entry` | Language | full language, dialect, vocabulary… |
| `place_knowledge` | Places | sacred site, settlement, river, migration… |
| `medicine_knowledge` | Medicine | medicinal plant, healing practice, healer… |
| `person` | Knowledge Holders | elder, artisan, healer, storyteller… |

**Entry model:** `lib/Culture/Heritage/Models/cultural_entry.dart`
Fields: `org_id, title, content_type, subcategory, description, tags,
visibility, locality, image_url, comment_count, connection_count,
has_active_dispute, created_at, updated_at, created_by`.

**Collections in use (⚠ inconsistency to resolve in Phase 1):**
- `community_heritage_tab.dart` reads **`heritage_entries`**
- `cultural_org_profile_page.dart` / archive read **`cultural_entries`**
- Per-node backgrounds: **`heritage_hierarchy/{node_id}`** → `bg_image_url`
- Org docs: **`organizations/{orgId}`** (see org_firestore_fields memory)

**Hardcoded data to remove** (all of `lib/Community/Heritage/community_heritage_tab.dart`):
- `_HeritageHome`: country grid (Kenya…Tanzania), `_FeaturedStoriesRow._staticFeatured`
- `_KenyaScreen`: `_CulturesTab` tribe list (14 hardcoded), `_FoodTab._foods` (8),
  `_HistoryTab._events` (6)
- `_LuhyaScreen`: `_subGroups` (18), all `_StoryCard`/`_ContentBlock`/`_MusicItem` content
- Static image fallbacks `images/kenya.png`, `images/K_FOREST.png` (replace with
  empty/gradient states). **Keep `images/BG.png`.**

**Org storage** (`organizations/{orgId}`, written by
`CommunityAuthService.registerAsOrganization`): no `country` or country-bg field
yet — added in Phase 0.

**Capability flags on the org doc** (string status fields, value `'approved'`):
- `culturalStatus == 'approved'`  → org can use the Cultural Archive (the ONE
  cultural-enabled org for now). This is the migration target in Phase 1.
- `envOpsStatus == 'approved'`, `marketplaceStatus == 'approved'` (same pattern).
Resolve the cultural org with:
`organizations.where('culturalStatus', isEqualTo: 'approved')` (expect 1 doc).

---

## 1. Target architecture

### Navigation model (country → category → item)
```
Heritage Home  (countries from Firestore; BG.png static)
   └─ Country screen  (CATEGORY HUB — no tribe list)
        every present category = a card (distinct shapes per group)
        each card shows a PREVIEW of first N items + "Show all"
           └─ Category Browse screen  (grid/list of all items in that
              category for this country; filters: community, subcategory)
                └─ Item screen  (full record: story body, food info,
                   ingredient detail, etc. — rendered from content_type schema)
```
- "Show all" + Item pattern applies **from the country screen forward**.
- A screen with no data shows an elegant **empty state** — never hardcoded filler.

### Data layer (new): `lib/Culture/Heritage/Services/heritage_data_service.dart`
Streams off the canonical entries collection (Phase 1 decision), filtered by
`country`, `content_type`, `locality/community`, `visibility == public`.
Methods (sketch):
- `streamCountries()` → from `heritage_hierarchy` (type=country) or `assets/cultural/countries/_index.json` seeded into Firestore
- `streamCategoriesForCountry(country)` → distinct `content_type` present + counts
- `streamItems(country, contentType, {community, subcategory, limit})`
- `streamItem(id)`
- `streamFeatured()` (replaces `_staticFeatured`)
- `bgImageFor(nodeId)` (existing `heritage_hierarchy/{id}.bg_image_url` pattern)

---

## 2. Phases

### Phase 0 — Foundations (design system + data fields)
0.1 **Glass design system**: `lib/Shared/theme/glass.dart` — reusable
   `GlassCard`, `GlassPanel`, gradient/pattern backgrounds, accent palette.
   (Reuse the `view_commons.dart` GlassCard approach already in the repo.)
0.2 **Glassy bottom nav everywhere**: make `FloatingNavBar`
   (`lib/Shared/widgets/floating_nav_bar.dart`) the single nav on Home,
   Heritage, and Culture — add a frosted `BackdropFilter` variant. Heritage &
   Culture currently swap shells; ensure the glass bar persists.
0.3 **Org schema additions**: add `country` (String) and
   `country_bg_image_url` (String?) to `organizations`. Extend the org edit
   screen (`lib/Organization/Home/Dashboard/edit_org_details_screen.dart`) with
   a Country picker + country background uploader (only shown if missing).
0.4 **User→Org linkage**: ensure the current user maps to an org by uid (see
   open decision Q3). Cultural uploads attribute `org_id` + `created_by`.

### Phase 1 — Data layer + collection unification + SEED MIGRATION
1.1 Pick ONE entries collection and migrate reads/writes:
   `community_heritage_tab`, archive, profile, create flow all agree.
1.2 Build `HeritageDataService` (above). All reads `visibility == public`
   for the community-facing Heritage tab.
1.3 Seed countries into `heritage_hierarchy` (or read the existing
   `assets/cultural/countries/_index.json`) so the home country grid is data-driven.
1.4 **Seed/migration script** — `lib/Culture/Heritage/Tools/seed_hardcoded_culture.dart`
   (a dev-only one-shot, runnable from a hidden debug button or a `main()` guarded
   by `kDebugMode`). It:
   - Finds the cultural-enabled org:
     `organizations.where('culturalStatus','==','approved').limit(1)` → `orgId`.
     Abort with a clear log if zero/multiple found.
   - Writes the currently-hardcoded content as real entries owned by that org
     (`org_id = orgId`, `created_by = org rep uid`, `visibility = 'public'`):
       · Kenya tribes/communities (`_CulturesTab` list) → Communities nodes
         + a community entry each (locality set).
       · Kenya foods (`_FoodTab._foods`) → `food_tradition` entries (country=Kenya).
       · Kenya history (`_HistoryTab._events`) → `place_knowledge`/`oral_tradition`
         (or a `history_event` subcategory) entries.
       · Luhya page (`_LuhyaScreen`): sub-groups → community nodes; the two
         `_StoryCard`s → `oral_tradition`; music items → `music_tradition`;
         food block → `food_tradition`; language block → `language_entry`.
   - Is **idempotent** (use deterministic doc ids or a `seed_key` field; skip if
     already present) so re-runs don't duplicate.
   - **Does NOT invent images** — the hardcoded data only had emoji (being
     removed). Entries/countries get `image_url = null` / `bg_image_url = null`;
     these surface as "missing" in the org upload checklist (Phase 5.3).
   - Logs a summary (counts per type) and the resolved `orgId`.

### Phase 2 — Country screen redesign (category hub)
2.1 Replace `_KenyaScreen`'s 3 hardcoded tabs with a **generic CountryScreen**
   driven by `streamCategoriesForCountry`. No tribe list, no tabs.
2.2 **Layout:** the country background image is the full-screen backdrop and the
   page **scrolls over it** to reveal all category cards (single vertical
   scroll, parallax/fixed bg with a darkening scrim for legibility — glassy
   cards float on top). Bg from `heritage_hierarchy/country_{id}.bg_image_url`
   (org-set); if absent, an elegant gradient + emblem placeholder (no kenya.png).
2.3 **Categories appear in a fixed, consistent order** with **distinct card
   shapes** per group, e.g.:
       1 Communities (wide banner)   2 Stories (tall poster)
       3 Food · 4 Ingredients (square tiles)   5 Music · 6 Instruments (tiles)
       7 Ceremonies (wide banner)   8 Crafts · 9 Dress (tiles)
       10 Language (compact row)    11 Places (wide banner)
       12 Medicine · 13 Knowledge Holders (tiles)
   Define the order + shape map once (single source) so it's consistent across
   countries. Cards are **glassy** (frosted `BackdropFilter`).
2.4 Each category card = preview of first 3–6 items + "Show all" → Browse.
   A category with no entries is hidden (per Q1).
2.5 **If the whole country has nothing to show**, render a glassy "Check back
   later" placeholder over the background instead of an empty page.

### Phase 3 — Generic Category Browse + Item screens
3.1 `CategoryBrowseScreen(country, contentType)` — data-driven grid/list,
   filters (community, subcategory), search, empty state.
3.2 `HeritageItemScreen(entryId)` — renders the full record using the
   `content_type` field schema (story body, food prep, ingredient uses, etc.).
   Image-rich, glassy. Comments/connections if present.
3.3 These replace `_LuhyaScreen`'s hardcoded blocks entirely.

### Phase 4 — Heritage home dynamic
4.1 Country grid from data; "Live" vs "Soon" derived from whether any public
   entries exist for that country.
4.2 Featured row from `streamFeatured()` (no `_staticFeatured`).
4.3 Search delegate wired to real entry search.

### Phase 5 — Culture upload pages redesign (elegant/glassy)
5.1 Restyle `create_entry_screen.dart`, `type_data_form_builder.dart`,
   `media_upload_item.dart`, `locality_selector_sheet.dart` with the Phase 0
   glass system: patterns, colour, sectioned steps, better media role UI.
5.2 Verify EVERY one of the 12 content types is creatable and that uploaded
   images flow to the right roles (cover, backgrounds, food image, etc.).
5.3 **Per-country "missing features" checklist** on the org upload/manage pages.
   For each country the org operates in, compute and display what's still
   missing so they know what to upload, e.g.:
       · Country background image (`heritage_hierarchy/country_{id}.bg_image_url`
         == null) — flagged because the old data was emoji-only, now removed.
       · Categories with zero entries (of the 12) → "No Food entries yet", etc.
       · Communities with no detail/entries.
   Render as a glassy completeness card with tappable rows that deep-link to the
   relevant upload flow (pre-selecting country + content_type). Drives orgs to
   fill the gaps the seed migration left blank.

### Phase 6 — Marketplace entry relocation
6.1 Remove the Marketplace icon from the community home app bar
   (`community_home.dart` `_buildHomeAppBar` actions).
6.2 Add a full-width "Marketplace" action under **Quick Actions** on the Home
   tab, redesigned to span the row width (distinct from the 2-up cards).

### Phase 7 — Notifications screen
7.1 Create `lib/Community/Communication/notification_center.dart` target (or
   reuse if present) as a proper screen with an **empty state ("display none"
   content for now)**. Wire the bell to it.

### Phase 8 — Remove ALL placeholders + backend⇄frontend parity + QA
8.1 Delete every placeholder/sample/fake data source so the UI mirrors Firestore
   exactly. Known sources to remove/neutralise:
   - `lib/Community/Heritage/community_heritage_tab.dart`: `_staticFeatured`,
     hardcoded country grid, `_CulturesTab` tribe list, `_FoodTab._foods`,
     `_HistoryTab._events`, all `_LuhyaScreen` content, emoji stand-ins.
   - `lib/Community/Map/map_placeholders.dart` (`kPlaceholderOrgs`,
     `kPlaceholderAmenities`) and the `_allOrgs/_allAmenities` fallbacks in
     `map.dart` — the map shows only real Firestore orgs/pins (empty otherwise).
   - `community_home.dart` fake article/announcement content (keep shimmer +
     empty states only).
   - Any other `_static*`, `kPlaceholder*`, or hardcoded demo lists found via
     grep (`kPlaceholder`, `_static`, `_demo`, hardcoded `const _… = [`).
8.2 Replace each removed fallback with: shimmer while loading → real data, or an
   empty-state ("check back later") when the stream is empty. Missing images →
   gradient only.
8.3 Full `flutter analyze` (0 errors); manual pass confirming every screen shows
   real backend data or a proper empty state — no invented content anywhere.

---

## 3. Permissions / authorizations the cowork run needs

Pre-approve so the long run isn't blocked:
- **Bash/PowerShell:** `flutter analyze`, `flutter pub get`, `dart fix`,
  `flutter build` (no emulator runs unless asked), `git add/commit/branch`
  (commit per phase; never push without ask).
- **File tools:** create/edit across `lib/`, `assets/cultural/`, and
  `lib/Shared/`. New files under `lib/Culture/`, `lib/Community/Heritage/`,
  `lib/Shared/theme|widgets`.
- **Firestore (app-side only):** code reads/writes to `cultural_entries`/
  `heritage_entries`, `heritage_hierarchy`, `organizations`, `notifications`.
  ⚠ The run will NOT touch Firebase console/security rules — flag any rule or
  composite-index changes for you to apply.
- **No external services** beyond what the app already uses (Firebase Storage
  for uploads). Surface any new `pubspec.yaml` dependency before adding.

## 4. Decisions (LOCKED)

- **Q1 — Country screen cards:** show **all 12 content types**, each as its own
  card. A category card appears only when that country has ≥1 public entry of
  that type. A country with no entries at all shows a country-level empty state
  (Q4 style). Use distinct card shapes per group (poster / tile / banner).
- **Q2 — Communities:** add a dedicated **"Communities" card** on the country
  screen (so 12 category cards + 1 Communities card). It browses communities
  (Luhya, Luo, Maasai…); a community screen lists that community's entries by
  `locality`. Communities are NOT a per-category filter destination by default.
- **Q3 — Uploads are ORG-ONLY (for now):** only registered organisations (org
  reps, resolved via `Users.orgId` → `organizations/{orgId}`) can create/upload
  cultural content. Regular community users are **read-only** — no auto-created
  or personal orgs. `org_id` + `created_by` set from the org rep.
- **Q4 — Empty states (revised by "remove all placeholders"):** no hardcoded
  data. Missing images fall back to a neutral **gradient only** (the decorative
  **emoji is removed** per the latest instruction). Sections/screens with no
  items show a tasteful **"nothing yet / check back later"** message. Only
  `images/BG.png` stays static. Loading shimmers are fine.

### Adjustments from decisions
- Phase 0.4 simplifies: no user→org auto-link work; just ensure the create flow
  reads the org rep's `orgId` and gates upload UI to org reps only.
- Phase 2 country screen = 12 category cards (entry-gated) + Communities card.
- Phase 3 adds a **CommunityScreen** (lists a community's entries) alongside the
  generic CategoryBrowse + Item screens.
