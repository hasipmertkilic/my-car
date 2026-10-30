# Uygulama simgesi

Kaynak: `assets/branding/app_icon.jpg`. Kullanıcının sağladığı kare görsel korunur.

`dart run tool/prepare_app_icons.dart` kaynak görselden Android yoğunlukları, Android 8+ uyarlanabilir ön plan, iOS AppIcon kataloğu ve web/PWA/favicon PNG dosyalarını üretir. Yeni bir kaynak için dosya yolu ilk argüman olarak verilebilir. Oluşan PNG boyutları araç tarafından tekrar okunarak doğrulanır.

Android adaptive simgesi koyu arka plan ve 108 dp katmanda ortalanan 72 dp kaynak görselden oluşur; daire gibi başlatıcı maskelerinde kenar ayrıntıları için pay bırakılır. iOS çıktıları alfa kanalı olmadan üretilir. Web maskable simgeleri de güvenli kenar boşluğu içerir.
