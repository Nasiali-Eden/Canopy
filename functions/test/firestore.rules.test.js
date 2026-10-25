/**
 * Emulator Suite test — demonstrates the Week 1 exit-gate requirement:
 * "demonstrate rejected unauthorized writes."
 *
 * Run with the Firestore emulator:
 *   firebase emulators:exec --only firestore "npx jest test/firestore.rules.test.js"
 *
 * Requires @firebase/rules-unit-testing (already added to package.json's
 * devDependencies — run `npm install` in functions/ before running this).
 */

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const fs = require("fs");
const path = require("path");

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "citywatch-3ac52-test",
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, "../../firestore.rules"),
        "utf8"
      ),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

test("a resident can create their own contribution with an estimated points value", async () => {
  const alice = testEnv.authenticatedContext("alice");
  await assertSucceeds(
    alice
      .firestore()
      .collection("contributions")
      .doc("c1")
      .set({ userId: "alice", type: "Time", hours: 2.5, estimatedImpactPoints: 25, status: "pending" })
  );
});

test("a client CANNOT set confirmedImpactPoints directly — only the trusted API can", async () => {
  // Seed the document as an admin (bypasses rules), matching how the
  // server would actually create it.
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await adminCtx
      .firestore()
      .collection("contributions")
      .doc("c1")
      .set({ userId: "alice", estimatedImpactPoints: 25 });
  });

  const alice = testEnv.authenticatedContext("alice");
  await assertFails(
    alice
      .firestore()
      .collection("contributions")
      .doc("c1")
      .update({ confirmedImpactPoints: 999 }) // the whole point: a resident
      // should never be able to award themselves points directly.
  );
});

test("someone outside an org cannot write to that org's collectionHandoffs subcollection", async () => {
  const outsider = testEnv.authenticatedContext("mallory", { orgId: "org-b" });
  await assertFails(
    outsider
      .firestore()
      .collection("organisations")
      .doc("org-a")
      .collection("collectionHandoffs")
      .doc("h1")
      .set({ weightKg: 50, verified: true }) // also tests that "verified"
      // can't be self-declared true even by someone with SOME org membership.
  );
});

test("an org member can create a handoff for their own org, but not mark it verified", async () => {
  // authenticatedContext's second argument becomes request.auth.token, so
  // orgId here simulates the custom-claim style check some rules use;
  // this project's rules resolve orgId via a Users/{uid} lookup instead,
  // so seed that doc first.
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await adminCtx.firestore().collection("Users").doc("bob").set({ orgId: "org-a" });
  });
  const bobDb = testEnv.authenticatedContext("bob").firestore();

  await assertSucceeds(
    bobDb
      .collection("organisations")
      .doc("org-a")
      .collection("collectionHandoffs")
      .doc("h2")
      .set({ weightKg: 12, material: "PET" })
  );

  await assertFails(
    bobDb
      .collection("organisations")
      .doc("org-a")
      .collection("collectionHandoffs")
      .doc("h2")
      .update({ verified: true, impactPointsAwarded: 40 })
  );
});

// Phase 3.2 — username reservation (see firestore.rules' `usernames/{username}`
// block and lib/Services/Authentication/username_service.dart).
test("anyone — even signed out — can read a username reservation (availability check)", async () => {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await adminCtx.firestore().collection("usernames").doc("taken").set({ uid: "someone" });
  });
  const anon = testEnv.unauthenticatedContext();
  await assertSucceeds(anon.firestore().collection("usernames").doc("taken").get());
});

test("a signed-out client cannot reserve a username", async () => {
  const anon = testEnv.unauthenticatedContext();
  await assertFails(
    anon.firestore().collection("usernames").doc("newname").set({ uid: "ghost" })
  );
});

test("a signed-in user can only reserve a username for themselves, not someone else", async () => {
  const aliceDb = testEnv.authenticatedContext("alice").firestore();
  await assertFails(
    aliceDb.collection("usernames").doc("newname").set({ uid: "mallory" })
  );
  await assertSucceeds(
    aliceDb.collection("usernames").doc("newname").set({ uid: "alice" })
  );
});

test("a username reservation can't be reassigned once claimed", async () => {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await adminCtx.firestore().collection("usernames").doc("claimed").set({ uid: "alice" });
  });
  const mallory = testEnv.authenticatedContext("mallory");
  await assertFails(
    mallory.firestore().collection("usernames").doc("claimed").update({ uid: "mallory" })
  );
});

// Phase 5.1 — article creation (see firestore.rules' `articles/{docId}`
// block and lib/Services/Article/article_service.dart). Also a regression
// test for a real bug this phase fixed: the rule used to require an
// 'authorId' field the client never sends (it sends 'createdBy'), which
// would have rejected every article creation from the app.
test("a signed-in org rep can create a regular article with createdBy + authorName", async () => {
  const alice = testEnv.authenticatedContext("alice");
  await assertSucceeds(
    alice.firestore().collection("articles").doc("a1").set({
      heading: "Cleanup this weekend",
      category: "news",
      body: "...",
      orgId: "org-a",
      createdBy: "alice",
      authorName: "Org A",
    })
  );
});

test("article creation fails without createdBy/authorName (matches the rule's own requirement)", async () => {
  const alice = testEnv.authenticatedContext("alice");
  await assertFails(
    alice.firestore().collection("articles").doc("a2").set({
      heading: "Missing attribution",
      category: "news",
      body: "...",
      orgId: "org-a",
    })
  );
});

test("a non-Super-Admin org cannot create a 'special' category article", async () => {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await adminCtx.firestore().collection("organizations").doc("org-a").set({ isSuperAdmin: false });
  });
  const alice = testEnv.authenticatedContext("alice");
  await assertFails(
    alice.firestore().collection("articles").doc("a3").set({
      heading: "What Is Blockchain?",
      category: "special",
      body: "...",
      orgId: "org-a",
      createdBy: "alice",
      authorName: "Org A",
    })
  );
});

test("the Super Admin org CAN create a 'special' category article", async () => {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await adminCtx.firestore().collection("organizations").doc("shield-hq").set({ isSuperAdmin: true });
  });
  const shieldRep = testEnv.authenticatedContext("shieldRep");
  await assertSucceeds(
    shieldRep.firestore().collection("articles").doc("a4").set({
      heading: "What Is Blockchain?",
      category: "special",
      body: "...",
      orgId: "shield-hq",
      createdBy: "shieldRep",
      authorName: "SHIELD International",
    })
  );
});

test('ranking totals and verification authority cannot be supplied during signup', async () => {
  const db = testEnv.authenticatedContext('alice').firestore();
  await assertFails(db.collection('Users').doc('alice').set({impact_points:999}));
  await assertFails(db.collection('Users').doc('alice').set({impact_points:0,orgId:'org-a'}));
  await assertFails(db.collection('Users').doc('alice').set({impact_points:0,rankingVersion:1}));
  await assertSucceeds(db.collection('Users').doc('alice').set({impact_points:0,name:'Alice'}));
  await assertFails(db.collection('Users').doc('alice').update({impact_points:999}));
  await assertFails(db.collection('users').doc('alice').set({totalPoints:999}));
});
test('confirmation fields cannot be smuggled into contribution creation', async () => {
  const db = testEnv.authenticatedContext('alice').firestore();
  await assertFails(db.collection('contributions').doc('forged').set({userId:'alice',status:'pending',estimatedImpactPoints:20,confirmedImpactPoints:999}));
  await assertFails(db.collection('pointAwards').doc('forged').set({userId:'alice',points:999}));
});
