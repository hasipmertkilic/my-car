# Marka, seri ve model seçimi

Araç ekleme/düzenlemede Marka ve Model metin alanları seçim listeleri oldu. BMW ve Mercedes-Benz için önce seri, ardından model seçilir. Tek gruplu markalarda seri otomatik seçilir ve kullanıcı doğrudan model seçer. Marka/seri değişiminde eski model temizlenir; seçim tamamlanmadan kaydedilemez.

Başlangıç kataloğu 24 marka içerir. BMW 3 Serisi için 320i/330i/320d gibi modeller; Mercedes-Benz E Serisi için E 200/E 250/E 300 gibi seçenekler vardır. Liste eski ve yeni model adlarını içerir; tüm yılların/donanımların eksiksiz veya güncel satış kataloğu değildir. Motor hacmi, model yılı ve yakıt bilgisi kullanıcı tarafından ayrıca doğrulanır.

Katalog `lib/features/vehicles/data/vehicle_catalog.dart` dosyasında merkezi olarak tutulur. Yeni bir model/marka buradan eklenebilir. Çevrimdışı seçim için harici hesap/API gerektirmez.

Firestore şeması değişmedi: seçilen marka ve model önceki `brand`/`model` alanlarına kaydedilir. Seri katalogda gruplama amacıyla kullanılır. Katalog dışındaki eski marka/model değerleri “Mevcut kayıt” grubunda korunur; kullanıcının eski verisi sessizce değiştirilmez.

Kontroller: marka/seri/model seçimi, marka değişiminde model sıfırlama, Mercedes-Benz E 250 kaydı ve katalog dışındaki eski kayıtların korunması araç testlerinde doğrulanır.

5 araç testi geçti. Firestore alanları ve güvenlik kuralları değişmedi. Mevcut veriler otomatik olarak yeniden yazılmadı.

Model adları için örnek resmî kaynaklar: [BMW 3 Serisi](https://www.bmw.com.tr/tr/all-models/3-series/bmw-3-serisi-sedan/bmw-3-serisi-sedan.html), [Mercedes-Benz modelleri](https://www.mercedes-benz.com.tr/passengercars/models.html).
