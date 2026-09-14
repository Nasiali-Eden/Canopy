// Runs only against the emulator; never falls back to production.
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Firestore emulator required');
process.env.GCLOUD_PROJECT = 'demo-canopy-ranking';
const {confirmContribution} = require('../lib/index');
const {getFirestore} = require('firebase-admin/firestore');
const db = getFirestore();
const call = (uid, contributionId, verifier = true) => confirmContribution.run({data:{contributionId},auth:{uid,token:{verifier}}});
beforeEach(async () => {
  for (const name of ['Users','activities','contributions','pointAwards']) {
    const docs = await db.collection(name).get();
    await Promise.all(docs.docs.map(d => d.ref.delete()));
  }
  await db.doc('Users/reviewer').set({orgId:'org-a'});
  await db.doc('Users/alice').set({impact_points:999999});
  await db.doc('activities/event').set({orgId:'org-a'});
  await db.doc('contributions/c1').set({userId:'alice',activityId:'event',type:'Time',hours:2,estimatedImpactPoints:999,status:'pending'});
});
afterAll(async () => { await db.terminate(); });
test('concurrent confirmations produce a single ledger award and trusted total', async () => {
  await Promise.all([call('reviewer','c1'),call('reviewer','c1')]);
  expect((await db.doc('Users/alice').get()).data().impact_points).toBe(20);
  expect((await db.doc('Users/alice').get()).data().verifiedContributions).toBe(1);
  expect((await db.collection('pointAwards').get()).size).toBe(1);
});
test('non-verifiers, self-verification and unattributed activities fail closed', async () => {
  await expect(call('reviewer','c1',false)).rejects.toMatchObject({code:'permission-denied'});
  await expect(call('alice','c1')).rejects.toMatchObject({code:'permission-denied'});
  await db.doc('activities/event').set({});
  await expect(call('reviewer','c1')).rejects.toMatchObject({code:'failed-precondition'});
  expect((await db.collection('pointAwards').get()).size).toBe(0);
});
