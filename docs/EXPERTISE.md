# Araç ekspertizi

Hızlı erişim → Araç ekspertizi, seçili araca ait 13 dış gövde parçasını gösterir. Parçaya dokunularak belirtilmedi, orijinal, boyalı, lokal boyalı, değişen veya hasarlı seçilir. Ön üsttedir; sol/sağ sürücü oturma yönüne göredir. Şema ile parça listesi aynı veriyi kullanır. Kayıt güncellenebilir; notlar en fazla 2.000 karakterdir. PDF’den otomatik veri çıkarılmaz.

Veri: users/{uid}/vehicles/{vehicleId}/expertise/current. Firebase hesabı ve aktif araç sahipliği yazma sırasında kontrol edilir. createdAt korunur. Başka hesap okuyamaz/yazamaz. Araç arşivlenince güncelleme reddedilir.

PDF isteğe bağlıdır; en fazla 10 MB. Dosya uzantısı, boyutu ve PDF başlığı kontrol edilir. Dosya Firebase Storage üzerinde users/{uid}/vehicles/{vehicleId}/expertise/{reportId}.pdf yolunda saklanır. İndirme bağlantısı paylaşılmaz; getData ile oturumun erişim kuralları üzerinden okunur ve uygulamada PdfViewer ile gösterilir. Yeni PDF önce ayrı adla yüklenir; belge kaydı başarısız olursa yeni yüklenen dosya temizlenmeye çalışılır. Eski PDF yalnızca başarılı kayıt değişiminden sonra temizlenir. Temizlik başarısızsa erişim kullanıcıya özel kalır ancak kullanılmayan dosya depolamada kalabilir.

## Kurulum

mycar-f0673 projesinde Firebase Console → Storage → Get started ile varsayılan depolamanın oluşturulması gerekir. Yapılandırılmış bucket: mycar-f0673.firebasestorage.app. Kurulum sonrası `npx --yes firebase-tools deploy --only storage --project mycar-f0673 --non-interactive`. Storage Rules Firestore üzerinden araç kontrolü yaptığından Firebase'in servis erişim onayını gerektirebilir. Şema kayıtları Storage kurulumundan bağımsız çalışır.

## Doğrulama

- flutter test test/expertise_test.dart test/widget_test.dart --no-pub
- Firebase emulators:exec --only firestore --project demo-mycar --config firebase.emulator.json "node --test tool/firestore_rules.test.cjs"
- Firebase emulators:exec --only firestore,storage --project demo-mycar --config firebase.expertise.emulator.json "node --test tool/expertise_storage.test.cjs"
