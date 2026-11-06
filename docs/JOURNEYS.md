# Yolculuk planı

Hızlı erişim > Rota oluştur bölümünden açılır. Seçili araç kullanılır.
Başlangıç güncel konum, yazılı adres veya haritadan nokta olabilir; varış adres veya nokta olabilir.
Konum yalnızca arama düğmesiyle istenir. Google en fazla üç alternatif döndürür; her aramada alternatif bulunmayabilir.
Mesafe ve trafik içermeyen süre gösterilir. Google Haritalar düğmesi harici uygulamada rotayı yeniden hesaplayabilir.

## Maliyet
Tüketim L/100 km (elektrikli araçta kWh/100 km), birim fiyat TL/L veya TL/kWh.
Yakıt = mesafe × tüketim / 100 × birim fiyat.
Uygun dolu depo kayıtları ve son yakıt birim fiyatı varsa ön doldurulur; canlı fiyat değildir.
Geçiş ücretleri otomatik sorgulanmaz. Her alternatif için ayrı elle girilir. Boş değer bilinmiyor, açıkça girilen 0 ücretsiz anlamındadır.
Sonuçlar ve elle girilen ücretler bu ekranın belleğinde tutulur; yolculuk geçmişi kaydedilmez.

## Sunucu
planRoutes, us-central1, Firebase oturumu zorunlu. Kullanıcı başına 10 saniyede bir ve UTC günü başına 50 arama.
ROUTES_API_KEY Secret Manager üzerinden okunur; istemciye veya depoya yazılmaz.
Routes API açık ve faturalandırma bağlı olmalıdır. Yalnızca Routes API izni olan ayrı sunucu anahtarı kullanılır.
TRAFFIC_UNAWARE, temel alan maskesi ve alternatif rotalar istenir. TOLLS veya extraComputations kullanılmaz.
Firestore sayaçları yalnızca gün, adet ve son istek zamanını tutar; konum/adres saklamaz.

Yayınlama: npx --yes firebase-tools deploy --only functions:planRoutes --project mycar-f0673

## EDS katmanı (0.5.1)
EGM’nin kamuya açık haritasından 3 Kasım 2026 tarihinde alınmış 1.543 geçerli nokta assets/eds/egm_points.json içinde paketlenir. Bir geçersiz koordinat elendi. Kaynak son güncelleme tarihi belirtilmiyor; alınma tarihi güncellik garantisi değildir.
Kaynak: https://onlineislemler.egm.gov.tr/trafik/sayfalar/edsharita.aspx

Seçilen rotanın overview geometrisine 150 metre yakın noktalar yaklaşık olarak eşleştirilir ve rota başlangıcına göre sıralanır. Mesafeler geometri üzerinde yaklaşık ilerlemedir. Paralel yol, ters yön veya geometri sadeleştirmesi nedeniyle yanlış/eksik eşleşme olabilir. Eşleşme bulunmaması denetim olmadığı anlamına gelmez.

Kamera simgeleri açılıp kapatılabilir; dokununca kaynak açıklaması ve veri tarihi gösterilir. Açıklamadan denetim türü/hız sınırı tahmini üretilmez. Resmi sayfadaki ortalama hız bölgesi görselleri doğrulanmış koordinat/koridor geometrisi sağlamadığından haritada uydurma koridor çizgisi gösterilmez; resmi sayfaya bağlantı sunulur. 

Veri çevrimdışı yüklenir, ek Google sorgusu veya yeni ücretli servis kullanılmaz. 30 günden eski kopya için uyarı gösterilir. Güncelleme için resmi HTML yeniden indirilip node tool/import_eds.cjs DOSYA.html çalıştırılır; alınma tarihi ve geçerli kayıt sayısı kontrol edilip uygulama yeniden paketlenir. İçe aktarıcı JavaScript çalıştırmaz; yalnızca koordinat ve açıklama alanlarını ayrıştırır. Kaynak biçimi değişirse mevcut dosyayı ezmeden hata verir.

0.5.2: EDS uyarıları kullanıcı tarafından başlatılır. Rota ekranı ön plandayken yaklaşık 500 m içindeki ilerideki noktalar için oturum başına bir kez ekranda uyarı ve desteklenen cihazlarda titreşim verilir. Arka plana geçince takip durur. Konum cihazda işlenir.
