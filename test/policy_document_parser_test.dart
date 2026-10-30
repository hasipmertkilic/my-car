import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/features/insurance/services/policy_document_parser.dart';

void main() {
  test('Trafik belgesindeki etiketler, Türkçe tutar ve basamak okunur', () {
    final f = parsePolicyDocument('''
ZORUNLU MALİ SORUMLULUK TRAFİK SİGORTASI
Sigorta Şirketi: Örnek Sigorta A.Ş.
Poliçe Numarası: TR-123456/2
Başlangıç Tarihi: 19.10.2026 12:00
Bitiş Tarihi: 19/10/2027
Hasarsızlık Basamağı: 8. basamak
Toplam Brüt Prim: 12.500,50 TL
Net Prim: 11000,00 TL
Teminat Bedeli: 999999 TL
''');
    expect(f.company, 'Örnek Sigorta A.Ş.');
    expect(f.number, 'TR-123456/2');
    expect(f.kind, 'traffic');
    expect(f.startDate, DateTime(2026, 10, 19));
    expect(f.endDate, DateTime(2027, 10, 19));
    expect(f.step, 8);
    expect(f.premiumKurus, 1250050);
  });
  test('Kasko kapsamı ve bir sonraki satırdaki şirket/no okunur', () {
    final f = parsePolicyDocument('''
GENİŞLETİLMİŞ KASKO POLİÇESİ
Sigortacı:
Deneme Sigorta A.Ş.
Poliçe No:
K-456789
Poliçe Başlangıç Tarihi: 01-02-2026
Poliçe Bitiş Tarihi: 01-02-2027
Poliçe Tutarı (TL): 42500.25
''');
    expect(f.kind, 'casco');
    expect(f.level, 'Genişletilmiş Kasko');
    expect(f.step, isNull);
    expect(f.company, 'Deneme Sigorta A.Ş.');
    expect(f.number, 'K-456789');
    expect(f.premiumKurus, 4250025);
  });
  test('Kimlik, teminat ve net prim poliçe alanı gibi tahmin edilmez', () {
    final f = parsePolicyDocument(
      'T.C. Kimlik No: 11111111111\nSigortalı: Örnek Kişi\nNet Prim: 1000\nTeminat Bedeli: 500000',
    );
    expect(f.isEmpty, isTrue);
  });
  test(
    'Çelişkili numaralar, tarihler, geçersiz basamak/tutar boş bırakılır',
    () {
      final f = parsePolicyDocument('''
Trafik Sigortası
Poliçe No: P123
Poliçe No: P456
Başlangıç Tarihi: 31.02.2026
Bitiş Tarihi: 01.01.2026
Hasarsızlık Basamağı: 9
Toplam Prim: 12.500
''');
      expect(f.number, isNull);
      expect(f.startDate, isNull);
      expect(f.step, isNull);
      expect(f.premiumKurus, isNull);
      final reversed = parsePolicyDocument(
        'Başlangıç Tarihi: 01.01.2027\nBitiş Tarihi: 01.01.2026',
      );
      expect(reversed.startDate, isNull);
      expect(reversed.endDate, isNull);
    },
  );
}
