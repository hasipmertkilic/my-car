const fs = require('node:fs');
const path = require('node:path');
const {createWorker, PSM} = require('tesseract.js');
async function read(file, mode) {
  const worker = await createWorker('tur+eng', 1, {
    langPath: path.resolve(__dirname, '../web/vendor/document-ocr/languages'), cacheMethod:'none',
  });
  try {
    await worker.setParameters({tessedit_pageseg_mode: mode});
    return (await worker.recognize(file)).data.text;
  } finally { await worker.terminate(); }
}
(async () => {
    const count = Number(process.argv[3] || 3);
    const output = path.resolve(process.argv[4] || path.join(__dirname, '../build/receipt-validation'));
    const samples = [];
    for (let i = 1; i <= count; i++) {
      const prepared = await read(path.join(output, `${i}.png`), PSM.SPARSE_TEXT);
      const original = await read(path.join(process.argv[2], `${i}.jpg`), PSM.SINGLE_BLOCK);
      samples.push({prepared, original});
    }
    fs.writeFileSync(path.join(output, 'results.json'), JSON.stringify(samples));
    console.log('Yerel OCR tamamlandı; ham metin günlüğe yazılmadı.');
})().catch(() => { console.error('Yerel örnek okuma başarısız.'); process.exitCode = 1; });
