const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {defineSecret}=require('firebase-functions/params');
const {getFirestore}=require('firebase-admin/firestore');
const {validateJourney,computeJourney,RouteProviderError}=require('./journeys');
const routesKey=defineSecret('ROUTES_API_KEY');
exports.planRoutes=onCall({region:'us-central1',secrets:[routesKey],timeoutSeconds:30,maxInstances:3,cors:true,invoker:'public'},async request=>{
 if(!request.auth)throw new HttpsError('unauthenticated','Giriş yapmalısın.');
 let input;try{input=validateJourney(request.data);}catch(_){throw new HttpsError('invalid-argument','Başlangıç ve varış bilgilerini kontrol et.');}
 const counter=getFirestore().collection('_journeySearchLimits').doc(request.auth.uid);
 const now=Date.now();
 await getFirestore().runTransaction(async tx=>{
  const snapshot=await tx.get(counter);const previous=snapshot.data()||{};const day=new Date(now).toISOString().slice(0,10);
  const count=previous.day===day?previous.count||0:0;
  if(now-(previous.last||0)<10000||count>=50)throw new HttpsError('resource-exhausted','Biraz bekleyip tekrar dene.');
  tx.set(counter,{last:now,day,count:count+1});
 });
 try{return {routes:await computeJourney(input,routesKey.value())};}
 catch(error){
  if(error instanceof RouteProviderError && error.code==='NOT_READY')throw new HttpsError('failed-precondition','Rota hizmeti henüz etkin değil.');
  if(error instanceof RouteProviderError && error.code==='LIMIT')throw new HttpsError('resource-exhausted','Rota arama sınırına ulaşıldı.');
  throw new HttpsError('unavailable','Rota şu anda hesaplanamıyor.');
 }
});
