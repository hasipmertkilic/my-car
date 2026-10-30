const {test} = require('node:test');
const assert = require('node:assert/strict');
const {validatePoint, searchStations} = require('./stations');
test('rejects missing, non-numeric and out-of-range coordinates', () => {
  for (const value of [null, {}, {latitude: '41', longitude: 29},
    {latitude: 91, longitude: 29}, {latitude: 41, longitude: Infinity}]) {
    assert.throws(() => validatePoint(value));
  }
  assert.deepEqual(validatePoint({latitude: 41, longitude: 29}), {latitude: 41, longitude: 29});
});
test('requests gas stations within 5 km and removes invalid/closed results', async () => {
  const stations = await searchStations({latitude: 41, longitude: 29}, 'test-key', async (url, options) => {
    assert.equal(url, 'https://places.googleapis.com/v1/places:searchNearby');
    const query = JSON.parse(options.body);
    assert.equal(query.locationRestriction.circle.radius, 5000);
    assert.equal(query.rankPreference, 'DISTANCE');
    assert.deepEqual(query.includedTypes, ['gas_station']);
    assert.equal(query.maxResultCount, 20);
    return {ok: true, json: async () => ({places: [
      {id: 'open', displayName: {text: 'İstasyon'}, location: {latitude: 41, longitude: 29}},
      {id: 'closed', businessStatus: 'CLOSED_PERMANENTLY', displayName: {text: 'Kapalı'}, location: {latitude: 41, longitude: 29}},
      {id: 'broken', displayName: {text: 'Eksik'}},
    ]})};
  });
  assert.equal(stations.length, 1);
  assert.equal(stations[0].name, 'İstasyon');
});
test('empty results are valid and upstream errors are not exposed', async () => {
  assert.deepEqual(await searchStations({}, '', async () => ({ok: true, json: async () => ({})})), []);
  await assert.rejects(searchStations({}, '', async () => ({ok: false})), /places-unavailable/);
});
