# Sigorta ve kasko poliçeleri

Yan menü → Sigorta ve kasko poliçeleri veya Garaj → aracın Poliçeler düğmesi. Ana ekranda yalnızca süresi yaklaşan/geçen poliçeler için kısa uyarılar gösterilir.

- Trafik sigortası: isteğe bağlı 0–8 hasarsızlık basamağı.
- Kasko: Dar Kasko, Kasko, Genişletilmiş Kasko veya Tam Kasko kapsamı.
- Şirket, poliçe numarası, başlangıç/bitiş tarihi ve pozitif poliçe tutarı zorunlu; teminat notları isteğe bağlıdır.
- Bilgiler kullanıcının poliçe belgesinden girilir; şirketlerden otomatik sorgulama veya poliçe satın alma yapılmaz.
- Poliçe formunda **PDF / fotoğraf seç** veya **Fotoğraf çek** ile belgeden doldurma vardır. Şifresiz PDF (en fazla 10 sayfa), JPG ve PNG; en fazla 20 MB desteklenir. Metin içeren PDF doğrudan okunur; taranmış sayfalar/fotoğraflar OCR ile okunur.
- Okunan alanlar önce önizlemede gösterilir. Kullanıcı hangi alanların değişeceğini seçer, eksikleri tamamlar ve ayrıca Kaydet'e basar. Şirket, poliçe numarası, DD.MM.YYYY/DD-MM-YYYY/DD/MM/YYYY tarihleri, trafik basamağı, kasko kapsamı ve brüt/toplam prim için etiketli değerler aranır. Net prim veya teminat limiti toplam tutar yerine kullanılmaz. Birden fazla çelişkili değer bulunan alan önerilmez.
- Bu bir e-Devlet entegrasyonu veya belge doğrulaması değildir. e-Devlet'in tüm belge şablonları garanti edilmez; fotoğrafın netliği ve belgenin yerleşimi sonucu etkiler. Okunmayan alanlar elle tamamlanır.
- Belge, ham OCR metni ve kimlik/adres alanları Firestore'a gönderilmez. Android'de ML Kit, web'de yerel Tesseract.js worker kullanılır. Web model/worker dosyaları ilk kullanımda uygulamanın kendi adresinden yüklenir. Android OCR geçici çalışma dosyaları işlem sonunda temizlenir. Yalnızca kullanıcı tarafından kaydedilen poliçe alanları mevcut Firestore yoluna yazılır.
- Yenilemede yeni poliçe eklenebilir; süresi dolan kayıtlar listede korunur. Düzenleme ve arşivleme vardır. Arşivleme sonrası Geri al seçeneği sunulur.
- Özet her türün geçerli poliçesini gösterir; yoksa sıradaki, o da yoksa en son biten poliçeyi seçer. Başlamamış poliçeler ayrıca belirtilir. Son 30 gün ve süresi geçmiş poliçeler uyarı rengiyle gösterilir. Bu özellik ana ekran uyarısıdır; sigorta için sistem bildirimi planlanmaz.
- Poliçe tutarı ayrı saklanır; masraf toplamlarına otomatik eklenmez. Ödeme kaydı için Kayıtlar bölümünde masraf eklenebilir.

## Veri ve erişim

Firestore yolu: `users/{uid}/vehicles/{vehicleId}/policies/{policyId}`. Kayıtlar yalnızca hesap sahibi tarafından okunabilir/yazılabilir. Araç arşivlenince poliçe yazımı engellenir. Kalıcı silme engellidir. Tutar kuruş cinsinden tam sayı, tarihler UTC takvim günü olarak saklanır.

Model/form testleri tarih, seviye, para hassasiyeti ve kayıt hatasını kapsar. Firestore emülatör testi hesap izolasyonu, eksik/arşivlenmiş araç, geçersiz alanlar ve arşiv/geri alma kurallarını doğrular.

## Belge okuyucuyu geliştirme

Web OCR kütüphanesi sabit `tesseract.js@7.0.0` sürümüdür. `npm ci --prefix tool` ardından `node tool/prepare_document_ocr.cjs` dağıtım dosyalarını hazırlar. Türkçe/İngilizce model dosyaları `web/vendor/document-ocr/languages/` altında bulunur. Kaynak: `https://tessdata.projectnaptha.com/4.0.0/{tur,eng}.traineddata.gz`. Flutter web derlemesi bu dizini kopyalar. Dağıtımda `.wasm` MIME türü `application/wasm` olmalıdır; yerel önizleme sunucusu bunu sağlar.

`flutter test` gerçek PDF motoruyla sentetik metinli PDF'yi, alan ayrıştırmayı ve onay/iptal/hata form akışını doğrular. `node tool/check_document_ocr.cjs` kişisel veri içermeyen Türkçe örnek PNG'yi gerçek Tesseract modeliyle okur. Android kamera ve ML Kit için fiziksel cihazda farklı ışık/odak koşullarında ayrıca kullanım testi yapılmalıdır.

Seviye adları için: [TSB sık sorulan sorular](https://www.tsb.org.tr/tr/sss), [SEDDK 0 ve 8. basamak duyurusu](https://www.seddk.gov.tr/upload/doc/SEDDK-basin-bulteni-04.04.2023.pdf). Uygulama indirim oranı veya teminat vaadi hesaplamaz.
