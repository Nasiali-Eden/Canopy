# Canopy — how the app works, for the privacy policy and terms

For the Cowork session writing the **privacy policy** and **terms and conditions** for the Canopy app and website. This describes what the app does *today*, taken from the code and the Firebase rules, not what is planned. Things I could not confirm are marked **unverified** or listed as **decisions needed** in section 12. Do not invent practices the app does not have.

The website is **canopycircle.org**. It is not part of this repository, so what it collects is unknown; ask before assuming. The app links to `canopycircle.org/privacy`, `/terms` and `/delete-account`; **those three pages must exist**.

## 1. What Canopy is

A mobile app (Android now, iOS not yet released) for community and environmental work in Kenya. People log work they have done (clean-ups, tree planting), organisations run activities and verify that work, members earn points and appear on leaderboards. It also contains a map, a cultural heritage archive, a materials marketplace, a home-services directory, and tools for waste-collection organisations.

- App id / bundle id: `com.impactledger.app`. Backend: Google Firebase project `citywatch-3ac52`.
- The operating legal entity is **not stated anywhere in the code**. Needed for both documents (see section 12).
- **Payments never happen in the app.** There is no payment processor, no card or mobile-money handling, no fees and no escrow. People exchange phone numbers and settle directly.

## 2. Who uses it (roles)

| Role | What they can do |
|---|---|
| **Member** (also "Volunteer") | Log contributions, join activities, see the map and heritage, post comments, use marketplace and services. |
| **Organisation** | Registered by an *organisation representative*. Creates activities and events, verifies contributions, publishes articles, posts announcements, manages people, maps places. |
| **Organisation representatives** | One owner (who registered) plus invited **admins** and **editors**. A person can represent more than one organisation. |
| **Marketplace seller** | Lists products and recycled materials. |
| **Service provider** | Lists home services (e.g. trash collection, plumbing, electrical) and receives booking requests. |
| **Cultural archive organisation** | Records heritage entries (stories, food, music, people, places…) for communities. |
| **Canopy administrators** | Approve organisation workspaces, set verified badges and the "verifier" permission, review licences. Done by hand in the Firebase console. |

Organisations can switch between workspaces (member, organisation, Environmental Ops, Cultural Archive, Marketplace).

## 3. Accounts and sign-in

- Sign-in methods: **email + password**, and **Google sign-in**. Both can be linked to one account.
- Members register with: full name, email, password, optional username, county/city, optional area. Country is fixed to Kenya.
- Organisations register with: representative name, organisation name, email, password, description, main activities, designation (e.g. NGO, CBO), logo, sector and type, who they serve (beneficiary groups), facilities, country/city/area, and approximate coordinates taken from the chosen area.
- Marketplace sellers give: name, phone, shop name, business registration number (optional), logo, bio, location.
- Everyone accepts the **Community Guidelines** (be respectful, log honestly, stay safe, ask before sharing people's faces or private details, honour culture). Acceptance is recorded as a timestamp.
- **Age and terms:** creating an account (member or organisation) now requires a checkbox: "I am 18 or older (or have a parent or guardian's permission) and I agree to the Terms and the Privacy policy". The time of acceptance and the age threshold are saved on the profile. There is still no date-of-birth field, so age is self-declared. The threshold is one constant (`kMinimumAge = 18`, `lib/Config/legal.dart`); **counsel should confirm 18**.
- **Account deletion:** Settings → Account → **Delete account** (confirm, then type DELETE). A server function deletes the sign-in account, profile, username, notifications, contributions, point records, organisation memberships, support messages, service listings, seller profile and the photos under the person's own folders. Heritage comments they made stay but are made anonymous ("Deleted member"). **Owners of an organisation cannot self-delete**: they are told to contact Canopy to transfer or close it first. The same request path should exist on the website (`/delete-account`). (Deployment of the function is pending; see section 14.)
- Organisation invites: an owner or admin enters a person's **email** (or phone) to invite them. The invited person must sign in with a **verified** email that matches, then accepts. The invitee's email/phone is stored by the inviting organisation.

## 4. What data the app collects

| Data | When | Why | Who can see it |
|---|---|---|---|
| Name, username, city/area, role, points, accepted-terms time | Registration, profile | Account, leaderboard, attribution | **Any signed-in user can read user profile records** (these fields). Leaderboards show names and points. |
| **Email and phone number** | Registration; edit profile; first launch after this update | Contact, sign-in | **Private**: stored in `UserPrivate/{uid}`, readable only by that person. Existing accounts are moved there automatically the next time they open the app. Other people only ever see a phone number the person puts on a listing or booking. |
| Password | Email sign-in | Authentication | Held by Firebase Authentication; never readable by Canopy. |
| Google account name, email, photo | Google sign-in | Authentication | Via Firebase Authentication. |
| **Precise location (GPS)** | Logging work; mapping dumpsites/trees/places/boundaries; showing "my location" on the map; pinning events and heritage entries | Verify that work happened where claimed; show things on the map | Stored as exact coordinates with the record. Contributions are visible to signed-in users; map pins, zones, trees and events are visible to **anyone, signed in or not**. |
| **Photos** (camera or gallery) | Contributions, map pins, activities, articles, marketplace and service listings, incident reports, heritage media, organisation logo and cover, profile | Evidence and presentation | Same visibility as the record they belong to. Photos of people are discouraged by the guidelines, not technically blocked. |
| Phone numbers | Marketplace listings, service listings and bookings, seller profile, organisation contact, invitations | So people can contact each other | **Shown to other users on the listing/booking**, and public on public listings. |
| Contribution details (type of work, hours, notes, materials, before/after photos, optional social links) | Logging work | Points and impact | Signed-in users. Organisation reviewers see them to verify. |
| Verification outcomes, points, score records | When an organisation confirms work | Points and ranking | Owner and server; points show on profiles/leaderboards. |
| Comments, questions and disputes | Heritage "Talk to the archive", activities | Discussion with the archive team | Commenter name is stored and shown; disputes are private to the archive team. |
| Heritage entries | Organisations recording knowledge | Preserve and share culture | By visibility: public, community, restricted or sealed. May describe named people (see section 7). |
| Incident / dumping reports | Reporting a problem | Map and organisation response | Signed-in users. |
| Support messages | "Contact support" | Help | Canopy team only. |
| Home-services licence documents (photo) | Providers in regulated trades | Licence check | Only the uploader and administrators. |
| Notifications | App events | Tell people things happened | The recipient only. Stored in the database (in-app); see push note below. |

**Also stored:** timestamps, internal ids, the organisation(s) a person represents, device-local preferences (e.g. language choice) on the phone.

## 5. Device permissions requested

Internet, **camera**, **fine and coarse location**, read photos/media, and legacy storage permissions (`READ/WRITE_EXTERNAL_STORAGE`, `MANAGE_EXTERNAL_STORAGE`). The storage permissions are slated for removal (they are only used for picking photos). Location is only read while the app is in use for the features above; there is no background tracking (**unverified** on a device, but nothing in the code requests background location). The camera is also used to scan QR codes for event check-in.

## 6. Third-party services

| Service | Used for | Notes |
|---|---|---|
| **Firebase Authentication** (Google) | Sign-in | Email/password and Google. |
| **Cloud Firestore** | Almost all app data | Region **unverified** (check the console); Cloud Functions run in `us-central1`. |
| **Firebase Storage** | Photos and media | Some folders are publicly readable. |
| **Cloud Functions** | Points confirmation, event check-in, organisation invites/access | Server-side, trusted code. |
| **Google Maps SDK** | Map display; sends map requests from the device | Google receives map tile and location-area requests. |
| **Google Sign-In** | Optional sign-in | |
| **Firebase Analytics / Cloud Messaging** | **Removed.** The packages were never used and have been taken out, so the app collects no analytics and sends no push notifications. Notifications are in-app only. | |
| **Phone, WhatsApp, social links, Google Maps directions** | Open outside the app when the user taps them | Canopy does not see what happens there. |
| Share sheet | Sharing a post's text | Canopy does not receive the share. |

No advertising, no ad SDKs, no data sales, no payment processor, and no cookies inside the app. **No App Check** is enabled yet, so Firebase does not verify that requests come from the genuine app.

## 7. What is public, what is not

- **Public (no sign-in needed):** organisation profiles (name, logo, description, location, contact details they publish), announcements, articles, activities and events, map pins, collection zones, trees, marketplace sellers and listings, service listings, public heritage entries, usernames.
- **Signed-in users only:** other users' profiles and contribution records (including location and photos), incident reports, heritage entries that are not public, comments.
- **Private:** a person's notifications, their service bookings (visible to the two parties), licence documents, support requests, password.
- **Heritage specifics:** entries have four visibility levels (public, community, restricted, sealed), optional **restriction notes** shown verbatim ("shared with limits"), credits on every photo/recording, and a consent flag for entries about a person (they must agree to be documented and named). Cultural content belongs to its communities; the app does not claim ownership.

## 8. Points, verification and moderation

- Members log work; it starts **pending**. A person from the organisation that ran the activity confirms it using a server function; the server calculates points, records an award, and marks it **verified**. People cannot verify their own work. (Today nobody holds the required "verifier" permission, so no work can be verified yet — operational, not a policy matter.)
- Points feed leaderboards and badges, which are visible to other users.
- Organisations can be marked **verified** by an administrator; this is a manual judgement.
- Map pins are saved as unverified; there is no community confirmation flow yet.
- **Report and block (new):** a flag button on feed posts and the Read-more screen, marketplace listings and heritage entries opens a report sheet (spam, inappropriate, harassment, false, unsafe or illegal, shares private information, other, plus an optional note). Reports are stored privately and only the Canopy team can read them, in the Firebase console. The reporter can also **block** the poster: their posts then stop appearing in the reporter's home feed, and Settings → **Blocked people** undoes it. The person reported is not told. There is **no automatic action**; Canopy staff review reports by hand. **Decide** what response time or outcome the terms promise.

## 9. Retention, deletion, security

- No automatic deletion for most data. Marketplace material listings are set to stop showing after 30 days; recurring standing orders do not expire. Nothing is purged from the database when they lapse.
- Users can delete **their own pending contributions**. Organisations can close listings. **Nothing else is user-deletable.** Published heritage entries are "sealed" rather than deleted by design.
- Administrators can delete data in the Firebase console. Deleting a contribution does not remove points already awarded; photos stay in Storage until removed by hand.
- Security: access is controlled by Firebase security rules and server-side functions; points, organisation membership and verification can only be changed by the server. Data in transit uses TLS. No further encryption claims should be made without checking.
- The privacy policy will need a real **account and data deletion** process: Google Play requires one (in-app path and a web link). It does not exist yet.

## 10. Marketplace and services — what the terms must cover

- Canopy only **connects** people. It is not a party to any sale or service, does not hold money, and takes no commission. Buyers and sellers (and customers and providers) agree price, handover and payment themselves.
- Listings show a phone number and (optionally) an exact location. Listing owners choose to publish these; the policy should say they are visible to other users.
- Sellers list recycled materials, products and services. Regulated trades (electrical, plumbing) are hidden until an administrator has checked a licence; Canopy does not guarantee any provider's work.
- Waste and recycling activity may be regulated in Kenya; users are responsible for their own compliance.

## 11. Content and conduct (for the terms)

- Users own what they post, and give Canopy a licence to show it in the app and to the people it is shared with. Heritage content also carries credit and consent rules above.
- Rules: honest logging, no harassment or discrimination, no posting people's faces, homes or private details without consent, no fake locations (a phone with mock-location is refused when mapping places), respect heritage restrictions.
- Organisations are responsible for the people they invite and for the accuracy of what they verify.

## 12. Decisions needed before writing (please ask the owner)

1. **Legal entity name, address, contact email, and governing law/jurisdiction.** (The website is canopycircle.org; the operator behind it is still unnamed.) (Kenya is the market; the Data Protection Act, 2019 and registration with the Data Commissioner probably apply — confirm with counsel.)
2. **Minimum age.** The app asks people to confirm they are 18+ (or have a parent or guardian's permission). Confirm 18 is right, and what "permission" means in practice.
3. **Data location and international transfers** (Firestore region and the use of Google services outside Kenya).
4. **Retention periods** and the deletion timeline. In-app deletion removes the account at once; state whether backups keep copies and for how long.
5. *(Resolved)* Analytics and push notifications are removed; the policy can say so.
6. *(Resolved)* Email and phone are private. Other signed-in users can still see name, username, area, role and points. Say so.
7. **Reporting and moderation promises** — what Canopy commits to do about abusive or unlawful content, and how fast.
   **Also:** an organisation's public record still carries the email it registered with, which may be the representative's own login email. Decide whether to publish a separate public contact address.
8. **Heritage content licensing** — how organisations license material and how communities can withdraw it.
9. **The website:** what it collects (forms, cookies, analytics), and whether the app and website share one policy.
10. **Support channel** and response time to state.

## 13. Where to look in the code if something needs checking

- Registration and data written: `lib/Services/Authentication/community_auth.dart`
- Who can read/write what: `firestore.rules`, `storage.rules`
- Server logic (points, check-in, organisation access): `functions/src/index.ts`, `functions-access/src/orgAccess.ts`
- Permissions: `android/app/src/main/AndroidManifest.xml`
- Guidelines text: `lib/Shared/Pages/community_guidelines.dart`
- Release blockers and setup: `DEPLOYMENT_BRIEF.md`

## 14. Changes made for this brief (state of the code)

Built in the app and awaiting release: age and terms checkbox, Settings → Delete account, Settings → Terms and Privacy policy (website) links, report and block, email and phone moved to a private record, analytics and push packages removed, service listings carry the provider's own contact number. **Not live until deployed:** the new `deleteMyAccount` function and the updated Firestore rules (`reports`, `blockedUsers`, `UserPrivate`, owner-only `org_rep`). The in-app privacy screen is still an older draft and should be replaced with the final policy text.
