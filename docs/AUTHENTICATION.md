# Firebase Authentication

## Bağlantı

Hazır MyCar projesi (`mycar-f0673`) mevcut Firebase CLI oturumundan bulundu. Yeni Firebase projesi veya yeni platform uygulaması oluşturulmadı; mevcut Android/iOS/web uygulamalarının bilgileri FlutterFire ile alındı.

`lib/core/services/firebase_bootstrap.dart` uygulama açılırken Firebase'i başlatır. Başlatma hatası olursa formda bağlantı sorunu gösterilir ve hesap işlemleri devre dışı kalır.

`AuthRepository` Firebase işlemlerini arayüzden ayırır. `FirebaseAuthRepository` gerçek SDK'yı; testlerde `FakeAuthRepository` kontrollü oturumları kullanır. Şifreler Firestore'a veya uygulama loglarına yazılmaz.

## Ekranlar

- `/login`: e-posta/şifreyle giriş.
- `/register`: e-posta, şifre ve şifre tekrarı. Kayıt başarılı olduğunda Firebase'in açtığı oturumla özete geçilir.
- `/forgot-password`: sıfırlama e-postası isteği. Kullanıcı şifresini e-postadaki Firebase bağlantısından yeniler.
- `/session`: SDK'nın kayıtlı oturumu kontrol etmesi ve bağlantı hatası yeniden denemesi.
- `/settings`: hesap e-postası ve çıkış.

GoRouter oturum değişimlerini dinler. Girişsiz kullanıcı özel ekranlara yönlendirilemez; çıkıştan sonra geri veya adres değişimi giriş kontrolünü aşmaz. Firestore sahiplik kuralları araç ve masraf verilerini ayrıca kullanıcı UID'sine göre korur.

## Tek e-posta ve kalıcı oturum

Giriş, kayıt ve parola sıfırlamada e-postanın başındaki/sonundaki boşluklar kaldırılır ve küçük harfe çevrilir. Şifre değiştirilmez. Hesaplar Firebase Authentication'da oluşturulur; tekillik sunucunun `email-already-in-use` kontrolüyle sağlanır. Önceden hesap sorgulayan ve eşzamanlı kayıtlarda yarışa neden olan bir istemci kontrolü kullanılmaz.

13 Ekim 2026 yönetim API denetiminde `allowDuplicateEmails=false`, toplam 2 hesap ve normalize edilmiş e-posta başına birden fazla hesap grubu 0 bulundu. Hesapların kişisel bilgileri çıktıya veya dosyaya kaydedilmez. Denetim: `node tool/check_auth_config.cjs` (yetkili Firebase CLI oturumu gerekir).

Web başlangıcında `Persistence.LOCAL` açıkça ayarlanır; Android/iOS Firebase SDK'sı oturumu cihazda saklar. Uygulama açılırken SDK'nın oturum sonucu beklenir. Şifreler uygulama depolamasına yazılmaz. Çıkış, tarayıcı/uygulama verilerinin silinmesi veya hesabın iptali yeniden giriş gerektirir. Web'de farklı adresler ayrı oturum depoları kullanır; geliştirmede sürekli `http://localhost:4173` kullanılmalıdır.

Authentication emulator testi aynı e-postanın büyük harfle tekrar kaydını, yanlış parola reddini, ilk hesabın UID'sinin korunmasını ve çıkışı doğrular: `firebase emulators:exec --only auth --project demo-mycar --config firebase.auth.emulator.json "node --test tool/auth_emulator.test.cjs"`. Widget testleri kayıt hatasının gösterilmesini ve saklanan oturumla uygulamanın yeniden açılmasını da kontrol eder.

## Doğrulama

Widget testleri form doğrulamasını, şifre eşleşmesini, giriş hatasını, özel sayfa yönlendirmesini, başarılı kayıt sonrası geçişi, çıkışı, parola sıfırlama sonucunu, tekrar gönderim engelini ve oturum hatası yeniden denemesini kontrol eder. Bu testler gerçek kişilere e-posta göndermez ve üretim hesapları oluşturmaz.

Firebase yönetim API'sinden e-posta/şifre sağlayıcısının etkin olduğu okundu. Gerçek kullanıcının başarılı giriş/kayıt işlemi ve gelen kutusuna e-posta teslimi kullanıcı hesabıyla ayrıca denenmelidir. Android/iOS cihaz doğrulaması henüz yapılmadı.

## Kaynaklar

- [Flutter e-posta/şifre Authentication](https://firebase.google.com/docs/auth/flutter/password-auth)
- [Kullanıcı yönetimi ve parola sıfırlama](https://firebase.google.com/docs/auth/flutter/manage-users)
- [Flutter oturum kalıcılığı](https://firebase.google.com/docs/auth/flutter/start)
- [Firebase tek e-posta yapılandırması](https://docs.cloud.google.com/identity-platform/docs/reference/rest/v2/Config#SignInConfig)
