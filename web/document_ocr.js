// Recognition runs inside the user's browser. No document is uploaded.
globalThis.myCarRecognizeDocument = async function (bytes, receiptLayout = false, sparseText = false) {
  if (!globalThis.Tesseract) {
    await new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = new URL('vendor/document-ocr/tesseract.min.js', document.baseURI).href;
      script.onload = resolve;
      script.onerror = () => { script.remove(); reject(new Error('OCR okuyucusu yüklenemedi. İnternet bağlantını kontrol et.')); };
      document.head.appendChild(script);
    });
  }
  const directory = new URL('vendor/document-ocr/', document.baseURI).href;
  const worker = await Tesseract.createWorker('tur+eng', 1, {
    workerPath: directory + 'worker.min.js', corePath: directory,
    langPath: directory + 'languages',
  });
  try {
    if (receiptLayout && sparseText) await worker.setParameters({tessedit_pageseg_mode: Tesseract.PSM.SPARSE_TEXT});
    const result = await worker.recognize(new Blob([bytes]));
    return result.data.text;
  } finally { await worker.terminate(); }
};
