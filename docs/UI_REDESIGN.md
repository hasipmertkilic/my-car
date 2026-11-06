# Kontrol Merkezi — 0.4.0

0.3.0 yerleşiminden bağımsız yeni görsel sistem: sıcak nötr zemin, mürekkep rengi metinler, kobalt mavisi vurgu, sade sayısal özetler ve kapsül biçimli eylemler. Sistem teması varsayılanı ve açık/koyu seçenekleri korunur.

## Düzen

- Özet: seçilebilir kompakt araç kimliği, temsili araç çizimi ve kilometre bilgisi, gider/tüketim özeti, en son üç işlemin zaman akışı, tüm kayıtlar ve park geçmişi bağlantıları.
- Gezinme: telefonda yüzen alt menü, masaüstünde ayrı yan gezinme alanı. Rotalar aynı kalır.
- Hızlı erişim: Günlük kullanım, Aracının dosyası, Park ve garaj kategorilerinde özellik kutuları. Araç seçilmemişse araç gerektiren işlem garaja yönlendirir.
- Garaj: sıralı araç dosyaları, seçili araç göstergesi, araç bilgileri ve mevcut seç/düzenle/poliçe/kaldır eylemleri.
- Kayıtlar: fiş görünümlü yakıt/masraf kayıtları ve üç seçenekli filtre. Kaydetme, düzenleme, arşivleme ve geri alma aynı repository üzerinden çalışır.
- Analiz, park ve ayarlar: yeni sayfa başlıkları, ortak form/düğme/yüzey dili.

Gerçek veri, Firebase erişimi, GPS, harita servisleri, ekspertiz ve PDF, OCR, bakım/muayene bildirimleri, sigorta ve oturum davranışları değiştirilmez. Araç çizimi temsili olup modelin fotoğrafı değildir.

## Kontrol

flutter test --no-pub
flutter analyze --no-pub

Telefon, büyük yazı/dar ekran, masaüstü ve açık/koyu tema testleri bulunur. test/ui_redesign_test.dart önizlemeleri build/ui-preview/ altında üretir; örnek test verileri kullanır. Çizim önbelleği önizleme alınmadan yenilenir. Derleme: tool/build_local.ps1 ve SECRETS.md.
