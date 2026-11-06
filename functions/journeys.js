function waypoint(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('invalid-waypoint');
  if (typeof value.address === 'string' && Object.keys(value).length === 1) {
    const address = value.address.trim().replace(/\s+/g, ' ');
    if (address.length < 3 || address.length > 200) throw new Error('invalid-address');
    return {address};
  }
  if (Object.keys(value).sort().join(',') !== 'latitude,longitude' ||
      typeof value.latitude !== 'number' || !Number.isFinite(value.latitude) || Math.abs(value.latitude) > 90 ||
      typeof value.longitude !== 'number' || !Number.isFinite(value.longitude) || Math.abs(value.longitude) > 180) throw new Error('invalid-point');
  return {location: {latLng: {latitude: value.latitude, longitude: value.longitude}}};
}
function validateJourney(data) {
  if (!data || Object.keys(data).some(k => !['origin', 'destination', 'avoidTolls'].includes(k)) || typeof data.avoidTolls !== 'boolean') throw new Error('invalid-request');
  return {origin: waypoint(data.origin), destination: waypoint(data.destination), avoidTolls: data.avoidTolls};
}
class RouteProviderError extends Error {
  constructor(code) { super(code); this.code = code; }
}
async function computeJourney(input, key, fetcher = fetch) {
  const response = await fetcher('https://routes.googleapis.com/directions/v2:computeRoutes', {
    method: 'POST',
    headers: {'Content-Type': 'application/json', 'X-Goog-Api-Key': key,
      'X-Goog-FieldMask': 'routes.description,routes.routeLabels,routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline,routes.legs.startLocation,routes.legs.endLocation'},
    body: JSON.stringify({origin: input.origin, destination: input.destination, travelMode: 'DRIVE', routingPreference: 'TRAFFIC_UNAWARE',
      computeAlternativeRoutes: true, routeModifiers: {avoidTolls: input.avoidTolls}, languageCode: 'tr-TR', regionCode: 'TR', units: 'METRIC', polylineQuality: 'OVERVIEW'}),
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) throw new RouteProviderError(response.status === 403 ? 'NOT_READY' : response.status === 429 ? 'LIMIT' : 'UNAVAILABLE');
  const data = await response.json();
  return (Array.isArray(data.routes) ? data.routes : []).slice(0, 3).flatMap((route, index) => {
    const meters = route.distanceMeters;
    const duration = typeof route.duration === 'string' && /^\d+(?:\.\d+)?s$/.test(route.duration) ? Number(route.duration.slice(0, -1)) : NaN;
    const polyline = route.polyline?.encodedPolyline;
    const start = route.legs?.[0]?.startLocation?.latLng;
    const end = route.legs?.at(-1)?.endLocation?.latLng;
    const point = p => p && Number.isFinite(p.latitude) && Math.abs(p.latitude) <= 90 && Number.isFinite(p.longitude) && Math.abs(p.longitude) <= 180;
    if (!Number.isFinite(meters) || meters <= 0 || meters > 50000000 || !Number.isFinite(duration) || duration < 0 || duration > 31536000 ||
        typeof polyline !== 'string' || !polyline.length || polyline.length > 200000 || !point(start) || !point(end)) return [];
    return [{id: `route-${index}`, name: typeof route.description === 'string' && route.description ? route.description.slice(0, 180) : (index === 0 ? 'Önerilen rota' : `Alternatif ${index}`),
      recommended: Array.isArray(route.routeLabels) ? route.routeLabels.includes('DEFAULT_ROUTE') : index === 0,
      distanceMeters: meters, durationSeconds: Math.round(duration), polyline,
      start: {latitude: start.latitude, longitude: start.longitude}, end: {latitude: end.latitude, longitude: end.longitude},
      tollStatus: 'unknown'}];
  });
}
module.exports = {waypoint, validateJourney, computeJourney, RouteProviderError};
