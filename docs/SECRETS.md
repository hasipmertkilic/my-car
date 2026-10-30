# Yerel anahtarlar ve GitHub

Firebase istemci anahtarları artık Dart kaynak kodunda tutulmaz; `config/firebase.local.json` içindeki `FIREBASE_WEB_API_KEY`, `FIREBASE_ANDROID_API_KEY`, `FIREBASE_IOS_API_KEY` alanlarından derleme sırasında alınır. Yerel gerçek değerler korunmuştur ve Git tarafından dışlanır. Yeni bilgisayarda `config/firebase.example.json` dosyasını `config/firebase.local.json` olarak kopyalayıp Firebase Console'daki platform anahtarlarını doldur.

Android için Firebase Console → Proje ayarları → Android uygulaması üzerinden `google-services.json` indir; `android/app/google-services.json` konumuna koy. Bu dosya Git'e eklenmez. iOS kullanılırsa `ios/Runner/GoogleService-Info.plist` de dışlanır.

Maps yapılandırması `config/google_maps.local.json` üzerinden gelir. Örneği `config/google_maps.example.json` dosyasıdır. Web için türetilen `web/google_maps_config.js` de Git dışında kalır.

## Derleme

```powershell
flutter pub get
powershell -ExecutionPolicy Bypass -File tool/build_local.ps1 -Target apk
powershell -ExecutionPolicy Bypass -File tool/build_local.ps1 -Target web
```

Doğrudan çalıştırmak için: `flutter run --dart-define-from-file=config/firebase.local.json`. Web öncesi `node tool/prepare_google_maps.cjs` gerekir. CI ortamında bu yerel dosyaları depo/ortam sırlarından oluştur; build çıktıları anahtarları içerebildiği için kaynak deposuna ekleme.

## Gerçek erişim güvenliği

Firebase istemci anahtarları sır değildir ve derlenmiş uygulamadan okunabilir. Veriye erişimi Authentication, Firestore/Storage Rules ve gerekli servislerde App Check belirler. Sunucu Places anahtarı Cloud Functions Secret Manager'da `PLACES_API_KEY` olarak kalır, istemciye gönderilmez.

Google Maps için ayrı Android/web anahtarları kullan: Android anahtarına `com.mertkilic.mycar` paket adı ve kullanılan debug/release imza SHA-1 kısıtları, web anahtarına yalnızca izin verilen alan adı/referrer kısıtları uygula. API kısıtında yalnızca o istemcinin kullandığı Maps API'lerini aç. Aynı anahtara Android ve web uygulama kısıtları birlikte uygulanamaz; ayrı anahtar gerekir. Projenin mevcut Cloud kısıtları bu değişiklikle değiştirilmemiştir.

GitHub'a gönderilmiş eski commit'lerdeki yapılandırma, yeni commit ile silinmez. Geçmiş temizliği ve uzaktaki commit'lerin zorla güncellenmesi ayrı bir işlemdir. Paylaşılan gerçek sunucu sırları veya kısıtsız ücretli API anahtarları varsa yenilenmeli; geçmiş temizliği, kopyalanmış bir anahtarı geçersiz kılmaz. Firebase istemci anahtarını körlemesine silmek mevcut uygulamaların girişini bozabilir.

Kontrol: `node tool/check_secrets.cjs`. Anahtar değerleri ekrana yazılmaz; yalnızca dosya ve satır bildirilir. Taramada Git'e eklenecek dosyalar kontrol edilir; tüm Git geçmişi veya bulut ayarları denetlenmez.

Kaynaklar: https://firebase.google.com/docs/projects/api-keys ve https://developers.google.com/maps/api-security-best-practices
