const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {validatePoint, searchStations} = require('./stations');
initializeApp();
const placesKey = defineSecret('PLACES_API_KEY');

exports.nearbyStations = onCall({region: 'us-central1', secrets: [placesKey],
  timeoutSeconds: 30, maxInstances: 3, cors: true, invoker: 'public'}, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Giriş yapmalısın.');
  let point;
  try { point = validatePoint(request.data); }
  catch (_) { throw new HttpsError('invalid-argument', 'Konum geçersiz.'); }
  // Only counters are stored; coordinates and Places results are never persisted.
  const database = getFirestore();
  const counter = database.collection('_stationSearchLimits').doc(request.auth.uid);
  const now = Date.now();
  await database.runTransaction(async transaction => {
    const snapshot = await transaction.get(counter);
    const previous = snapshot.data() || {};
    const today = new Date(now).toISOString().slice(0, 10);
    const count = previous.day === today ? previous.count || 0 : 0;
    if (now - (previous.last || 0) < 30000 || count >= 50) {
      throw new HttpsError('resource-exhausted', 'Arama sınırına ulaşıldı.');
    }
    transaction.set(counter, {last: now, day: today, count: count + 1});
  });
  try { return {stations: await searchStations(point, placesKey.value())}; }
  catch (_) { throw new HttpsError('unavailable', 'İstasyon hizmeti kullanılamıyor.'); }
});
