# Muayene takibi ve bildirimler

Ana ekrandaki Muayene kartından son muayene tarihi ve 1–5 yıl tekrar aralığı kaydedilir. Varsayılan 2 yıl seçimi kullanıcı tarafından değiştirilebilir; araç türü için yasal periyot tespiti yapılmaz. Sonraki tarih takvim yılı eklenerek hesaplanır. 29 Şubat uygun olmayan yılda 28 Şubat'a yuvarlanır. Son/sonraki tarih, aralık ve not `users/{uid}/vehicles/{vehicleId}/inspection/current` belgesinde saklanır. Son muayene bilgisi güncellenir; bu aşamada ayrı muayene geçmişi listesi veya ücret kaydı yoktur.

Tarihler UTC'de gün olarak saklanıp takvim günü şeklinde gösterilir; saat dilimi değişince kayıt tarihi başka güne kaymaz. Kalan gün farkı takvim günlerinden hesaplanır. Ana ekran 30 gün içindeki muayeneyi, bugünkü tarihi ve gecikmeyi belirgin gösterir. Uygulama açıkken gün/saat değişimleri bir dakika içinde ve uygulamaya dönüşte yeniden değerlendirilir.

## Bildirim tercihi

Muayene ekranı veya Ayarlar → Muayene bildirimleri üzerinden kullanıcı izni istenir. Varsayılan kapalıdır. Tercih cihazda ve kullanıcı UID'sine göre saklanır. İzin reddedilirse ana ekran kartı çalışmaya devam eder. Özellik hazır olmayan veya izinleri kısıtlı ortamlarda uyarı gösterilir.

### Android/iOS

30 gün, 7 gün ve muayene günü, cihazın yerel saat diliminde 09.00 civarı bildirim planlanır. Android'de inexactAllowWhileIdle kullanılır; kesin alarm izni istenmez, işletim sistemi saati geciktirebilir. Android açılış/alarm alıcıları ve bildirim izni, Java desugaring ve tek renk bildirim ikonu eklendi. iOS ön plan bildirim delegesi yapılandırıldı.

Tüm görünür araçların muayeneleri planlanır. İlk etkinleştirmede eşik geçmişse bir defalık güncel uyarı gösterilir. Aynı muayene tarihi/eşik için tekrar bildirim üretilmez. En yakın 60 gelecek plan tutulur; bu iOS sınırının altındadır.

Tarih değişirse ve araç kaldırılırsa eski planlar iptal edilip görünür araçlar tekrar planlanır. Çıkış ve bildirimleri kapatma planları iptal eder. Başka hesabın önceki planları temizlenir. Hesap/araç bilgisi başka cihazda değişirse bu cihaz uygulamayı açıp yeni Firestore verisini aldığında planlar güncellenir; sunucu tabanlı push yoktur.

### Web

Tarayıcı izniyle yaklaşan/gecikmiş muayene uygulama açıkken gösterilir. Web'de geleceğe zamanlama veya sayfa kapalıyken hatırlatma desteklenmez. Bildirim gösterimi service worker kullanır; HTTPS veya localhost ve bildirimleri destekleyen bir tarayıcı gerekir. Tarayıcı/işletim sistemi engeli varsa izin verilemeyebilir. İzin yalnızca kullanıcının anahtarı açmasıyla istenir.

## Doğrulama

24 Flutter testi ve 8 Firestore güvenlik testi geçti. Takvim yılı/artık yıl hesabı, 30/7/0 planları, gecikmiş eşik, izin reddi, tekrar uyarı engeli, tarih değişimi, çıkış/kapama, hesap değişimi, web planlamasının kapalı olması ve muayene formunun ana ekrana yansıması test edildi.

Emülatör testleri gerçek üretim hesaplarına bildirim veya muayene kaydı oluşturmaz. Gerçek Android/iOS cihazında OS bildirim teslimi henüz doğrulanmadı. Web'de izin isteme ve bildirim teslimi kullanıcının kendi ortamında ayrıca denenmelidir.

Muayene kuralları MyCar projesine başarıyla uygulandı. Web derlemesi ve muayene formunun tarayıcıda görsel kontrolü tamamlandı. Kullanıcının gerçek muayene tarihi bilinmediği için üretimde örnek bir tarih kaydedilmedi; form kullanıcı girişine hazır bırakıldı.

Android deneme derlemesi de başarılı: `build/app/outputs/flutter-apk/app-debug.apk`. Bu, uygulama ve bildirim eklentisinin Android için derlendiğini doğrular; fiziksel cihazda işletim sistemi izinleri ve gerçek bildirim teslimi ayrıca denenmelidir.

Kaynaklar: [Flutter local notifications](https://pub.dev/packages/flutter_local_notifications), [Notifications API](https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API).
