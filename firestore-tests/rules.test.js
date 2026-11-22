// Tests for ../firestore.rules against the Firestore emulator.
//
// From the repo root:
//   npm --prefix firestore-tests install
//   npm --prefix firestore-tests run test:emulator
//
// The emulator needs Java 11+ (Android Studio's bundled one works:
// JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home").

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  collection,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

// Uids sort as alice < bob < carol, like real Firebase uids (no "_").
const ALICE = 'alice';
const BOB = 'bob';
const CAROL = 'carol';
const PAIR = `${ALICE}_${BOB}`;

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-friend360',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(() => env.clearFirestore());

const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

/** Writes data directly, skipping the rules (test setup). */
async function seed(fn) {
  await env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));
}

function profile(uid, username, friendCode) {
  return {
    displayName: uid,
    username,
    avatarEmoji: '🦊',
    friendCode,
    createdAt: serverTimestamp(),
  };
}

/** Same writes as FirestoreProfileRepository.createProfile. */
function createProfile(firestore, uid, username, friendCode) {
  return runTransaction(firestore, async (tx) => {
    tx.set(doc(firestore, `usernames/${username}`), { uid });
    tx.set(doc(firestore, `friendCodes/${friendCode}`), { uid });
    tx.set(doc(firestore, `users/${uid}`), profile(uid, username, friendCode));
    tx.set(doc(firestore, `users/${uid}/private/goals`), { steps: 8000 });
  });
}

async function seedProfiles(...uids) {
  const codes = { alice: 'AAAAA2', bob: 'BBBBB2', carol: 'CCCCC2' };
  await seed(async (f) => {
    for (const uid of uids) {
      await setDoc(doc(f, `users/${uid}`), {
        displayName: uid,
        username: uid,
        avatarEmoji: '🦊',
        friendCode: codes[uid],
      });
      await setDoc(doc(f, `usernames/${uid}`), { uid });
      await setDoc(doc(f, `friendCodes/${codes[uid]}`), { uid });
    }
  });
}

function request(requesterId, addresseeId) {
  return {
    requesterId,
    addresseeId,
    users: [requesterId, addresseeId],
    status: 'pending',
    createdAt: serverTimestamp(),
  };
}

describe('profiles', () => {
  test('creating your profile with its claims works', async () => {
    await assertSucceeds(createProfile(db(ALICE), ALICE, 'alice', 'AAAAA2'));
  });

  test("can't create someone else's profile", async () => {
    await assertFails(createProfile(db(ALICE), BOB, 'bob', 'BBBBB2'));
  });

  test('a profile without its claims is rejected', async () => {
    const f = db(ALICE);
    await assertFails(setDoc(doc(f, `users/${ALICE}`), profile(ALICE, 'alice', 'AAAAA2')));
  });

  test("can't claim a username without the matching profile", async () => {
    const f = db(ALICE);
    await assertFails(setDoc(doc(f, 'usernames/squatted'), { uid: ALICE }));
  });

  test("can't take a username someone already has", async () => {
    await seedProfiles(BOB);
    await assertFails(createProfile(db(ALICE), ALICE, 'bob', 'AAAAA2'));
  });

  test('invalid usernames and friend codes are rejected', async () => {
    await assertFails(createProfile(db(ALICE), ALICE, 'No Spaces', 'AAAAA2'));
    await assertFails(createProfile(db(ALICE), ALICE, 'alice', 'aaaaa0'));
  });

  test('signed-in users can read profiles, nobody else can', async () => {
    await seedProfiles(BOB);
    await assertSucceeds(getDoc(doc(db(ALICE), `users/${BOB}`)));
    await assertFails(getDoc(doc(anon(), `users/${BOB}`)));
  });

  test('goals are private', async () => {
    await assertSucceeds(createProfile(db(ALICE), ALICE, 'alice', 'AAAAA2'));
    await assertSucceeds(getDoc(doc(db(ALICE), `users/${ALICE}/private/goals`)));
    await assertFails(getDoc(doc(db(BOB), `users/${ALICE}/private/goals`)));
  });

  test("username and friend code can't change, name can", async () => {
    await seedProfiles(ALICE);
    const ref = doc(db(ALICE), `users/${ALICE}`);
    await assertSucceeds(updateDoc(ref, { displayName: 'Alice A' }));
    await assertFails(updateDoc(ref, { username: 'queen' }));
    await assertFails(updateDoc(ref, { friendCode: 'ZZZZZ2' }));
  });

  test('deleting your own profile and claims works', async () => {
    await seedProfiles(ALICE);
    const f = db(ALICE);
    const batch = writeBatch(f);
    batch.delete(doc(f, `users/${ALICE}/private/goals`));
    batch.delete(doc(f, 'usernames/alice'));
    batch.delete(doc(f, 'friendCodes/AAAAA2'));
    batch.delete(doc(f, `users/${ALICE}`));
    await assertSucceeds(batch.commit());
  });

  test("can't delete someone else's claims", async () => {
    await seedProfiles(BOB);
    await assertFails(deleteDoc(doc(db(ALICE), 'usernames/bob')));
  });
});

describe('friendships', () => {
  beforeEach(() => seedProfiles(ALICE, BOB, CAROL));

  test('sending a request works', async () => {
    const f = db(ALICE);
    await assertSucceeds(setDoc(doc(f, `friendships/${PAIR}`), request(ALICE, BOB)));
  });

  test('the addressee can send it too (same pair id)', async () => {
    const f = db(BOB);
    await assertSucceeds(setDoc(doc(f, `friendships/${PAIR}`), request(BOB, ALICE)));
  });

  test('checking for a request that does not exist yet works', async () => {
    await assertSucceeds(getDoc(doc(db(ALICE), `friendships/${PAIR}`)));
  });

  test("can't peek at other people's pairs", async () => {
    await assertFails(getDoc(doc(db(CAROL), `friendships/${PAIR}`)));
  });

  test("can't send a request as someone else", async () => {
    await assertFails(setDoc(doc(db(CAROL), `friendships/${PAIR}`), request(ALICE, BOB)));
  });

  test("can't create a friendship that's already accepted", async () => {
    const data = { ...request(ALICE, BOB), status: 'accepted' };
    await assertFails(setDoc(doc(db(ALICE), `friendships/${PAIR}`), data));
  });

  test('the id must be the sorted pair', async () => {
    const f = db(ALICE);
    await assertFails(setDoc(doc(f, `friendships/${BOB}_${ALICE}`), request(ALICE, BOB)));
    await assertFails(setDoc(doc(f, `friendships/${ALICE}_${CAROL}`), request(ALICE, BOB)));
  });

  test("can't add yourself or someone without a profile", async () => {
    const f = db(ALICE);
    await assertFails(setDoc(doc(f, `friendships/${ALICE}_${ALICE}`), request(ALICE, ALICE)));
    await assertFails(setDoc(doc(f, `friendships/${ALICE}_zed`), request(ALICE, 'zed')));
  });

  test('users must list both people in order', async () => {
    const data = { ...request(ALICE, BOB), users: [ALICE, CAROL] };
    await assertFails(setDoc(doc(db(ALICE), `friendships/${PAIR}`), data));
  });

  test("can't overwrite an existing request", async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), `friendships/${PAIR}`), request(ALICE, BOB)));
    await assertFails(setDoc(doc(db(BOB), `friendships/${PAIR}`), request(BOB, ALICE)));
  });

  describe('with a pending request from alice to bob', () => {
    beforeEach(() =>
      assertSucceeds(setDoc(doc(db(ALICE), `friendships/${PAIR}`), request(ALICE, BOB))),
    );

    const accept = { status: 'accepted', respondedAt: serverTimestamp() };

    test('only bob can accept', async () => {
      await assertFails(updateDoc(doc(db(ALICE), `friendships/${PAIR}`), accept));
      await assertFails(updateDoc(doc(db(CAROL), `friendships/${PAIR}`), accept));
      await assertSucceeds(updateDoc(doc(db(BOB), `friendships/${PAIR}`), accept));
    });

    test("accepting can't change anything else", async () => {
      await assertFails(
        updateDoc(doc(db(BOB), `friendships/${PAIR}`), { ...accept, requesterId: BOB }),
      );
    });

    test('bob can decline and alice can cancel (both delete)', async () => {
      await assertSucceeds(deleteDoc(doc(db(BOB), `friendships/${PAIR}`)));
      await assertSucceeds(setDoc(doc(db(ALICE), `friendships/${PAIR}`), request(ALICE, BOB)));
      await assertSucceeds(deleteDoc(doc(db(ALICE), `friendships/${PAIR}`)));
    });

    test('carol can neither read nor delete it', async () => {
      await assertFails(getDoc(doc(db(CAROL), `friendships/${PAIR}`)));
      await assertFails(deleteDoc(doc(db(CAROL), `friendships/${PAIR}`)));
    });

    test('listing works only for your own friendships', async () => {
      const mine = (f, uid) =>
        getDocs(query(collection(f, 'friendships'), where('users', 'array-contains', uid)));
      const result = await assertSucceeds(mine(db(ALICE), ALICE));
      if (result.size !== 1) throw new Error(`expected 1 friendship, got ${result.size}`);
      await assertFails(mine(db(CAROL), ALICE));
      await assertFails(getDocs(collection(db(CAROL), 'friendships')));
    });

    test('once accepted, either friend can unfriend', async () => {
      await assertSucceeds(updateDoc(doc(db(BOB), `friendships/${PAIR}`), accept));
      await assertFails(updateDoc(doc(db(BOB), `friendships/${PAIR}`), { status: 'pending' }));
      await assertSucceeds(deleteDoc(doc(db(ALICE), `friendships/${PAIR}`)));
    });
  });
});

describe('emails', () => {
  const ALICE_EMAIL = 'alice@example.com';
  /** Alice signed in with her (mixed-case) email on the token. */
  const aliceWithEmail = () =>
    env.authenticatedContext(ALICE, { email: 'Alice@Example.com' }).firestore();

  /** Same writes as FirestoreProfileRepository.saveEmail. */
  function saveEmail(firestore, uid, email) {
    const batch = writeBatch(firestore);
    batch.set(doc(firestore, `users/${uid}/private/account`), { email });
    batch.set(doc(firestore, `emails/${email}`), { uid });
    return batch.commit();
  }

  test('you can save your own lowercased email, and again later', async () => {
    await assertSucceeds(saveEmail(aliceWithEmail(), ALICE, ALICE_EMAIL));
    await assertSucceeds(saveEmail(aliceWithEmail(), ALICE, ALICE_EMAIL));
  });

  test("you can't claim an email that isn't on your account", async () => {
    await assertFails(saveEmail(aliceWithEmail(), ALICE, 'bob@example.com'));
    await assertFails(saveEmail(db(ALICE), ALICE, ALICE_EMAIL)); // no email
    await assertFails(
      setDoc(doc(aliceWithEmail(), `emails/${ALICE_EMAIL}`), { uid: BOB }),
    );
  });

  test('anyone signed in can look up one exact email, but never list them', async () => {
    await seed((f) => saveEmail(f, ALICE, ALICE_EMAIL));
    await assertSucceeds(getDoc(doc(db(BOB), `emails/${ALICE_EMAIL}`)));
    await assertFails(getDoc(doc(anon(), `emails/${ALICE_EMAIL}`)));
    await assertFails(getDocs(collection(db(BOB), 'emails')));
  });

  test('only you can read your saved email', async () => {
    await seed((f) => saveEmail(f, ALICE, ALICE_EMAIL));
    await assertSucceeds(getDoc(doc(db(ALICE), `users/${ALICE}/private/account`)));
    await assertFails(getDoc(doc(db(BOB), `users/${ALICE}/private/account`)));
  });

  test('only the owner can delete the lookup', async () => {
    await seed((f) => saveEmail(f, ALICE, ALICE_EMAIL));
    await assertFails(deleteDoc(doc(db(BOB), `emails/${ALICE_EMAIL}`)));
    await assertSucceeds(deleteDoc(doc(db(ALICE), `emails/${ALICE_EMAIL}`)));
  });
});
