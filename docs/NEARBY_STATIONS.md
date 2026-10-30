# Yakındaki yakıt istasyonları

Uygulama Google Maps üzerinde kullanıcının arama anındaki konumunu ve 5 km içindeki en yakın 20 yakıt istasyonunu gösterir. Liste mesafeleri kuş uçuşudur. Yol tarifi Google Maps uygulamasında veya tarayıcıda, o anki kullanıcı konumundan başlar. Fiyat ve açık/kapalı saat bilgileri sunulmaz.

## Google ve Firebase kurulumu

1. Google Cloud projesinde **Places API (New)** servisini etkinleştir ve faturalandırmayı doğrula.
2. Ayrı bir **sunucu API anahtarı** oluştur. API kısıtlamasını yalnızca **Places API (New)** olarak ayarla. Android paket veya web site kısıtlaması bu sunucu anahtarına uygulanmaz. Statik sunucu çıkış IP'si yapılandırıldığında IP kısıtlaması da eklenebilir. Bu anahtarı APK, web dosyası veya kaynak koda ekleme. Mevcut Maps SDK ve JavaScript anahtarları ayrı kalır.
3. Firebase projesi `mycar-f0673` için Blaze planını doğrula. Functions/Secret Manager ve Places kullanım ücreti doğabilir. Places kota sınırlarını ve bütçe bildirimlerini Google Cloud'da ayarla; bütçe bildirimi harcamayı otomatik durdurmaz.
4. Proje klasöründe terminalden:

   ```powershell
   npx --yes firebase-tools login
   npm --prefix functions ci
   npx --yes firebase-tools functions:secrets:set PLACES_API_KEY --project mycar-f0673
   npx --yes firebase-tools deploy --only functions:nearbyStations --project mycar-f0673
   ```

   Secret komutu sorduğunda anahtarı terminale gir. Anahtarı sohbet veya komut satırı argümanı olarak paylaşma.

5. Uygulamada giriş yap → yan menü → **Yakındaki istasyonlar** → **Konumumdan istasyon bul**. Web'de localhost veya HTTPS konum izni gerekir. Android'de konum servisi ve uygulama izni açık olmalı.

Harita anahtarı ile Places sunucu anahtarı farklı Google Cloud projelerinde olabilir; faturalandırma ve servis etkinleştirme Places anahtarının ait olduğu projede yapılır. Function `us-central1` bölgesinde Firebase projesine yayınlanır. Başka bir projeye yayınlanacaksa `STATIONS_ENDPOINT` derleme tanımıyla endpoint güncellenir.

## Güvenlik ve davranış

- Firebase callable sunucu tarafında kimliği doğrulanmış kullanıcı ister. Oturumsuz istek Google'a gönderilmez.
- Kullanıcı başına 30 saniyede bir, UTC gününde en fazla 50 arama. Transaction ile eş zamanlı isteklerde de uygulanır. Arıza durumundaki girişimler de sayılır.
- `_stationSearchLimits` koleksiyonunda sadece zaman/gün/sayaç tutulur. Mevcut Firestore kuralları bu koleksiyona istemci erişimi vermez. Konumlar ve Google Places yanıtları veritabanına yazılmaz.
- Sunucu anahtarı Secret Manager'dadır. App Check henüz uygulamaya entegre olmadığı için enforced değildir; anonim hesap açma ve kötüye kullanım için ek üretim koruması olarak ayrıca yapılandırılmalıdır.
- Kullanıcı konum butonuna basmadan konum izni istenmez ve Places çağrılmaz. Otomatik yenileme yoktur.
- Kalıcı kapalı işletmeler ve koordinatı eksik sonuçlar listelenmez. Google veri kapsamı ve sonuç sınırı nedeniyle tüm istasyonların bulunacağı garanti edilmez.
- Canlı sonuçlar için servis yayını ve geçerli secret gerekir. Yerel testler sahte servisle yapılır; canlı Google isteği yapmaz.

## Kontrol

```powershell
node --test functions/stations.test.js
flutter test test/stations_test.dart test/widget_test.dart --no-pub
```

Resmî kaynaklar: [Nearby Search (New)](https://developers.google.com/maps/documentation/places/web-service/nearby-search), [Firebase secrets](https://firebase.google.com/docs/functions/config-env), [Google Maps URL](https://developers.google.com/maps/documentation/urls/get-started).
