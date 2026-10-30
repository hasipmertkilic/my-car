const {test,before,after}=require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {ref,uploadBytes,getBytes,deleteObject}=require('firebase/storage');
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-mycar',firestore:{host:'127.0.0.1',port:8085,rules:fs.readFileSync('firestore.rules','utf8')},storage:{host:'127.0.0.1',port:9199,rules:fs.readFileSync('storage.rules','utf8')}});});
after(async()=>{await env?.cleanup();});
test('PDF sahibi erişir; başka hesap, yanlış tür ve büyük dosya reddedilir',async()=>{
 await env.withSecurityRulesDisabled(async ctx=>{const {doc,setDoc}=require('firebase/firestore');await setDoc(doc(ctx.firestore(),'users/alice/vehicles/car'),{archived:false});});
 const owner=env.authenticatedContext('alice').storage();
 const path='users/alice/vehicles/car/expertise/report1.pdf';
 const target=ref(owner,path);
 await assertSucceeds(uploadBytes(target,Buffer.from('%PDF-1.7\n'),{contentType:'application/pdf'}));
 await assertSucceeds(getBytes(target));
 await assertFails(uploadBytes(target,Buffer.from('%PDF-1.7\n'),{contentType:'application/pdf'}));
 for(const storage of [env.authenticatedContext('bob').storage(),env.unauthenticatedContext().storage()]){await assertFails(getBytes(ref(storage,path)));await assertFails(deleteObject(ref(storage,path)));await assertFails(uploadBytes(ref(storage,'users/alice/vehicles/car/expertise/other.pdf'),Buffer.from('%PDF-'),{contentType:'application/pdf'}));}
 await assertFails(uploadBytes(ref(owner,'users/alice/vehicles/car/expertise/photo.pdf'),Buffer.from('image'),{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(owner,'users/alice/vehicles/car/expertise/big.pdf'),Buffer.alloc(10*1024*1024+1),{contentType:'application/pdf'}));
 await assertFails(uploadBytes(ref(owner,'users/alice/vehicles/missing/expertise/file.pdf'),Buffer.from('%PDF-'),{contentType:'application/pdf'}));
 await assertSucceeds(deleteObject(target));
});
