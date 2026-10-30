// Run after npm ci --prefix tool, before flutter build web.
const fs = require('node:fs');
const path = require('node:path');
const destination = path.resolve(__dirname, '../web/vendor/document-ocr');
fs.mkdirSync(destination, {recursive: true});
for (const file of ['tesseract.min.js', 'worker.min.js']) {
  fs.copyFileSync(path.join(__dirname, 'node_modules/tesseract.js/dist', file), path.join(destination, file));
}
const core = path.join(__dirname, 'node_modules/tesseract.js-core');
for (const file of fs.readdirSync(core)) {
  if (/\.wasm(?:\.js)?$/.test(file)) fs.copyFileSync(path.join(core, file), path.join(destination, file));
}
for (const [pkg, target] of [['tesseract.js', 'LICENSE-tesseract'], ['tesseract.js-core', 'LICENSE-core']]) {
  const folder = path.join(__dirname, 'node_modules', pkg);
  const license = fs.existsSync(path.join(folder, 'LICENSE')) ? 'LICENSE' : 'LICENSE.md';
  fs.copyFileSync(path.join(folder, license), path.join(destination, target));
}
console.log('Tarayıcı OCR dosyaları hazır.');
