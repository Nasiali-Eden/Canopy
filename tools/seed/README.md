# Heritage seed (CLI)

Seeds the hardcoded Kenya culture data into Firestore from the command line.
Mirrors `lib/Culture/Heritage/Tools/seed_hardcoded_culture.dart` exactly (same
doc ids + data), so it's idempotent and interchangeable with the in-app debug
button. Re-running skips existing entries and never clobbers an org-uploaded
`bg_image_url`.

## 1. Get a service account key
Firebase console → **Project settings → Service accounts → Generate new private
key**. Save the JSON somewhere outside the repo. **Never commit it.**

## 2. Install + run
```bash
cd tools/seed
npm install
```
Then run with the key, easiest first:
```bash
# A) drop the key here as serviceAccount.json (gitignored) and just run:
node seed_heritage.js

# B) or point at it explicitly:
node seed_heritage.js --key /absolute/path/to/serviceAccount.json

# C) or via env:
#   export GOOGLE_APPLICATION_CREDENTIALS=/abs/path.json   (PowerShell: $env:GOOGLE_APPLICATION_CREDENTIALS="...")
#   node seed_heritage.js
```
The script auto-detects `tools/seed/serviceAccount.json` if present.

## What it does
- Resolves the ONE org with `culturalStatus == 'approved'` (aborts if 0 or >1).
- Writes `heritage_hierarchy` nodes (country, 14 communities, 18 Luhya
  sub-groups) and `cultural_entries` (foods, history, Luhya stories/music/
  language/food) owned by that org, `visibility: 'public'`.
- Invents NO images — image fields are null (surface in the org's "missing
  features" checklist).

## Notes
- Writing runs with **admin privileges** (service account), so Firestore
  security rules don't block it.
- **Viewing** the seeded data in-app needs the composite indexes on
  `cultural_entries` (Firestore prints the exact creation links on first query).
- Output ends with e.g. `done — org=… nodes=20 entries=14 skipped=0`.
```
```
