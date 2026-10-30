function validatePoint(data) {
  const {latitude, longitude} = data || {};
  if (typeof latitude !== 'number' || !Number.isFinite(latitude) || Math.abs(latitude) > 90 ||
      typeof longitude !== 'number' || !Number.isFinite(longitude) || Math.abs(longitude) > 180) {
    throw new Error('invalid-point');
  }
  return {latitude, longitude};
}

async function searchStations(point, key, fetcher = fetch) {
  const response = await fetcher('https://places.googleapis.com/v1/places:searchNearby', {
    method: 'POST',
    headers: {'Content-Type': 'application/json', 'X-Goog-Api-Key': key,
      'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.businessStatus'},
    body: JSON.stringify({includedTypes: ['gas_station'], maxResultCount: 20,
      rankPreference: 'DISTANCE', languageCode: 'tr',
      locationRestriction: {circle: {center: point, radius: 5000}}}),
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error('places-unavailable');
  const body = await response.json();
  return (body.places || []).filter(p => p.businessStatus !== 'CLOSED_PERMANENTLY' &&
    typeof p.id === 'string' && p.displayName?.text &&
    Number.isFinite(p.location?.latitude) && Number.isFinite(p.location?.longitude))
    .map(p => ({id: p.id, name: p.displayName.text, address: p.formattedAddress || '',
      latitude: p.location.latitude, longitude: p.location.longitude}));
}
module.exports = {validatePoint, searchStations};
