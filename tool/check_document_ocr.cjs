const assert = require('node:assert/strict');
const path = require('node:path');
const {createWorker} = require('tesseract.js');
(async () => {
  const worker = await createWorker('tur+eng', 1, {
    langPath: path.resolve(__dirname, '../web/vendor/document-ocr/languages'),
    cacheMethod: 'none',
  });
  try {
    const {data} = await worker.recognize(path.resolve(__dirname, '../test/fixtures/policy_ocr_sample.png'));
    assert.match(data.text, /TEST-123456/);
    assert.match(data.text, /19\.10\.2027/);
    assert.match(data.text, /12\.500,50/);
    assert.match(data.text, /Sigorta/);
    console.log('Türkçe fotoğraf örneğinde poliçe numarası, tarih ve tutar okundu.');
    const receipt = await worker.recognize(path.resolve(__dirname, '../test/fixtures/fuel_receipt_sample.png'));
    assert.match(receipt.data.text, /42,300/);
    assert.match(receipt.data.text, /2\.115,00/);
    console.log('Yakıt fişi örneğinde litre ve toplam tutar okundu.');
  } finally { await worker.terminate(); }
})().catch(() => { console.error('Fotoğraf okuyucu testi başarısız.'); process.exitCode = 1; });
