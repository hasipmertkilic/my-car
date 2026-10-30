import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/features/records/services/fuel_receipt_importer.dart';

void main() {
  test('KBENZİN parçalanmış ürün adı ve aynı fişin POS tutarı okunur', () {
    for (final name in ['KBENZİN', 'KBENZ IN', 'KBENZ LN', 'K BENZİN']) {
      final f = parseFuelReceipt(
        '23,920 LT X 41,80\n$name %20\nTOPKDV 166,67\nTOP LAM *1.000,00\nTUTAR\n1.000,00 TL',
      );
      expect(f.litersMilli, 23920, reason: name);
      expect(f.amountKurus, 100000, reason: name);
    }
  });
  test('Bitişik LT ve ondalıktaki boşluk 780 litre olarak yorumlanmaz', () {
    expect(
      parseFuelReceipt(
        'MOTORİN\nİşlem: 1.\n29,900 LT X 5,520\nTOP 165,05',
      ).litersMilli,
      29900,
    );
    for (final quantity in [
      '44,780LT X',
      '44, 780LT X',
      '44,780LTX',
      '44.780LT X',
    ]) {
      final f = parseFuelReceipt('$quantity 3,350B\nMOTORİN %18\nTOP 150,01');
      expect(f.litersMilli, 44780, reason: quantity);
      expect(f.amountKurus, 15001, reason: quantity);
    }
  });
  test(
    'Kırışık fişte toplamla fiyat arasındaki tek karakterli OCR kalıntıları atlanır',
    () {
      expect(
        parseFuelReceipt(
          'ultra motorin\n29,900 LT X 5,520\nTOP\n0\n)\n*165,05',
        ).amountKurus,
        16505,
      );
      expect(
        parseFuelReceipt('ultra motorin\nTOP\n0\nKDV\n25,18').amountKurus,
        isNull,
      );
    },
  );
  test('EXCELLIUM EURODI yakıt adı ve üç örneğin ödeme biçimleri okunur', () {
    final first = parseFuelReceipt(
      '15,520 LT X 41,90\nEXCELLIUM EURODI %20 *650,29\nTOPKDV *108,38\nTOPLAM *650,29',
    );
    expect(first.litersMilli, 15520);
    expect(first.amountKurus, 65029);
    final second = parseFuelReceipt(
      'ultra Motorin %18\n29,900 LT X 5,520\nTOP\n*165,05 |',
    );
    expect(second.litersMilli, 29900);
    expect(second.amountKurus, 16505);
    expect(
      parseFuelReceipt(
        'MOTORİN\n84,15 LT X 51,22\nTOPLAN +4.309,74',
      ).amountKurus,
      430974,
    );
  });
  test(
    'İkinci okumada eksikler tamamlanır; çelişen rakamlar tahmin edilmez',
    () {
      final f = mergeFuelReceiptReadings(
        '29,900 LT X 5,520\nultra m\nNAKIT *165,05 |',
        'ultra motorin',
      );
      expect(f.litersMilli, 29900);
      expect(f.amountKurus, 16505);
      final conflict = mergeFuelReceiptReadings(
        'Motorin\n30 LT\nTOP 165,05',
        'Motorin\n31 LT\nTOP 165,06',
      );
      expect(conflict.isEmpty, isTrue);
    },
  );
  test('TOP kısaltması okunur ama TOPKDV toplam ödeme değildir', () {
    for (final total in [
      'TOP *2.115,00',
      'TOP. (TL): 2115,00',
      'TOP\n*2.115,00',
      'T0P *2115,00',
      'TOPLAM\n*2115,00',
    ]) {
      expect(
        parseFuelReceipt(
          'MOTORİN\n42,300 LT\nTOPKDV 352,50\n$total',
        ).amountKurus,
        211500,
        reason: total,
      );
    }
    expect(parseFuelReceipt('DİZEL\nTOPKDV 352,50').amountKurus, isNull);
    expect(parseFuelReceipt('DİZEL\nTOP KDV 352,50').amountKurus, isNull);
  });
  test('Tutarın OCR yazım, para birimi ve ayraç farkları okunur', () {
    for (final total in [
      '*TOPLAM(TL): *2.115,00',
      'T0PLAM TUTARI .... 2.115,00 TL',
      'GENEL TOPLAM: TL 2 115,00',
      'TOPLAM 2,115.00',
      'TOPLAM 2.115.00',
      'ÖDENECEK TUTAR = 2115, 00',
      'TOPLAM\nTL\n*2.115,00',
    ]) {
      expect(
        parseFuelReceipt('MOTORİN\n42,300 LT\n$total').amountKurus,
        211500,
        reason: total,
      );
    }
  });
  test(
    'Toplam yoksa tek kart ödemesi kullanılabilir; KDV ve para üstü atlanır',
    () {
      expect(
        parseFuelReceipt(
          'BENZİN\nTOPKDV 352,50\nKREDİ KARTI\n*2115,00',
        ).amountKurus,
        211500,
      );
      expect(
        parseFuelReceipt('LPG\nNAKİT 1000,00\nPARA ÜSTÜ 50,00').amountKurus,
        isNull,
      );
      expect(
        parseFuelReceipt('LPG\nKREDİ KARTI 500,00\nNAKİT 300,00').amountKurus,
        isNull,
      );
      expect(
        parseFuelReceipt(
          'LPG\nTOPLAM 800,00\nNAKİT 1000,00\nPARA ÜSTÜ 200,00',
        ).amountKurus,
        80000,
      );
    },
  );
  test(
    'Başka başlığın altındaki tutara atlamaz ve çelişkili toplamı doldurmaz',
    () {
      expect(
        parseFuelReceipt('DİZEL\nTOPLAM\nTOPKDV\n352,50').amountKurus,
        isNull,
      );
      expect(
        parseFuelReceipt(
          'DİZEL\nTOPLAM 500,00\nSATIŞ TUTARI 600,00\nKREDİ KARTI 500,00',
        ).amountKurus,
        isNull,
      );
      expect(parseFuelReceipt('LPG\nTOPLAM .50').amountKurus, isNull);
    },
  );
  test('Ayrı satırdaki toplam ve yaygın ürün adı okunur', () {
    final f = parseFuelReceipt('KURSUNSUZ95\n40,500 LT\nTOPLAM\n*2.025,00');
    expect(f.litersMilli, 40500);
    expect(f.amountKurus, 202500);
  });
  test(
    'Fişten litre ve brüt toplam okunur; KDV, nakit ve para üstü karışmaz',
    () {
      final f = parseFuelReceipt('''
MOTORİN
42,300 LT X 50,00
TOPKDV *352,50
TOPLAM *2.115,00
NAKİT 2500,00
PARA ÜSTÜ 385,00
''');
      expect(f.litersMilli, 42300);
      expect(f.amountKurus, 211500);
    },
  );
  test('Etiketli litre ve noktalı tutar da okunur', () {
    final f = parseFuelReceipt(
      'BENZİN\nLİTRE: 35,250\nTOPLAM TUTAR: 1762.50 TL',
    );
    expect(f.litersMilli, 35250);
    expect(f.amountKurus, 176250);
  });
  test(
    'Birim fiyat litre değildir; farklı toplamlar veya litreler tahmin edilmez',
    () {
      final f = parseFuelReceipt('LPG\nBİRİM FİYAT 25,00 TL/LT\nTOPLAM 500,00');
      expect(f.litersMilli, isNull);
      expect(f.amountKurus, 50000);
      final mixed = parseFuelReceipt(
        'DİZEL\n20 LT\n30 LT\nTOPLAM 1000,00\nSATIŞ TUTARI 2000,00',
      );
      expect(mixed.isEmpty, isTrue);
    },
  );
  test('Yakıt içermeyen, sınır dışı veya belirsiz fişler doldurulmaz', () {
    expect(parseFuelReceipt('MARKET\nTOPLAM 150,00').isEmpty, isTrue);
    final f = parseFuelReceipt('MOTORİN\n1500 LT\nTOPLAM 1.500');
    expect(f.isEmpty, isTrue);
  });
}
