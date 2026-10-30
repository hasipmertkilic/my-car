# Firestore araç yönetimi

Araçlar `users/{uid}/vehicles/{vehicleId}` altında saklanır. Aktif araç tercihi `users/{uid}.activeVehicleId` alanıdır. Marka, model, yıl, plaka, yakıt/vites tipi, motor hacmi ve kilometre kaydedilir. Fotoğraf yükleme henüz eklenmedi.

Ekranlar Firestore akışlarını dinler. Giriş/hesap değişiminde UID'ye bağlı repository ve akışlar değişir; kullanıcı kendi listesini görür. İlk araç oluşturulması ve aktif seçim transaction içinde birlikte yazılır. Düzenleme oluşturulma tarihini korur; hata olursa form kapanmaz. Açık düzenleme formunda araç başka cihazdan kaldırılmışsa kayıt reddedilir.

Kaldırma kalıcı silme değildir: `archived: true` yapılır. Aktif tercih o araçsa temizlenir; başka araç varsa listede ilk araç gösterilir. İşlemden sonraki 10 saniye boyunca Geri al düğmesi kullanılabilir. Arşivleme gelecekteki alt koleksiyonları ve belge geçmişini korur. Kalıcı silme erişimi güvenlik kurallarında kapalıdır.

Mevcut Firestore kuralları tüm erişimi reddediyordu; `docs/firestore-before.rules` içinde yedeği bulunur. Yeni kurallar yalnızca kullanıcının kendi profilindeki aktif araç alanına ve kendi araçlarına erişim açar. Bilinmeyen alanlar, geçersiz kilometre/yıl/motor hacmi ve değiştirilmiş oluşturulma tarihi reddedilir. Diğer koleksiyonlar kapalıdır.

12 Ekim 2026: kurallar emülatördeki 5 güvenlik testi geçtikten sonra `mycar-f0673` projesine başarıyla uygulandı. 11 Flutter testi ve kod denetimi geçti.

Örnek araçlar ve örnek yakıt/masraf/bakım değerleri kaldırıldı. Yakıt, bakım ve masraf modülleri henüz yapılmadığından kayıt ve istatistik ekranları gerçek araca ait boş durum gösterir. Mevcut başka veri yapıları bu sürüme otomatik taşınmaz.

## Kontroller

```sh
flutter analyze
flutter test
npm ci --prefix tool
firebase emulators:exec --only firestore --project demo-mycar --config firebase.emulator.json "node --test tool/firestore_rules.test.cjs"
flutter build web
```

Emülatör `demo-mycar` üzerinde çalışır; üretim hesabı oluşturmaz ve üretim verisi değiştirmez. Kurallar için sahip erişimi, başka hesap/girişsiz erişim reddi, alan doğrulaması, atomik ilk seçim ve arşiv/geri alma senaryoları test edilir. Arayüz testleri kontrollü repository ile ekleme, düzenleme, seçme, kaldırma onayı, geri alma ve hata durumlarını doğrular.

## Kaynaklar

- [Firestore transaction işlemleri](https://firebase.google.com/docs/firestore/manage-data/transactions)
- [Firestore erişim koşulları](https://firebase.google.com/docs/firestore/security/rules-conditions)
- [Belge ve alt koleksiyon silme davranışı](https://firebase.google.com/docs/firestore/manage-data/delete-data)
