# Bakım geçmişi ve periyodik bakım

Yan menü → **Bakım takibi** seçili aracın kayıtlarını açar. Her kayıt bakım tarihi ve kilometresi, değişen parçalar, diğer işlemler, servis/usta, notlar ve isteğe bağlı tutar içerir. Eski kayıtlar yeni kayıt eklendiğinde korunur; ayrıntılar açılıp düzenlenebilir. Silme yoktur.

Varsayılan aralık **10.000 km** olup her bakım kaydında 1.000–100.000 km arasında değiştirilebilir. Araç üreticisinin bakım planına göre girilmelidir. Takip yalnızca kilometreye bağlıdır; ay/yıl aralığı ve süreye bağlı uyarı yoktur. Bakım tarihi, geçmişte hangi işlemin ne zaman yapıldığını göstermek için korunur. Eski kayıtlardaki `intervalMonths` alanı okunurken yok sayılır; yeni kayıt ve düzenlemelerde yazılmaz.

Geçmiş bakım eklemek, tarih olarak daha yeni bakımı değiştirmez. Liste bakım tarihine, aynı tarihte kilometreye göre yeniden eskiye sıralanır. Son kayıttan sonraki bakım kilometresi türetilir. Güncel kilometre, araç kaydından alınır; bakım kilometresi bunu geçemez. Güncel kilometreyi değiştirmek gerekiyorsa önce araç düzenlenir.

2.000 km kalınca özet ekranında yaklaşma uyarısı; kilometrenin dolması durumunda bakım zamanı, aşılması durumunda gecikme uyarısı gösterilir. Eski bakım tarihi tek başına uyarı oluşturmaz. Ayarlar → Bildirimler → Bakım bildirimleri açılıp cihaz izni verildiğinde yerel bildirim de gösterilir. Kontrol uygulama açıldığında, geri dönüldüğünde veya kayıtlı kilometre/bakım değiştiğinde yapılır; araç kilometresi otomatik okunmaz. Aynı hesap, araç, bakım döngüsü ve aşama için bildirim tekrarlanmaz. Yeni bakım veya çıkış eski bildirimi temizler. Bildirime dokununca hesap ve araç sahipliği kontrol edilerek son bakımın değişen parçaları açık gösterilir; tüm geçmişe geçilebilir. Bakım tutarı bakım geçmişinde saklanır, gider toplamına otomatik eklenmez. Formda bu bilgi gösterilir; gider kaydı ayrıca eklenebilir.

## Veri ve erişim

`users/{uid}/vehicles/{vehicleId}/maintenance/{entryId}` belgeleri kullanıcıya özeldir. Araç sahipliği, aktif araç kaydı, kilometre, tarih, tutar, parça listesi ve metin uzunlukları hem istemcide hem Firestore kurallarında kontrol edilir. Güncelleme oluşturulma zamanını değiştiremez. Arşivli araca bakım yazılamaz; önceki kayıtlar korunur. Kayıt işlemi parent ve eski kayıt okunarak transaction içinde yapılır.

Parçalar: motor yağı, yağ/hava/polen/yakıt filtreleri, bujiler, balata, fren hidroliği, antifriz, şanzıman yağı, triger seti, akü ve lastikler. Diğer parçalar ve kontroller serbest metinle yazılabilir.

## Kontrol ve yayın

```powershell
flutter test test/maintenance_test.dart test/widget_test.dart --no-pub
npx --yes firebase-tools emulators:exec --only firestore --project demo-mycar --config firebase.emulator.json "node --test tool/firestore_rules.test.cjs"
npx --yes firebase-tools deploy --only firestore:rules --project mycar-f0673 --non-interactive
```

Emülatör Java 21 veya üstünü kullanır. Model testleri kilometre eşiklerini, eski tarihin uyarı oluşturmamasını, eski ay alanının yok sayılmasını, geçmiş sıralamasını ve verinin dönüşümünü; ekran testi kayıt ekleme/düzenleme, hata halinde formun korunması ve araç değişiminde uyarının ayrılmasını kontrol eder. Kurallar testi başka hesapların erişimini, geçersiz veriyi ve arşivli araca yazmayı reddeder.

