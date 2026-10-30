# Yakıt ve masraf kayıtları

Kayıtlar `users/{uid}/vehicles/{vehicleId}/activityRecords/{recordId}` altında tutulur. `kind` alanı `fuel` veya `expense` değeridir. Yakıt zaten gider toplamına dahildir; ayrıca ikinci bir masraf belgesi oluşturulmaz. Önceki plandaki ayrı yakıt/masraf koleksiyonları bu aşamada tek işlem defteri olarak uygulanmıştır.

Her kayıtta tarih, kilometre, tutar, kategori ve isteğe bağlı açıklama bulunur. Yakıtta litre, yakıt türü ve dolu depo bilgisi de saklanır. Para tam sayı kuruş, yakıt miktarı tam sayı mililitre olarak kaydedilir. Form 1250,50 ve 42,3 gibi Türkçe ondalık girişleri kabul eder; binlik ayırıcı kabul etmez. Litre fiyatı tutar/litre üzerinden hesaplanır.

## Kilometre ve değişiklikler

Geçmiş tarihli kayıtlar eklenebilir. Tarihe, aynı gün içinde kilometreye göre sıralandığında kilometrenin düşmesi reddedilir. Aynı gün eşit kilometrede birden fazla masraf veya dolum kabul edilir.

Kaydetme, düzenleme, kaldırma ve geri alma sırasında araç kilometresi ve işlem aynı transaction içinde yazılır. Geçmiş, araçtaki `activityRevision` sürümüyle doğrulanır; başka cihaz geçmişi değiştirmişse işlem yeniden denenmelidir. Araç kilometresi, manuel başlangıç/değer (`baselineKm`) ile görünür işlem kayıtlarının maksimum kilometresinden büyük olanıdır. Hatalı kayıt kaldırıldığında başlangıç değerinin altına inilmez. Garaj formu kilometreyi işlem geçmişinin maksimumunun altına düşüremez.

Kayıt kaldırma arşivleme yapar; hesaplardan çıkarır. 10 saniyelik Geri al eylemi tekrar hesaplara dahil eder. Kalıcı silme kapalıdır. Kayıtlar hesap ve araç kimliğiyle sınırlandırılır; araç değişince diğer aracın kayıtları gösterilir.

## Hesaplamalar

- İki dolu depo arasındaki mesafe ve arada alınan litre üzerinden tüketim hesaplanır. İlk dolu deponun litre/tutarı aralığa dahil edilmez.
- Aradaki kısmi dolumlar toplanır; son dolu depodan sonraki henüz kapanmamış aralık tüketim hesabına girmez.
- Geçerli aralıkların toplam litre/mesafesi × 100, ortalama L/100 km değeridir. Basit oran ortalaması alınmaz. km/L ve 100 km yakıt maliyeti aynı aralıklardan hesaplanır.
- İlk kayıt veya sıfır mesafe için tüketim yerine yetersiz veri açıklaması gösterilir. Toplam yakıt/gider tüm görünür kayıtları içerir.
- Farklı yakıt türleri karıştırılmaz; tüketim son kullanılan yakıt türünün kesintisiz dolu depo aralıklarından hesaplanır.
- Aylık/yıllık giderler işlem tarihinin cihaz yerel takvimindeki ay/yılına göre toplanır. Yakıt iki kez sayılmaz.
- İstatistikler toplam litre, yakıt gideri, aylık/yıllık/toplam gider, kategori dağılımı ve son altı ay gider grafiğini gösterir.
- Gözlenen kilometre yalnızca en eski/yeni işlem kilometresi farkıdır; tüm yıl veya aracın tüm kullanım geçmişi gibi sunulmaz.

Masraf olarak bakım, tamir, lastik, sigorta, kasko, muayene, otopark, yıkama ve diğer giderler girilebilir. Bu aşamada bakım periyotları veya sigorta hatırlatması oluşturulmaz; bunlar ayrı özelliklerdir.

## Doğrulama

19 Flutter testi (formlar, eski hesap/araç akışları ve yakıt/maliyet hesabı) ve 7 Firestore emülatör testi geçti. Kurallar sahiplik, pozitif tutar/litre, kategori, tarih, oluşturulma zamanı ve araç/işlem sürümünün atomik yazılmasını doğrular. Testler üretim kullanıcılarına kayıt veya e-posta oluşturmaz.

Kurallar 13 Ekim 2026 tarihinde MyCar projesine başarıyla uygulandı; web derlemesi başarılı ve yerel sunucu açık. Gerçek kullanıcı hesabında üretim kaydı yazmak otomatik testte denenmedi. Mevcut tarayıcı hata sekmesine otomatik erişim URL güvenlik politikası tarafından engellendiği için bu sürümün tarayıcıda görsel kontrolü tamamlanmadı. Android/iOS cihaz kontrolleri henüz yapılmadı.

Kaynaklar: [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions), [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/rules-conditions).
