const {test}=require('node:test');const assert=require('node:assert/strict');
const {waypoint,validateJourney,computeJourney}=require('./journeys');
test('addresses and coordinates are bounded; client cannot request paid features',()=>{
 assert.deepEqual(waypoint({address:' Ankara  Çankaya '}),{address:'Ankara Çankaya'});
 for(const point of [{latitude:91,longitude:2},{latitude:'41',longitude:2},{address:'x'},{address:'Ankara',latitude:41},{latitude:NaN,longitude:2}])assert.throws(()=>waypoint(point));
 assert.throws(()=>validateJourney({origin:{address:'Ankara'},destination:{address:'İzmir'},avoidTolls:false,extraComputations:['TOLLS']}));
});
test('uses Essentials route request only, alternatives and unknown tolls',async()=>{
 const input=validateJourney({origin:{latitude:41,longitude:29},destination:{address:'Ankara'},avoidTolls:true});
 const routes=await computeJourney(input,'fake',async(url,options)=>{
  assert.equal(url,'https://routes.googleapis.com/directions/v2:computeRoutes');const request=JSON.parse(options.body);
  assert.equal(request.computeAlternativeRoutes,true);assert.equal(request.routingPreference,'TRAFFIC_UNAWARE');assert.equal(request.routeModifiers.avoidTolls,true);assert.equal(request.extraComputations,undefined);assert.ok(!options.headers['X-Goog-FieldMask'].includes('tollInfo'));
  return {ok:true,json:async()=>({routes:[{description:'O-4',distanceMeters:450000,duration:'18000s',polyline:{encodedPolyline:'abc'},routeLabels:['DEFAULT_ROUTE'],legs:[{startLocation:{latLng:{latitude:41,longitude:29}},endLocation:{latLng:{latitude:40,longitude:33}}}]}]})};
 });
 assert.equal(routes[0].distanceMeters,450000);assert.equal(routes[0].tollStatus,'unknown');assert.equal(routes[0].recommended,true);
});
test('empty and invalid provider results do not invent routes or fees',async()=>{
 assert.deepEqual(await computeJourney({},'',async()=>({ok:true,json:async()=>({routes:[{distanceMeters:-1}]})})),[]);
 await assert.rejects(computeJourney({},'',async()=>({ok:false,status:403})),/NOT_READY/);
});
