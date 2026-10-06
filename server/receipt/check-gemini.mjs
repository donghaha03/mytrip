// Explicit live check: sends only the repository's synthetic, privacy-free fixtures.
// Never runs in CI and never reads or transmits the user's real receipt photos.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { GEMINI_MODEL, CONSENT_VERSION } from './gemini.mjs';

const url = new URL(process.env.RECEIPT_SERVER_URL ?? 'https://unset.invalid');
if (url.protocol !== 'https:' || url.hostname === 'unset.invalid' || url.username || url.password || url.search || url.hash || url.pathname !== '/')
  throw new Error('Set the deployed HTTPS RECEIPT_SERVER_URL.');
const status = await fetch(new URL('/receipt/status', url), { signal: AbortSignal.timeout(10000) });
const configuration = await status.json();
assert.equal(configuration.configured, true, 'Server secrets/free-tier confirmations are missing.');
assert.equal(configuration.provider, 'gemini');
assert.equal(configuration.model, GEMINI_MODEL);
for (const [file, merchant, total, category] of [
  ['receipt_en.png', 'TEST CAFE', 11000, '식비'], ['receipt_landscape.png', '테스트 카페', 5000, '식비'],
  ['receipt_food.png', 'SAMPLE STORE', 13000, '식비'],
  ['receipt_transport.png', 'SAMPLE STORE', 5000, '교통'],
  ['receipt_shopping.png', 'SAMPLE STORE', 10000, '쇼핑'],
]) {
  const image = `data:image/png;base64,${(await readFile(new URL(`../../test/fixtures/${file}`, import.meta.url))).toString('base64')}`;
  const started = Date.now();
  const response = await fetch(new URL('/receipt/recognize', url), {
    method: 'POST', headers: { 'X-Receipt-Consent': CONSENT_VERSION, 'Content-Type': 'application/json', Origin: 'https://donghaha03.github.io' },
    body: JSON.stringify({ image }), signal: AbortSignal.timeout(90000),
  });
  const payload = await response.json().catch(() => ({}));
  const reason = /^[A-Z_]{1,40}$/.test(payload.reason ?? '') ? payload.reason : 'UNKNOWN';
  assert.equal(response.status, 200, `Live recognition failed (${response.status}, provider ${Number(payload.providerStatus) || 0}, ${reason}); no retry/fallback was sent.`);
  const { draft, model } = payload;
  assert.equal(model, GEMINI_MODEL);
  assert.equal(draft.merchant, merchant);
  assert.equal(draft.date, '2026-10-04');
  assert.equal(draft.currency, 'KRW');
  assert.equal(draft.amount, total, 'Subtotal/tax must not be added to final total.');
  assert.equal(draft.category, category, 'Merchant and purchased items must inform category.');
  if (file === 'receipt_landscape.png') {
    assert.equal(draft.items.length, 1);
    assert.equal(draft.items[0].name, 'Americano');
    assert.equal(draft.items[0].quantity, 1);
    assert.equal(draft.items[0].amount, 5000);
  }
  if (file === 'receipt_food.png') {
    assert.deepEqual(draft.items.map(item => [item.name, item.quantity, item.amount]),
      [['Steak', 1, 10000], ['Milk', 1, 2000], ['Rice', 1, 1000]]);
  }
  console.log(`${file}: live ${GEMINI_MODEL}, ${merchant}, ${total} KRW, ${category}, ${Date.now() - started}ms — verified without access code`);
}
