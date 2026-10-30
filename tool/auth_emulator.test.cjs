const {test} = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase/app');
const {getAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithEmailAndPassword, signOut} = require('firebase/auth');

test('Firebase rejects duplicate email, retains the original account and rejects wrong passwords', async () => {
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST, 'Authentication emulator required');
  const app = initializeApp({apiKey: 'demo-key', projectId: 'demo-mycar'}, 'duplicates');
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`, {disableWarnings: true});
  const email = `unique-${Date.now()}@example.com`;
  try {
    const original = await createUserWithEmailAndPassword(auth, email, 'secret123');
    const uid = original.user.uid;
    await signOut(auth);
    await assert.rejects(createUserWithEmailAndPassword(auth, email.toUpperCase(), 'other123'), {code: 'auth/email-already-in-use'});
    assert.equal(auth.currentUser, null);
    await assert.rejects(signInWithEmailAndPassword(auth, email, 'wrong123'));
    const restored = await signInWithEmailAndPassword(auth, email, 'secret123');
    assert.equal(restored.user.uid, uid);
    await signOut(auth);
    assert.equal(auth.currentUser, null);
  } finally {
    await deleteApp(app);
  }
});
