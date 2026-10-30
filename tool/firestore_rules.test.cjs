const {test, before, after} = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, setDoc, getDoc, getDocs, collection, updateDoc, deleteDoc, writeBatch, serverTimestamp, Timestamp, runTransaction} = require('firebase/firestore');
let env;
test('Bakım geçmişi kullanıcıya özeldir, kilometre ve parçalar doğrulanır', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const parent = doc(db, 'users/alice/vehicles/maintenance-car');
  const target = doc(db, 'users/alice/vehicles/maintenance-car/maintenance/m1');
  const entry = {date: Timestamp.fromDate(new Date('2025-01-01T00:00:00Z')), odometerKm: 110000,
    intervalKm: 10000, amountKurus: 250050, items: ['engine_oil', 'oil_filter'],
    details: '', service: 'Servis', notes: '', createdAt: serverTimestamp(), updatedAt: serverTimestamp()};
  await assertSucceeds(setDoc(parent, vehicle()));
  await assertSucceeds(setDoc(target, entry));
  await assertSucceeds(setDoc(doc(db, 'users/alice/vehicles/maintenance-car/maintenance/legacy'), {...entry, intervalMonths: 12}));
  await assertSucceeds(getDocs(collection(db, 'users/alice/vehicles/maintenance-car/maintenance')));
  for (const other of [env.authenticatedContext('bob').firestore(), env.unauthenticatedContext().firestore()]) {
    const foreign = doc(other, 'users/alice/vehicles/maintenance-car/maintenance/m1');
    await assertFails(getDoc(foreign));
    await assertFails(setDoc(foreign, entry));
  }
  for (const invalid of [{odometerKm: 120001}, {intervalKm: 0}, {intervalMonths: 61},
    {amountKurus: -1}, {items: ['invalid']}, {items: ['engine_oil', 'engine_oil']},
    {items: [], details: ''}, {extra: true}, {date: Timestamp.fromDate(new Date('2100-01-01'))}]) {
    await assertFails(setDoc(doc(db, 'users/alice/vehicles/maintenance-car/maintenance/invalid'), {...entry, ...invalid}));
  }
  await assertSucceeds(updateDoc(target, {details: 'Fren kontrolü', updatedAt: serverTimestamp()}));
  await assertFails(deleteDoc(target));
  await assertFails(setDoc(doc(db, 'users/alice/vehicles/missing/maintenance/m1'), entry));
  await assertSucceeds(updateDoc(parent, {archived: true, updatedAt: serverTimestamp()}));
  await assertFails(updateDoc(target, {notes: 'Değişiklik', updatedAt: serverTimestamp()}));
});
const projectId = 'demo-mycar';
const vehicle = () => ({brand: 'BMW', model: '320i', year: 2020, plate: '34 TEST 1', fuelType: 'Benzin', transmission: 'Otomatik', engineCc: 1600, currentKm: 120000, archived: false, createdAt: serverTimestamp(), updatedAt: serverTimestamp()});
test('Poliçe sahipliği, basamak/kapsam, tarihler ve arşiv korunur', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const parent = doc(db, 'users/alice/vehicles/policy-car');
  const target = doc(db, 'users/alice/vehicles/policy-car/policies/p1');
  const policy = {kind: 'traffic', company: 'Örnek Sigorta', number: 'P-123', startDate: Timestamp.fromDate(new Date('2026-10-01T00:00:00Z')), endDate: Timestamp.fromDate(new Date('2027-10-01T00:00:00Z')), premiumKurus: 1250050, level: '', step: 8, notes: '', archived: false, createdAt: serverTimestamp(), updatedAt: serverTimestamp()};
  await assertSucceeds(setDoc(parent, vehicle()));
  await assertSucceeds(setDoc(target, policy));
  for (const other of [env.authenticatedContext('bob').firestore(), env.unauthenticatedContext().firestore()]) {
    const foreign = doc(other, 'users/alice/vehicles/policy-car/policies/p1');
    await assertFails(getDoc(foreign));
    await assertFails(setDoc(foreign, policy));
    await assertFails(getDocs(collection(other, 'users/alice/vehicles/policy-car/policies')));
  }
  for (const change of [{step: 9}, {step: -1}, {level: 'Tam Kasko'}, {premiumKurus: 0}, {endDate: policy.startDate}, {company: ''}, {extra: true}]) {
    await assertFails(setDoc(doc(db, 'users/alice/vehicles/policy-car/policies/invalid'), {...policy, ...change}));
  }
  await assertSucceeds(setDoc(doc(db, 'users/alice/vehicles/policy-car/policies/casco'), {...policy, kind: 'casco', step: null, level: 'Genişletilmiş Kasko'}));
  await assertFails(setDoc(doc(db, 'users/alice/vehicles/policy-car/policies/invalid-casco'), {...policy, kind: 'casco', step: 4, level: 'Tam Kasko'}));
  await assertSucceeds(updateDoc(target, {archived: true, updatedAt: serverTimestamp()}));
  await assertSucceeds(updateDoc(target, {archived: false, updatedAt: serverTimestamp()}));
  await assertFails(deleteDoc(target));
  await assertFails(setDoc(doc(db, 'users/alice/vehicles/missing/policies/p1'), policy));
  await assertSucceeds(updateDoc(parent, {archived: true, updatedAt: serverTimestamp()}));
  await assertFails(updateDoc(target, {premiumKurus: 20000, updatedAt: serverTimestamp()}));
});
test('Park geçmişi atomik kapanır, son 5 kayıt kalır ve tekrar kapatma çoğaltmaz', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const car = doc(db, 'users/alice/vehicles/history-car');
  const current = doc(db, 'users/alice/vehicles/history-car/parking/current');
  const history = doc(db, 'users/alice/vehicles/history-car/parking/history');
  await assertSucceeds(setDoc(car, vehicle()));
  async function finish() {
    await runTransaction(db, async tx => {
      const old = await tx.get(current);
      const past = await tx.get(history);
      if (!old.data().active) return;
      const entry = {...old.data(), active: false};
      delete entry.updatedAt;
      tx.set(history, {entries: [entry, ...(past.data()?.entries || [])].slice(0, 5), updatedAt: serverTimestamp()});
      tx.update(current, {active: false, updatedAt: serverTimestamp()});
    });
  }
  for (let i = 0; i < 6; i++) {
    await assertSucceeds(setDoc(current, {indoor: true, active: true, savedAt: serverTimestamp(), latitude: null, longitude: null, accuracy: null, floor: '-2', section: 'B', space: String(i), notes: '', updatedAt: serverTimestamp()}));
    await assertSucceeds(finish());
  }
  await assertSucceeds(finish());
  const entries = (await getDoc(history)).data().entries;
  require('node:assert/strict').deepEqual(entries.map(e => e.space), ['5', '4', '3', '2', '1']);
  await assertFails(setDoc(history, {entries: [...entries, entries[0]], updatedAt: serverTimestamp()}));
  await assertFails(setDoc(history, {entries: [{...entries[0], active: true}], updatedAt: serverTimestamp()}));
  const foreign = doc(env.authenticatedContext('bob').firestore(), 'users/alice/vehicles/history-car/parking/history');
  await assertFails(getDoc(foreign));
  await assertFails(setDoc(foreign, {entries, updatedAt: serverTimestamp()}));
});
before(async () => { env = await initializeTestEnvironment({projectId, firestore: {host: '127.0.0.1', port: 8085, rules: fs.readFileSync(path.join(__dirname, '../firestore.rules'), 'utf8')}}); });
after(async () => { if (env) await env.cleanup(); });
test('Park kaydı yalnızca sahibine açık; konum ve kapalı otopark doğrulanır', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const target = doc(alice, 'users/alice/vehicles/park-car/parking/current');
  await assertSucceeds(setDoc(doc(alice, 'users/alice/vehicles/park-car'), vehicle()));
  const parking = {indoor: false, active: true, savedAt: serverTimestamp(), latitude: 41.01, longitude: 28.97, accuracy: 12, floor: '', section: '', space: '', notes: '', updatedAt: serverTimestamp()};
  await assertSucceeds(setDoc(target, parking));
  for (const db of [env.authenticatedContext('bob').firestore(), env.unauthenticatedContext().firestore()]) {
    const foreign = doc(db, 'users/alice/vehicles/park-car/parking/current');
    await assertFails(getDoc(foreign));
    await assertFails(setDoc(foreign, parking));
  }
  for (const change of [{latitude: 91}, {longitude: -181}, {accuracy: -1}, {indoor: true}, {extra: true}]) {
    await assertFails(setDoc(target, {...parking, ...change}));
  }
  await assertSucceeds(setDoc(target, {...parking, indoor: true, floor: '-2', section: 'B', space: '125'}));
  await assertFails(setDoc(target, {...parking, indoor: true, latitude: null, floor: '-2', section: 'B'}));
  await assertSucceeds(setDoc(target, {...parking, indoor: true, latitude: null, longitude: null, accuracy: null, floor: '-2', section: 'B', space: '125'}));
  await assertSucceeds(updateDoc(target, {active: false, updatedAt: serverTimestamp()}));
  await assertFails(deleteDoc(target));
  await assertFails(setDoc(doc(alice, 'users/alice/vehicles/park-car/parking/other'), parking));
  await assertFails(setDoc(doc(alice, 'users/alice/vehicles/missing/parking/current'), parking));
  await assertSucceeds(updateDoc(doc(alice, 'users/alice/vehicles/park-car'), {archived: true, updatedAt: serverTimestamp()}));
  await assertFails(setDoc(target, parking));
});
test('Sahibi araç oluşturur ve kendi listesini okur', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/alice/vehicles/car'), vehicle()));
  await assertSucceeds(getDoc(doc(db, 'users/alice/vehicles/car')));
  await assertSucceeds(getDocs(collection(db, 'users/alice/vehicles')));
});
test('Başka hesap ve girişsiz kullanıcı erişemez', async () => {
  for (const db of [env.authenticatedContext('bob').firestore(), env.unauthenticatedContext().firestore()]) {
    await assertFails(getDoc(doc(db, 'users/alice/vehicles/car')));
    await assertFails(getDocs(collection(db, 'users/alice/vehicles')));
    await assertFails(setDoc(doc(db, 'users/alice/vehicles/foreign'), vehicle()));
    await assertFails(updateDoc(doc(db, 'users/alice/vehicles/car'), {currentKm: 1, updatedAt: serverTimestamp()}));
  }
});
test('Alan doğrulaması ve oluşturulma tarihi korunur', async () => {
  const db = env.authenticatedContext('alice').firestore();
  for (const change of [{currentKm: -1}, {year: 1800}, {engineCc: '1600'}, {brand: ''}, {extra: true}, {fuelType: 'Hatalı'}]) {
    await assertFails(setDoc(doc(db, 'users/alice/vehicles/invalid'), {...vehicle(), ...change}));
  }
  await assertFails(updateDoc(doc(db, 'users/alice/vehicles/car'), {createdAt: serverTimestamp(), updatedAt: serverTimestamp()}));
});
test('Yeni araç ve aktif seçim atomik; olmayan/başkasına ait araç seçilemez', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, 'users/alice/vehicles/new'), vehicle());
  batch.set(doc(db, 'users/alice'), {activeVehicleId: 'new'});
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(db, 'users/alice'), {activeVehicleId: 'missing'}));
  await assertFails(updateDoc(doc(db, 'users/alice'), {role: 'admin'}));
});
test('Arşivleme/geri alma çalışır; kalıcı silme ve alt koleksiyon yazımı kapalı', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const batch = writeBatch(db);
  batch.update(doc(db, 'users/alice/vehicles/new'), {archived: true, updatedAt: serverTimestamp()});
  batch.update(doc(db, 'users/alice'), {activeVehicleId: null});
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(db, 'users/alice'), {activeVehicleId: 'new'}));
  await assertSucceeds(updateDoc(doc(db, 'users/alice/vehicles/new'), {archived: false, updatedAt: serverTimestamp()}));
  await assertFails(deleteDoc(doc(db, 'users/alice/vehicles/new')));
  await assertFails(setDoc(doc(db, 'users/alice/vehicles/new/fuelRecords/fuel'), {liters: 40}));
});
const activity = (kind = 'fuel') => ({kind, date: Timestamp.fromDate(new Date('2026-10-01T09:00:00Z')), odometerKm: 125000,
  amountKurus: 211500, category: kind === 'fuel' ? 'Yakıt' : 'Tamir', litersMilli: kind === 'fuel' ? 42300 : 0,
  fullTank: kind === 'fuel', fuelType: kind === 'fuel' ? 'Benzin' : '', notes: 'test', archived: false,
  createdAt: serverTimestamp(), updatedAt: serverTimestamp()});
async function writeActivity(db, id, data) {
  return runTransaction(db, async tx => {
    const car = doc(db, 'users/alice/vehicles/car');
    const snapshot = await tx.get(car);
    tx.set(doc(db, 'users/alice/vehicles/car/activityRecords/' + id), data);
    tx.update(car, {activityRevision: (snapshot.data().activityRevision || 0) + 1, baselineKm: 120000, recordMaxKm: 125000, currentKm: 125000, updatedAt: serverTimestamp()});
  });
}
test('Yakıt/masraf ve kilometre atomik yazılır; doğrulama ve sahiplik korunur', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertSucceeds(writeActivity(alice, 'fuel', activity()));
  await assertSucceeds(writeActivity(alice, 'expense', activity('expense')));
  await assertSucceeds(getDocs(collection(alice, 'users/alice/vehicles/car/activityRecords')));
  await assertFails(setDoc(doc(alice, 'users/alice/vehicles/car/activityRecords/no-parent'), activity()));
  for (const change of [{amountKurus: -1}, {amountKurus: 1.5}, {litersMilli: 0}, {extra: 1}, {category: 'Tamir'}, {date: Timestamp.fromDate(new Date('2100-01-01'))}]) {
    await assertFails(writeActivity(alice, 'invalid', {...activity(), ...change}));
  }
  for (const db of [env.authenticatedContext('bob').firestore(), env.unauthenticatedContext().firestore()]) {
    await assertFails(getDoc(doc(db, 'users/alice/vehicles/car/activityRecords/fuel')));
    await assertFails(getDocs(collection(db, 'users/alice/vehicles/car/activityRecords')));
    await assertFails(setDoc(doc(db, 'users/alice/vehicles/car/activityRecords/foreign'), activity()));
    await assertFails(updateDoc(doc(db, 'users/alice/vehicles/car/activityRecords/fuel'), {amountKurus: 1}));
  }
});
test('Kayıt arşivleme ve düzeltme işlem sürümü gerektirir; arşivli araca eklenemez', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const target = doc(db, 'users/alice/vehicles/car/activityRecords/fuel');
  await assertFails(updateDoc(target, {archived: true, updatedAt: serverTimestamp()}));
  await assertSucceeds(runTransaction(db, async tx => {
    const car = doc(db, 'users/alice/vehicles/car'); const snapshot = await tx.get(car);
    tx.update(target, {archived: true, updatedAt: serverTimestamp()});
    tx.update(car, {activityRevision: snapshot.data().activityRevision + 1, updatedAt: serverTimestamp()});
  }));
  await assertFails(deleteDoc(target));
  await assertSucceeds(updateDoc(doc(db, 'users/alice/vehicles/car'), {archived: true, updatedAt: serverTimestamp()}));
  await assertFails(writeActivity(db, 'archived', activity()));
});
test('Muayene sahibi kaydeder; tarih/aralık ve diğer hesap erişimi korunur', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/alice/vehicles/inspection-car'), vehicle()));
  const target = doc(db, 'users/alice/vehicles/inspection-car/inspection/current');
  const inspection = {lastDate: Timestamp.fromDate(new Date('2024-10-13')), nextDate: Timestamp.fromDate(new Date('2026-10-13')),
    intervalYears: 2, notes: '', createdAt: serverTimestamp(), updatedAt: serverTimestamp()};
  await assertSucceeds(setDoc(target, inspection));
  await assertSucceeds(getDoc(target));
  await assertSucceeds(updateDoc(target, {notes: 'Güncellendi', updatedAt: serverTimestamp()}));
  for (const change of [{intervalYears: 0}, {intervalYears: 6}, {nextDate: Timestamp.fromDate(new Date('2035-01-01'))}, {lastDate: Timestamp.fromDate(new Date('2100-01-01'))}, {extra: true}]) {
    await assertFails(setDoc(doc(db, 'users/alice/vehicles/inspection-car/inspection/invalid'), {...inspection, ...change}));
    await assertFails(updateDoc(target, {...change, updatedAt: serverTimestamp()}));
  }
  await assertFails(updateDoc(target, {createdAt: serverTimestamp(), updatedAt: serverTimestamp()}));
  for (const other of [env.authenticatedContext('bob').firestore(), env.unauthenticatedContext().firestore()]) {
    const foreign = doc(other, 'users/alice/vehicles/inspection-car/inspection/current');
    await assertFails(getDoc(foreign)); await assertFails(setDoc(foreign, inspection));
  }
  await assertSucceeds(updateDoc(doc(db, 'users/alice/vehicles/inspection-car'), {archived: true, updatedAt: serverTimestamp()}));
  await assertFails(updateDoc(target, {notes: 'Arşivli', updatedAt: serverTimestamp()}));
});

test('Ekspertiz parça durumları, rapor ve sahiplik korunur', async () => {
 const db=env.authenticatedContext('alice').firestore();
 const car=doc(db,'users/alice/vehicles/expertise-car');
 const target=doc(db,'users/alice/vehicles/expertise-car/expertise/current');
 const keys=['front_bumper','hood','roof','trunk','rear_bumper','left_front_wing','right_front_wing','left_front_door','right_front_door','left_rear_door','right_rear_door','left_rear_wing','right_rear_wing'];
 const record={parts:Object.fromEntries(keys.map(k=>[k,'unknown'])),notes:'',reportId:'',reportName:'',createdAt:serverTimestamp(),updatedAt:serverTimestamp()};
 await assertSucceeds(setDoc(car,vehicle()));await assertSucceeds(setDoc(target,record));
 await assertSucceeds(updateDoc(target,{'parts.hood':'replaced',updatedAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(target,{reportId:'report1',reportName:'rapor.pdf',updatedAt:serverTimestamp()}));
 for(const change of [{'parts.hood':'wrong'},{parts:{hood:'original'}},{reportId:'../other'},{notes:'x'.repeat(2001)}]) await assertFails(updateDoc(target,{...change,updatedAt:serverTimestamp()}));
 for(const other of [env.authenticatedContext('bob').firestore(),env.unauthenticatedContext().firestore()]) {
 const foreign=doc(other,'users/alice/vehicles/expertise-car/expertise/current');await assertFails(getDoc(foreign));await assertFails(setDoc(foreign,record));
 }
 await assertSucceeds(updateDoc(car,{archived:true,updatedAt:serverTimestamp()}));await assertFails(updateDoc(target,{notes:'edit',updatedAt:serverTimestamp()}));
});
