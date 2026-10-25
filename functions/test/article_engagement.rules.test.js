/**
 * Rules tests for article upvotes and responses
 * (lib/Services/Article/article_engagement_service.dart).
 *
 * Run with the Firestore emulator, from functions/:
 *   firebase emulators:exec --only firestore --project demo-canopy "npx jest test/article_engagement.rules.test.js"
 */

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc, setDoc, updateDoc, writeBatch, increment, serverTimestamp, collection, addDoc,
} = require("firebase/firestore");
const fs = require("fs");
const path = require("path");

let env;
const A = "articles/a1";

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-canopy",
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

afterAll(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, A), { title: "T", orgId: "org1", createdBy: "author", authorName: "Org", upvotes: 0 });
    await setDoc(doc(db, "Users/mod"), { orgId: "org1" });
    await setDoc(doc(db, `${A}/responses/r1`), {
      authorUid: "alice", authorName: "Alice", body: "Hello", parentId: null, upvotes: 0, deleted: false,
    });
  });
});

const db = (uid) => env.authenticatedContext(uid).firestore();

function vote(fs, target, uid, on, step = on ? 1 : -1) {
  const b = writeBatch(fs);
  const v = doc(fs, `${target}/votes/${uid}`);
  if (on) b.set(v, { createdAt: serverTimestamp() }); else b.delete(v);
  b.update(doc(fs, target), { upvotes: increment(step) });
  return b.commit();
}

describe("article upvotes", () => {
  test("member can upvote and remove the upvote", async () => {
    await assertSucceeds(vote(db("bob"), A, "bob", true));
    await assertSucceeds(vote(db("bob"), A, "bob", false));
  });
  test("cannot vote twice", async () => {
    await assertSucceeds(vote(db("bob"), A, "bob", true));
    await assertFails(vote(db("bob"), A, "bob", true));
  });
  test("cannot bump the counter without a vote, or by more than one", async () => {
    await assertFails(updateDoc(doc(db("bob"), A), { upvotes: increment(1) }));
    await assertFails(vote(db("bob"), A, "bob", true, 2));
  });
  test("cannot vote as someone else", async () => {
    await assertFails(vote(db("bob"), A, "carol", true));
  });
  test("signed-out cannot vote", async () => {
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(vote(anon, A, "bob", true));
  });
  test("article author cannot set the counter directly", async () => {
    await assertFails(updateDoc(doc(db("author"), A), { upvotes: 99 }));
  });
});

describe("responses", () => {
  const post = (uid, data) =>
    addDoc(collection(db(uid), `${A}/responses`), {
      authorUid: uid, authorName: "X", body: "Hi", parentId: null, upvotes: 0, deleted: false,
      createdAt: serverTimestamp(), ...data,
    });

  test("member can respond and reply as themselves", async () => {
    await assertSucceeds(post("bob", {}));
    await assertSucceeds(post("bob", { parentId: "r1" }));
  });
  test("cannot respond as someone else, with fake upvotes, empty, or to a missing parent", async () => {
    await assertFails(post("bob", { authorUid: "alice" }));
    await assertFails(post("bob", { upvotes: 5 }));
    await assertFails(post("bob", { body: "" }));
    await assertFails(post("bob", { parentId: "nope" }));
  });
  test("signed-out can read but not post", async () => {
    const anon = env.unauthenticatedContext().firestore();
    const { getDoc } = require("firebase/firestore");
    await assertSucceeds(getDoc(doc(anon, `${A}/responses/r1`)));
    await assertFails(addDoc(collection(anon, `${A}/responses`), { authorUid: "x", body: "Hi", upvotes: 0, deleted: false }));
  });
  test("author edits own text; others cannot", async () => {
    await assertSucceeds(updateDoc(doc(db("alice"), `${A}/responses/r1`), { body: "Edited", editedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(db("bob"), `${A}/responses/r1`), { body: "Hacked", editedAt: serverTimestamp() }));
  });
  test("author or the publishing org can remove; others cannot", async () => {
    const removal = { body: "", deleted: true, removedBy: "organisation" };
    await assertFails(updateDoc(doc(db("bob"), `${A}/responses/r1`), removal));
    await assertSucceeds(updateDoc(doc(db("mod"), `${A}/responses/r1`), removal));
  });
  test("author can remove own", async () => {
    await assertSucceeds(updateDoc(doc(db("alice"), `${A}/responses/r1`), { body: "", deleted: true, removedBy: "author" }));
  });
  test("response upvotes follow the same rules", async () => {
    const R = `${A}/responses/r1`;
    await assertSucceeds(vote(db("bob"), R, "bob", true));
    await assertFails(vote(db("bob"), R, "bob", true));
    await assertFails(updateDoc(doc(db("alice"), R), { upvotes: 50 }));
    await assertSucceeds(vote(db("bob"), R, "bob", false));
  });
});

describe("org handoffs (organizations/ spelling, used by the app)", () => {
  test("member can log a handoff but not verify it; outsiders cannot log", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), "Users/mod"), { orgId: "org1" }));
    const m = db("mod");
    const H = "organizations/org1/collectionHandoffs/h1";
    await assertSucceeds(setDoc(doc(m, H), { weightKg: 10 }));
    await assertFails(updateDoc(doc(m, H), { verified: true }));
    await assertFails(setDoc(doc(db("bob"), "organizations/org1/collectionHandoffs/h2"), { weightKg: 1 }));
  });
});
