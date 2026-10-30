# Yakıt fişinden doldurma

## Yeni iki fiş (0.2.5)

KBENZİN, KBENZ IN ve KBENZ LN gibi OCR ürün yazımları desteklenir. Ondalık ayırıcıdan sonraki yatay boşluklar düzeltilir; `44, 780LT` değeri 44,780 litre olarak okunur. Bu düzeltme satırları birleştirmez. Sayının ondalık parçasının bağımsız litre miktarı olarak alınması engellenir. Bitişik `44,780LT` / `44,780LTX` yazımları da desteklenir.

Yeni fotoğrafların yerel OCR sonuçları: 23,920 L / 1.000,00 TL ve 44,780 L / 150,01 TL. Önceki üç fotoğrafın kayıtlı OCR sonuçları ayrıca test edilir. Örnek araçları isteğe bağlı adet ve çıktı dizini alır: `dart run tool/prepare_receipt_samples.dart <klasör> 2 build/receipt-validation-new`, `node tool/read_receipt_samples.cjs <klasör> 2 build/receipt-validation-new`; test için `--dart-define=CHECK_NEW_RECEIPTS=true` kullanılır. Yeni fotoğraflar test kaynaklarına eklenmez.

## Fotoğraf örneklerine göre iyileştirme (0.2.4)

- EXCELLIUM/EURODI ürün adları desteklenir. TOPLAN gibi son harf OCR sapmaları ve tutarın kenarındaki çizgi/asterisk işaretleri ayıklanır.
- Fotoğrafın EXIF yönü düzeltilir. Büyük açık renkli kâğıt alanı pay bırakılarak ayrılır, yazılar büyütülür ve gri ton/kontrast uygulanır. İlk okuma fişin orta ürün/ödeme bandına odaklanır; eksik alan varsa tam orijinal fotoğraf da okunur. Böylece kırpma bir alanı dışarıda bıraksa bile tam fotoğraf kullanılabilir.
- Web'de ilk okuma seyrek metin, ikinci okuma tam metin düzenindedir; Android'de her iki okumada ML Kit satır konumları kullanılır. İki sonuç farklı sayılar verirse ilgili alan tahmin edilmez.
- Yerel üç fotoğraf testi: 15,520 L / 650,29 TL; 29,900 L / 165,05 TL; 84,15 L / 4.309,74 TL. Kullanıcının fotoğrafları test kaynaklarına eklenmez; geçici çalışma dosyaları git tarafından dışlanan `build/receipt-validation/` dizinindedir. Ham OCR metni konsola veya Firestore'a yazılmaz.

İsteğe bağlı yeniden doğrulama: `dart run tool/prepare_receipt_samples.dart <yerel-fotoğraf-klasörü>` (1.jpg, 2.jpg, 3.jpg), `node tool/read_receipt_samples.cjs <yerel-fotoğraf-klasörü>`, ardından `flutter test --dart-define=CHECK_LOCAL_RECEIPTS=true`. Yerel dosyalar yokken fotoğraf testi varsayılan olarak atlanır. Bu test yerel Tesseract motorunu kapsar; fiziksel Android cihazında ML Kit ayrıca denenmelidir.

## Android TOP/TOPLAM düzeltmesi (0.2.3)

Android ML Kit metni farklı sütunları ayrı bloklar halinde döndürebilir. Yakıt fişi okumada artık bu blokların satırları, dikey örtüşme ve yatay konumlarına göre yeniden birleştirilir. Böylece soldaki TOP/TOPLAM etiketi sağdaki tutarla aynı satıra gelir. Poliçe okumasının mevcut metin sırası değiştirilmez. TOP, TOP., T0P ve TOPLAM desteklenir; TOPKDV veya TOP KDV toplam ödeme kabul edilmez.

`test/receipt_ocr_layout_test.dart` sütun birleştirmeyi ve komşu KDV satırına atlamamayı kontrol eder. `integration_test/fuel_receipt_device_test.dart` gerçek Android ML Kit için hazırlanmıştır; 0.2.3 hazırlanırken telefon bağlı olmadığından bu cihaz testi çalıştırılmamıştır. Cihaz testi için sentetik `test/fixtures/fuel_receipt_sample.png` dosyası uygulamanın harici dosya dizinine `mycar_receipt_test.png` adıyla konulmalı ve `flutter test integration_test/fuel_receipt_device_test.dart -d <cihaz>` çalıştırılmalıdır. Sonrasında normal uygulama APK'sı yeniden derlenip yüklenir. Gerçek fişler veya ham OCR metni test günlüklerine yazılmaz.

Yan menü → Yakıt ekle → Fiş fotoğrafı çek / Fiş fotoğrafı seç.

Fotoğraf cihazda okunur. Android'de mevcut ML Kit okuyucusu, web'de uygulamayla dağıtılan Türkçe/İngilizce Tesseract modeli kullanılır. Fotoğraf veya ham metin Firestore'a gönderilmez; yalnızca kullanıcı Kaydı kaydet'e bastığında form alanları mevcut yakıt kaydı olarak saklanır.

- Litre ve toplam ödeme önce önizlemede gösterilir; kullanıcı hangi alanların değişeceğini seçebilir veya vazgeçebilir.
- Kilometre, tarih, yakıt türü ve depo doluluğu otomatik değiştirilmez. Okunamayan alanlar elle tamamlanır. Mevcut litre fiyatı hesabı doldurulan değerlerle güncellenir.
- Yakıt ürünü geçen fişlerde açık litre birimi/etiketi ve toplam/tutar etiketleri aranır. Tutarın ayrı satıra düşmesi, `TOPLAM (TL)`, `T0PLAM`, noktalı ayraçlar ve farklı binlik ayırıcılar desteklenir. Toplam bulunamazsa yalnızca tek ödeme satırı kullanılabilir; nakit için para üstü/iade bulunmaması gerekir. Bölünmüş ödemeler toplanmaz. Birim fiyat, KDV ve para üstü toplam ödeme yerine kullanılmaz. Çelişkili toplamlar varsa ilgili alan boş bırakılır.
- Market alışverişiyle birleşik fişlerde toplam tutar yakıt dışı alışveriş içerebilir; önizlemede ve kayıttan önce yakıt tutarı kontrol edilmelidir. Tüm fiş düzenleri garanti edilmez; net, düz ve tamamı görünen fotoğraf kullanılır. En fazla 20 MB fotoğraf desteklenir.

`test/fuel_receipt_test.dart` sayı/etiket ayrımını; `test/activity_test.dart` kamera seçimi, önizleme/onay, iptal/hata ve açıkça kaydetme akışını sınar. `node tool/check_document_ocr.cjs` kişisel veri içermeyen örnek yakıt fişini gerçek Tesseract motoruyla okur. Fiziksel kamera ve Android ML Kit okuması cihaz üzerinde ayrıca denenmelidir.
