# Canopy — deployment brief

For the Cowork session taking this to release. Read this first. It says what exists, what is already live, and what still blocks a store release. Anything marked **unverified** was not tested on a device or in the store consoles.

## 1. What this is

A Flutter app (`impact_trail`, v1.0.0+1, Dart ^3.6.1, Flutter 3.35.5) with a Firebase backend.

- Android applicationId / iOS bundle id: `com.impactledger.app`
- Firebase project: `citywatch-3ac52` (display name "impact-trail"; `.firebaserc` alias `impact-ledger`)
- Surfaces: member app (Home feed, Activities, Map, Heritage, Profile), organisation workspace, Environmental Ops, Cultural Archive, Marketplace, Home Services.
- Payments are **outside the app**. All M-Pesa/Daraja code and secrets were removed. Listings and service bookings exchange phone numbers; people settle directly.

## 2. Already live on `citywatch-3ac52`

- **Firestore rules** (`firestore.rules`) and **Storage rules** (`storage.rules`), deployed 2026-10-25.
- **Functions, codebase `default`** (`functions/`): `pingTrustedApi`, `confirmContribution`, `checkInToEvent`.
- **Functions, codebase `access`** (`functions-access/`): `inviteOrgRep`, `acceptOrgInvite`, `removeOrgAccess`, `switchActiveOrg`. Separate codebase so it needs no secrets.
- Container-image cleanup policy set (1 day) on `us-central1`.
- Test data cleared: `activities`, `Events`, `contributions` (Firestore). Their **Storage images were not deleted**.
- Google sign-in works with the **debug** key only.

## 3. Blocks a release (do these first)

1. **Release signing.** `android/app/build.gradle` signs release builds with the *debug* key (`signingConfig = signingConfigs.debug`). Create an upload keystore, wire `key.properties`, and keep the keystore out of git.
2. **Google sign-in on the release key.** Register the release **SHA-1 and SHA-256** (and Play App Signing's SHA if used) in Firebase → Project settings → Android app, then replace `android/app/google-services.json`. Only the debug SHA is registered today.
3. **`lib/firebase_options.dart` is git-ignored.** A fresh clone will not compile. Regenerate with `flutterfire configure --project citywatch-3ac52`, or decide to commit it.
4. **iOS is not configured.** No `ios/Runner/GoogleService-Info.plist`; `firebase.json` has empty iOS app ids. Needs an iOS app in Firebase, the plist, signing/provisioning, and a build. Unverified whether it builds.
5. **Play Store permission risk.** `AndroidManifest.xml` requests `MANAGE_EXTERNAL_STORAGE`, `READ/WRITE_EXTERNAL_STORAGE`. Play restricts all-files access; the app only picks photos, so remove them and rely on the photo picker / `READ_MEDIA_IMAGES`.
6. **Maps API key.** Present in the manifest. Restrict it in Google Cloud (Android package + release SHA-1, Maps SDK only) so it cannot be reused.
7. **Cloud Functions runtime.** Node.js 20 is **decommissioned on 2026-10-30**; deploys fail after that. Move both codebases to a supported Node version and upgrade `firebase-functions` (^5 is flagged outdated). Re-test after.
8. **Verifier flag.** `confirmContribution` only accepts users with a `verifier: true` custom claim. **Nobody has it**, so no contribution can be verified and no points are awarded. Set it for the verifying accounts with the Admin SDK (needs a service-account credential). This is the main functional blocker.

## 4. Should fix before launch

- **Firestore indexes.** `firestore.indexes.json` has no composite indexes for `contributions`. Several queries combine `where` + `orderBy('createdAt')` in `lib/Services/Contributions/contribution_service.dart` and will fail with "requires an index". The community Impact page was fixed by sorting in the app; these were not.
- **`org_rep` rule is too open.** `allow write: ... (isSignedIn() && resource == null)` lets any signed-in user create an `org_rep` record, which routes to the organisation workspace. Tighten to server writes only.
- **App Check** is not installed (logs show "No AppCheckProvider installed"). Enable Play Integrity and enforce on Firestore/Storage/Functions.
- **Verified-badge and workspace approvals** (`verified`, `envOpsStatus`, `marketplaceStatus`, `culturalStatus`) are set by hand in the console. Decide who does that and how.
- **Map pins** save as `is_verified: false`; no confirmation flow exists.
- **Orphaned data.** Contribution photos and activity/event images remain in Storage under `contributions/`, `activities/`, `events/`. Delete in the console.
- **Heritage entries need map pins.** Every entry must have a `map_point`; the 21 existing entries do not, so the culture map is empty. Pin them in the app (Archive → entry → Location).
- **Dependencies.** About 130 packages have newer incompatible versions; run `flutter pub outdated` and plan an upgrade.
- **Store assets.** Privacy policy URL (the app collects location, photos and phone numbers), data-safety form, screenshots, listing text, support contact.

## 5. Build and verify

```
flutter pub get
flutterfire configure --project citywatch-3ac52     # creates lib/firebase_options.dart
flutter analyze                                      # a few path-case errors on Windows are false alarms
flutter test
flutter build appbundle --release                    # after signing is set up
firebase deploy --only firestore:rules,firestore:indexes,storage --project citywatch-3ac52
firebase deploy --only functions --project citywatch-3ac52
```

On Windows Git Bash, prefix Firebase commands that take a leading-slash path with `MSYS_NO_PATHCONV=1`, or the path is rewritten and nothing is deleted.

Smoke test on a release build, signed in as an organisation and as a member: Google and email sign-in, post an event with a pin, log a contribution, verify it (needs item 8), send an organisation invite and accept it from a second account, switch organisation, map a field pin with a photo, post a market listing with a phone number, open the culture map.

## 6. What is in this branch

Only what builds and deploys the app: `lib/`, `assets/`, `images/`, `fonts/`, `pngs/`, `android/`, `ios/`, `test/`, `functions/`, `functions-access/`, Firebase config and rules, `pubspec.*`. Design briefs, hand-off documents, seed/migration tools, editor and agent folders and `local.properties` are left out; they still exist on `heritage-culture-overhaul`.
