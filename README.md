## Yerel yapılandırma

Anahtarlar GitHub'a eklenmez. Yeni kurulum ve derleme için önce [Yerel anahtarlar ve GitHub](docs/SECRETS.md) belgesini uygula.

# My Car — Kişisel araç yönetimi

Üniversite bitirme projesi için Flutter ve Firebase ile geliştirilecek mobil uygulama.

## Mevcut aşama

Flutter, Firebase Authentication ve Firestore araç yönetimi eklendi. Garajdan araç eklenebilir, düzenlenebilir, aktif araç seçilebilir ve araç kaldırılabilir.

Gerçek Firebase projesi: `mycar-f0673` (MyCar). Hesaplar Firebase Authentication üzerinde oluşturulur. SDK oturumu yeniden açılışta korur; özel sayfalar oturum kontrolünden sonra açılır. Araçlar ve aktif araç tercihi kullanıcı hesabında kalıcıdır. Örnek veriler kaldırıldı. Yakıt ve masraf ekleme/düzenleme/kaldırma ve istatistikler hazırdır. Bakım periyotları sonraki aşamadadır. Tema seçimi henüz kalıcı değildir.

## Hesap akışı

- E-posta ve şifreyle giriş; Firebase hataları Türkçe gösterilir.
- Kayıtta geçerli e-posta, en az 6 karakter şifre ve eşleşen şifre tekrarı gerekir. Firebase projesinin daha güçlü şifre politikası varsa sunucu ayrıca uygular.
- Şifremi unuttum: Türkçe şifre sıfırlama e-postası istenir. Ekran hesap varlığını ifşa etmeyen bir sonuç gösterir. Gelen kutusu/spam kontrol edilmelidir.
- Ayarlar → Çıkış yap. Girişsiz kullanıcı doğrudan özel sayfa adresi açsa da girişe yönlendirilir.
- Başlatma veya oturum hatası, başarılı giriş gibi gösterilmez. İşlem sürerken form tekrar gönderilemez.

Firebase Console üzerinde e-posta/şifre sağlayıcısının etkin olduğu kontrol edildi. `localhost` yetkili alan adları arasında; `127.0.0.1` bulunmuyor. Web geliştirmede `localhost` adresini kullan.

Firebase bağlantısı `lib/firebase_options.dart` ile sağlanır. Android uygulama kimliği mevcut Firebase kaydına uygun `com.mertkilic.mycar`; iOS kimliği `com.example.myCar`. Yapılandırma dosyaları istemci uygulama bilgileridir, servis hesabı veya yönetici anahtarı içermez.

## Çalıştırma

Proje klasöründe:

```sh
flutter pub get
flutter run -d chrome --dart-define-from-file=config/firebase.local.json
```

Android için Android Studio'dan bir emülatör başlat veya USB hata ayıklaması açık telefon bağla; ardından `flutter devices` ve `flutter run -d <cihaz-kimliği>` kullan.

12 Ekim 2026 ortam kontrolü: Flutter 3.44.6 / Dart 3.12.2 mevcut. Android SDK mevcut, ancak bazı Android lisansları henüz kabul edilmemiş. Android çalıştırmadan önce `flutter doctor --android-licenses` ile lisansları inceleyip kabul etmek gerekiyor. Kontrol sırasında bağlı Android cihaz/emülatör yoktu. iOS derlemesi macOS/Xcode gerektirir.

## Kontroller

```sh
flutter analyze
flutter test
flutter build web --dart-define-from-file=config/firebase.local.json
```

Doğrulama: analyze temiz, 34 Flutter testi geçti; önceki 10 Firestore güvenlik testi de korunuyor. Park ekranında Google Haritalar ve araba simgesi eklendi; Google Maps yürüyüş rotası bağlantısı ile kapalı otoparkın isteğe bağlı giriş konumu desteklenir. Android/iOS cihazında gerçek GPS, Google Maps navigasyonu, bildirim teslimi ve e-posta teslimi henüz denenmedi. Google Maps yapılandırma ve derleme adımları `docs/PARKING.md` içindedir.

Derlenmiş web sürümünü yerelde açmak için `node tool/preview.cjs` kullanıp http://localhost:4173 adresine git. Bu önizleme yalnızca bilgisayarından erişilebilir.

## Kod yapısı

- `lib/app`: uygulama, tema ve yönlendirme.
- `lib/core`: ortak bileşenler ve Türkçe biçimlendirme.
- `lib/features`: hesap, araç, özet, kayıtlar, istatistikler ve ayarlar.
- Repository araçları Cloud Firestore'dan okur ve yazar; Riverpod aktif araç ve temayı yönetir. Ekranlar doğrudan veri kaynağına erişmez.

Kayıtlar ekranından Yakıt ekle veya Masraf ekle kullanılabilir. Ana ekrandaki Muayene kartından son tarih ve 1-5 yıl tekrar aralığı kaydedilir. Bildirim tercihi muayene ekranı veya Ayarlar üzerinden açılır. Telefonda 30/7/0 gün planları; web uygulaması açıkken yaklaşan muayene uyarısı desteklenir. Sonraki aşama bakım periyotlarıdır. Araç kaldırma, veriyi silmeden arşivler; işlemden hemen sonra Geri al kullanılabilir. Fotoğraf yükleme dosya aşamasında eklenecek.

[Mimari ve geliştirme planı](docs/PROJE_PLANI.md)

[Araç kayıtları, arşivleme ve güvenlik testleri](docs/VEHICLES.md)

İlk hedef Android; iOS desteği daha sonra macOS ve Xcode ortamında doğrulanacak.

[Yakıt, masraf ve tüketim hesapları](docs/RECORDS.md)

[Muayene takibi ve bildirimler](docs/INSPECTION.md)

[Marka, seri ve model seçim listeleri](docs/VEHICLE_CATALOG.md)

[Açık alan konumu ve kapalı otopark park kaydı](docs/PARKING.md)

Android deneme APK'sı: `build/app/outputs/flutter-apk/app-debug.apk` (derleme başarılı). Gerçek cihazda muayene bildirimi teslimi henüz denenmedi.
