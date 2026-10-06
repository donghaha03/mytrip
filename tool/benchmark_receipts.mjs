// Manual, real-engine comparison. Sends only these synthetic repository fixtures.
// Tesseract 6.0.1 is installed in a temporary directory, not in the app.
import { createRequire } from 'node:module';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve, dirname } from 'node:path';
import assert from 'node:assert/strict';
import { GEMINI_MODEL } from '../server/receipt/gemini.mjs';
const require = createRequire(import.meta.url);
const modulePath = process.env.TESSERACT_MODULE;
assert.ok(modulePath, 'Set TESSERACT_MODULE to a temporary installation of tesseract.js 6.0.1.');
const { createWorker } = require(modulePath);
assert.equal(require(resolve(dirname(modulePath), '../package.json')).version, '6.0.1');
const ocrRoot = resolve('web/ocr');
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const corePath = require.resolve('tesseract.js-core/tesseract-core-simd-lstm.wasm', { paths: [dirname(modulePath)] });
assert.equal(sha256(await readFile(corePath)), sha256(await readFile(resolve(ocrRoot, 'core/tesseract-core-simd-lstm.wasm'))), 'Use the exact bundled WASM engine.');
const output = { measuredAt: new Date().toISOString(), model: GEMINI_MODEL,
  runtime: 'Node.js real Tesseract.js 6.0.1; same bundled WASM and language data, not browser timing',
  fixtures: [] };
const url = process.env.RECEIPT_SERVER_URL && new URL(process.env.RECEIPT_SERVER_URL);
const code = process.env.RECEIPT_ACCESS_CODE;
if (url) {
  assert.ok(url.protocol === 'https:' && !url.username && !url.password && !url.search && !url.hash && url.pathname === '/');
  assert.ok(/^[A-Za-z0-9_-]{32,128}$/.test(code ?? '') && !/^(AIza|sk-)/.test(code));
  const health = await (await fetch(new URL('/receipt/status', url))).json();
  assert.equal(health.configured, true); assert.equal(health.model, GEMINI_MODEL);
}
const started = Date.now();
const worker = await createWorker(['eng', 'kor'], 1, { langPath: resolve(ocrRoot, 'lang'), gzip: false, cacheMethod: 'none', logger: () => {} });
output.tesseractStartupMs = Date.now() - started;
await worker.setParameters({ tessedit_pageseg_mode: '6', preserve_interword_spaces: '1' });
const fixtures = [
  ['receipt_en.png', { merchant: 'TEST CAFE', date: '2026-10-04', currency: 'KRW', amount: 11000 }],
  ['receipt_landscape.png', { merchant: '테스트 카페', date: '2026-10-04', currency: 'KRW', amount: 5000,
    item: { name: 'Americano', quantity: 1, amount: 5000 } }],
  ['receipt_blank.png', null],
];
// Optional original PayHere reference stays local. Never send it to Google.
if (process.env.RECEIPT_REFERENCE_FILE) fixtures.push(['payhere-reference-local-only', {
  merchant: '페이히어 카페', currency: 'KRW', amount: 5000,
  item: { name: 'Americano', quantity: 1, amount: 5000 },
}]);
try {
  for (const [file, expected] of fixtures) {
    const localOnly = file === 'payhere-reference-local-only';
    const bytes = await readFile(localOnly ? process.env.RECEIPT_REFERENCE_FILE : resolve('test/fixtures', file));
    const row = { file, sha256: sha256(bytes), expected };
    const start = Date.now();
    const { data } = await worker.recognize(bytes);
    row.tesseract = { text: data.text, confidence: data.confidence, elapsedMs: Date.now() - start };
    if (url && !localOnly) {
      const start = Date.now();
      const response = await fetch(new URL('/receipt/recognize', url), {
        method: 'POST', headers: { Authorization: `Bearer ${code}`, 'Content-Type': 'application/json', Origin: 'https://donghaha03.github.io' },
        body: JSON.stringify({ image: `data:image/png;base64,${bytes.toString('base64')}` }), signal: AbortSignal.timeout(90000),
      });
      const payload = await response.json().catch(() => ({}));
      row.gemini = { httpStatus: response.status, elapsedMs: Date.now() - start,
        ...(response.ok ? { draft: payload.draft } : { reason: /^[A-Z_]{1,40}$/.test(payload.reason ?? '') ? payload.reason : 'UNKNOWN' }) };
    }
    output.fixtures.push(row);
    console.log(`${file}: real Tesseract complete; Gemini ${row.gemini?.httpStatus ?? 'not run'}`);
  }
} finally { await worker.terminate(); }
await mkdir('.dart_tool', { recursive: true });
await writeFile('.dart_tool/receipt-benchmark.json', JSON.stringify(output, null, 2));
console.log('Results: .dart_tool/receipt-benchmark.json (ignored, local only); no credentials saved.');
