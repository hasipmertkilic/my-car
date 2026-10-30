# My Car teknik mimarisi ve geliştirme planı

## 1. Teknoloji ve genel mimari

Flutter ve Dart kullanılacak. Gereksinimler Flutter istediği için React Native yerine bu yol seçildi. İlk hedef Android. Arayüz Türkçe, para birimi başlangıçta TRY olacak. Açık ve koyu tema Material 3 üzerinden yönetilecek.

Firebase Authentication e-posta/parola ile kimlik doğrulama; Cloud Firestore kullanıcı ve araç kayıtları; Firebase Storage fotoğraf ve belge dosyaları için kullanılacak. Tarih hatırlatmaları önce yerel bildirimlerle yapılacak. FCM ancak sunucudan bildirim gereksinimi oluşursa eklenecek; tek başına FCM gelecekteki bildirimleri zamanlamaz.

Her özellik kendi model, repository, controller ve ekranlarına sahip olacak:

Ekran → Riverpod controller/provider → repository → Firebase servisi.

Ekranlar doğrudan Firestore sorgusu çalıştırmayacak. Repository arayüzleri sayesinde ilk çalışan sürüm örnek verilerle açılabilecek; Firebase bağlantısı sonraki aşamada aynı arayüz üzerinden kurulacak. Örnek veri modu açıkça gösterilecek ve gerçek kullanıcı verileriyle karıştırılmayacak.

Başlangıç seviyesinde anlaşılabilirlik için gereksiz katmanlar ve kod üretimi eklenmeyecek. Hesaplamalar arayüzden bağımsız Dart fonksiyonlarında tutulacak.

## 2. Planlanan klasör yapısı

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme.dart
  core/
    constants/
    utils/                 # Tarih, para, doğrulama
    services/              # Firebase, dosya, konum, bildirim
    widgets/               # Ortak kartlar, boş/hata/yükleniyor durumları
  features/
    auth/
    vehicles/
    dashboard/
    fuel/
    mileage/
    maintenance/
    inspection/
    insurance/
    expenses/
    documents/
    parking/
    statistics/
    settings/
      # Her özellikte ihtiyaca göre:
      # models/, repositories/, controllers/, screens/, widgets/
test/
  calculations/
  repositories/
  features/
docs/
  PROJE_PLANI.md
firestore.rules
firestore.indexes.json
storage.rules
```

Android/iOS platform klasörleri Flutter projesi oluşturulurken eklenecek. Firebase seçenekleri gerçek Firebase projesi bağlanınca FlutterFire CLI ile üretilecek.

## 3. Kullanılacak paketler

Paketler ilgili aşamada eklenecek; sürümleri kurulu Flutter SDK ile uyumlu olacak şekilde çözümlenip uygulamanın pubspec.lock dosyasıyla sabitlenecek.

| Paket | Amaç |
| --- | --- |
| flutter_riverpod | Durum yönetimi ve repository bağımlılıkları |
| go_router | Ekran geçişleri ve giriş kontrolü |
| firebase_core | Firebase başlangıcı |
| firebase_auth | Kayıt, giriş, parola sıfırlama |
| cloud_firestore | Araç ve işlem kayıtları |
| firebase_storage | Fotoğraf ve belge saklama |
| intl | Türkçe tarih, sayı ve para biçimleri |
| fl_chart | Yakıt, kilometre ve masraf grafikleri |
| image_picker | Araç fotoğrafı seçme |
| file_picker | Belge seçme |
| geolocator | Park konumu alma |
| flutter_map, latlong2 | Harita ve koordinatlar |
| url_launcher | Harici haritada yol tarifi ve belge açma |
| flutter_local_notifications, timezone, flutter_timezone | Cihaz saat dilimine uygun tarih bildirimleri |
| shared_preferences | Tema ve cihaz tercihleri |

Harita için başlangıç tercihi flutter_map. Harita karo sağlayıcısı, kullanım koşulları ve atıf metni park aşamasında seçilecek; üretimde sınırsız ücretsiz harita hizmeti varsayılmayacak.

## 4. Firestore veri modeli

Tüm araçlar kullanıcı altında tutulacak:

```text
users/{uid}
  vehicles/{vehicleId}
    fuelRecords/{recordId}
    maintenanceRecords/{recordId}
    inspectionRecords/{recordId}
    insurancePolicies/{policyId}
    expenseRecords/{recordId}
    mileageEntries/{entryId}
    documents/{documentId}
    parking/current
```

| Belge | Alanlar |
| --- | --- |
| users | displayName, email, activeVehicleId, notificationsEnabled, createdAt |
| vehicles | brand, model, year, plate, fuelType, transmission, engineCc, currentKm, photoPath, createdAt, updatedAt |
| fuelRecords | date, odometerKm, liters, totalAmountKurus, fuelType, fullTank, notes |
| maintenanceRecords | date, odometerKm, type, operations, replacedParts, serviceName, amountKurus, notes, nextDueDate, nextDueKm |
| inspectionRecords | date, odometerKm, nextDueDate, amountKurus, notes |
| insurancePolicies | type (traffic/casco), startDate, endDate, company, policyNumber, amountKurus, notes |
| expenseRecords | date, odometerKm (isteğe bağlı), category, amountKurus, description |
| mileageEntries | date, odometerKm, sourceType, sourceId |
| documents | name, type, storagePath, mimeType, sizeBytes, relatedRecordId, relatedRecordType, uploadedAt |
| parking/current | latitude, longitude, parkedAt, floor, section, spotNumber |

Tüm işlem kayıtlarında createdAt ve updatedAt bulunacak. Tarihler Firestore Timestamp, para tutarları yuvarlama hatalarını azaltmak için tam sayı kuruş olarak tutulacak. Litre fiyatı toplam ücret/litre üzerinden hesaplanacak. Dosyalar Firestore belgelerine gömülmeyecek; Storage yolu tutulacak.

Storage yolları: users/{uid}/vehicles/{vehicleId}/photos/... ve documents/...

Yakıt, bakım, muayene ve poliçe tutarları kendi kayıtlarından masraf özetine dahil edilecek. expenseRecords yalnızca bağımsız masrafları tutacak. Böylece aynı yakıt veya bakım iki kez sayılmayacak. Masraf listesindeki kaynaklı bir işlem düzenlendiğinde ilgili kaynak formu açılacak.

Araç güncel kilometresi, başlangıç kilometresi ve geçerli kilometre geçmişinin maksimumundan türetilecek. Geçmiş kayıt eklemeye izin verilecek; tarih sırasındaki kilometre düşüşleri doğrulama hatası olarak gösterilecek. Kaynak işlem ve kilometre girdisi birlikte yazılacak/düzenlenecek/silinecek. Geriye dönük düzenlemelerde güncel kilometre yeniden hesaplanacak.

Güvenlik kuralları yalnızca request.auth.uid == uid olan kullanıcının erişimine izin verecek; alan türleri, pozitif tutarlar ve dosya boyutu/türü doğrulanacak. Araç silmede alt koleksiyonlar ve Storage dosyaları da temizlenecek; yalnızca araç belgesini silmek yeterli kabul edilmeyecek. Silme onayı ve güvenilir toplu temizleme akışı bu aşamada uygulanacak.

Tarih sıralama ve kategori+tarih sorguları için gereken indeksler sürüm kontrolüne eklenecek. Hesaplamalar ilk sürümde aktif aracın kayıtlarından yapılacak; veri büyürse aylık özetler eklenecek.

## 5. Ekranlar ve bağlantılar

```text
Başlangıç → Oturum kontrolü
  → Giriş ↔ Kayıt / Parola sıfırlama
  → Araç yoksa İlk araç ekleme
  → Ana uygulama
      Özet | Kayıtlar | İstatistikler | Garaj
```

- Özet: aktif araç, kilometre, son yakıt/bakım, tüketim, aylık masraf, yaklaşan işlemler. Hızlı eylemler ilgili kayıt formuna gider.
- Kayıtlar: yakıt, bakım, muayene, sigorta/kasko ve masraf listeleri. Her liste → detay → düzenleme; ekle düğmesi → form.
- İstatistikler: dönem seçimi, yakıt tüketimi, gider dağılımı, kilometre geçmişi ve maliyet göstergeleri.
- Garaj: araç listesi, aktif araç seçimi, araç ekleme/düzenleme/silme. Araç detayı → belgeler ve park konumu.
- Ayarlar: tema, bildirim tercihleri, hesap ve çıkış. Özet veya Garaj üzerinden erişilir.
- Park: Aracımı park ettim → konum izni → konum ve park notu kaydı; Arabam nerede → harita → harici yol tarifi.

Aktif araç değiştiğinde tüm listeler ve istatistikler o araca geçecek. Giriş yapılmadığında özel ekranlara gidilemeyecek. Boş veri, bağlantı hatası ve izin reddi her ekranda anlaşılır Türkçe mesajlarla ele alınacak.

## 6. Hesaplama kuralları

- İki dolu depo arasında litre / mesafe × 100 tüketimi verir. Kısmi dolumlar aradaki litre toplamına dahil edilir. İlk kayıt başlangıç noktasıdır; tek kayıttan tüketim çıkarılmaz. Kullanıcının örneği 42,3 / 540 × 100 = 7,83 L/100 km.
- Ortalama tüketim tekil oranların basit ortalaması yerine geçerli aralıklardaki toplam litre / toplam mesafe üzerinden hesaplanır. km/L bunun tersidir; 100 km maliyeti aynı aralıkların yakıt gideri / mesafe × 100 olur.
- Toplam litre ve yakıt masrafı tüm kayıtları içerir; tüketim istatistiği yalnızca hesaplanabilir dolu depo aralıklarını kullanır. Sıfır mesafede bölme yapılmaz; yetersiz veride değer yerine açıklama gösterilir.
- Aylık/yıllık giderler işlem tarihine göre yakıt, bakım, muayene, poliçe ve bağımsız masrafların toplamıdır. Poliçe bedeli başlangıç tarihine yazılır; aylara dağıtılmaz.
- Kilometre başına maliyet seçili dönemin gideri / aynı dönemde ölçülebilen kilometredir. Sınır verisi yoksa yalnızca gözlenen aralık gösterilir; tam yıl kilometresi tahmin edilmez.
- Aylık ortalama gider gözlenen dönem içindeki takvim aylarına bölünür; sıfır giderli aylar dahildir. Kullanılan dönem ekranda gösterilir.
- Bakımın tarih ve kilometre eşiği birlikte verilirse önce gelen eşik dikkate alınır. Geçmiş tarihler “gecikti”, yakın tarihler “yaklaşıyor” olarak gösterilir.
- Tarih bildirimleri başlangıçta 30, 15 ve 7 gün öncesine planlanır. Kilometre hatırlatması yeni kilometre kaydında değerlendirilir; uygulama arka planda aracın kilometresini kendiliğinden bilemez.
- Bildirim kapatılınca zamanlanmış bildirimler iptal edilir; kayıt düzenlenince yeniden planlanır. Uygulama içi yaklaşan işlemler listesi bildirim izni olmasa da çalışır.

## 7. Geliştirme aşamaları ve tamamlanma ölçütleri

| Aşama | Yapılacak iş ve amacı | Tamamlanma ölçütü |
| --- | --- | --- |
| 0 — Plan (tamamlandı) | Teknoloji, veri modeli ve geliştirme sırasını belirlemek | Bu doküman ve README |
| 1 — Flutter temeli (kod tamamlandı) | Proje, modüler klasörler, Türkçe tema, yönlendirme ve açıkça işaretli örnek veri modu | Analyze ve üç widget testi geçti; web derlendi. Android cihaz doğrulaması lisanslar ve cihaz hazır olduğunda yapılacak |
| 2 — Firebase ve hesap (Authentication tamamlandı) | MyCar Firebase bağlantısı, giriş/kayıt/çıkış ve parola sıfırlama eklendi. Firestore/Storage kuralları araç verisi aşamasında uygulanacak | Analyze temiz; 5 hesap testi geçti, web arayüzü kontrol edildi. Gerçek hesap/e-posta teslimi ve cihaz testi ayrıca yapılacak; veri sahipliği kuralları henüz kapsamda değil |
| 3 — Araç yönetimi (tamamlandı, fotoğraf hariç) | Çoklu araç CRUD ve aktif araç seçimi | Araç verisi yeniden açılışta korunur; aktif araç ekranlara yansır |
| 4 — Yakıt ve kilometre (tamamlandı) | Kayıt formları, geçmiş ve tüketim hesapları | Dolu/kısmi depo, ilk kayıt, geçmiş düzenleme ve sıfır mesafe testleri geçer |
| 5 — Bakım ve yükümlülükler | Bakım, muayene, sigorta/kasko, yaklaşan işlemler | Tarih/km eşikleri ve gecikmeler doğru görünür |
| 6 — Masraf ve istatistik | Kategoriler, dönem filtreleri, grafikler ve özet ekranını gerçek veriye bağlama | Aynı işlem iki kez sayılmaz; dönem hesapları testlerle doğrulanır |
| 7 — Fotoğraf ve belgeler | Dosya seçimi, Storage yükleme, görüntüleme ve silme | Dosyalar yalnızca sahibine açıktır; hata ve yükleme durumları çalışır |
| 8 — Park | GPS, park notları, harita ve yol tarifi | İzin reddi ve konum yokluğu yönetilir; kaydedilen konum tekrar açılır |
| 9 — Hatırlatmalar | Bildirim izinleri, tarih planları, kilometre uyarıları | Düzenleme/silme/çıkış sonrası eski bildirim kalmaz; cihazda doğrulanır |
| 10 — Teslim | Entegrasyon kontrolleri, erişilebilirlik, hata düzeltme, APK ve proje raporu | Gerçek Android cihazda temel uçtan uca senaryolar geçer |

Her aşamanın başında ne yapıldığı ve nedeni açıklanacak; ardından yalnızca o aşamanın kodları oluşturulacak. Hesaplama ve güvenlik testleri önceliklidir. Son teslimde örnek veri modu ve gerçek Firebase modu ayrı ayrı belgelenir.

## 8. Ortam ve sonraki adım

Flutter 3.44.6 ve Dart 3.12.2 doğrulandı. Android SDK mevcut; bazı lisanslar kabul edilmemiş ve bağlı Android cihaz yok. Flutter temeli, dört ana ekran ve tema seçimi oluşturuldu. Analyze temiz; gezinme/araç seçimi, tema/geri dönüş ve dar ekran/büyük metin testleri geçti. Web derlemesi başarılı. Android ve iOS çalışması henüz doğrulanmadı. Firebase Authentication mevcut MyCar projesine bağlandı; giriş, kayıt, parola sıfırlama ve çıkış tamamlandı. Firestore araç yönetimi ve sahiplik kuralları eklendi. Sonraki aşama yakıt ve kilometre takibidir. Araç kaldırma bu sürümde arşivleme olarak uygulanır; fotoğraf yükleme dosya aşamasındadır.

Firebase aşamasında kullanıcının Firebase projesi ve platform uygulama kimliği gerekecek. Gizli servis hesabı anahtarı mobil uygulamaya eklenmeyecek. Bulut kaynaklarının etkinleştirilmesi ve olası ücretler o aşamada gerçek proje üzerinden değerlendirilecek.

## Kaynaklar

13 Ekim 2026 güncellemesi: son muayene tarihi ve tekrar yıl aralığı, ana ekran durum kartı ve cihaz bazlı muayene bildirim tercihi eklendi. 24 Flutter ve 8 Firestore testi geçti; web ve Android deneme APK derlemeleri başarılı. Telefon bildirim teslimi henüz fiziksel cihazda doğrulanmadı. Detaylar `docs/INSPECTION.md` dosyasında.

- [Flutter için Firebase kurulumu](https://firebase.google.com/docs/flutter/setup)
- [go_router paket dokümantasyonu](https://pub.dev/packages/go_router)
- [flutter_map paket dokümantasyonu](https://pub.dev/packages/flutter_map)

13 Ekim 2026: Yakıt ve masraf kayıtları activityRecords altında tek defter olarak uygulandı. Özet ve istatistikler gerçek kayıtlara bağlandı; 19 Flutter ve 7 güvenlik testi geçti. Detaylar docs/RECORDS.md dosyasında.
