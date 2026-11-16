// Explicit live check: sends only the repository's synthetic, privacy-free fixtures.
// Never runs in CI and never reads or transmits the user's real receipt photos.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { GEMINI_MODEL, CONSENT_VERSION } from './gemini.mjs';
import { setTimeout as delay } from 'node:timers/promises';

const url = new URL(process.env.RECEIPT_SERVER_URL ?? 'https://unset.invalid');
if (url.protocol !== 'https:' || url.hostname === 'unset.invalid' || url.username || url.password || url.search || url.hash || url.pathname !== '/')
  throw new Error('Set the deployed HTTPS RECEIPT_SERVER_URL.');
const status = await fetch(new URL('/receipt/status', url), { signal: AbortSignal.timeout(10000) });
const configuration = await status.json();
assert.equal(configuration.configured, true, 'Server secrets/free-tier confirmations are missing.');
assert.equal(configuration.provider, 'gemini');
assert.equal(configuration.model, GEMINI_MODEL);
let callsInBucket = 5; // Begin at a fresh bucket, including after an explicit test rerun.
async function pace() {
  if (callsInBucket >= 5) {
    const pause = 60_000 - Date.now() % 60_000;
    console.log(`Waiting ${pause}ms for shared quota; no retry/fallback.`);
    await delay(pause + 50);
    callsInBucket = 0;
  }
  callsInBucket++;
}
const cases = [
  ['receipt_en.png', 'TEST CAFE', 11000, '식비'], ['receipt_landscape.png', '테스트 카페', 5000, '식비'],
  ['receipt_food.png', 'SAMPLE STORE', 13000, '식비'],
  ['receipt_transport.png', 'SAMPLE STORE', 5000, '교통'],
  ['receipt_shopping.png', 'SAMPLE STORE', 10000, '쇼핑'],
  ['receipt_tax_free.png', 'SAMPLE TAX FREE', 9500, '쇼핑'],
  ['receipt_consumption_tax.png', 'SAMPLE STORE', 10800, '쇼핑'],
  ['receipt_adjustments.png', 'SAMPLE CAFE', 12000, '식비'],
];
const only = process.argv[2];
if (only && !cases.some(([file]) => file === only)) throw new Error('Unknown synthetic receipt fixture.');
for (const [file, merchant, total, category] of cases.filter(([file]) => !only || file === only)) {
  await pace();
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
  assert.equal(draft.currency, file === 'receipt_consumption_tax.png' ? 'JPY' : 'KRW');
  assert.equal(draft.amount, total, 'Subtotal/tax must not be added to final total.');
  assert.equal(draft.category, category, 'Merchant and purchased items must inform category.');
  if (file === 'receipt_landscape.png') {
    assert.equal(draft.items.length, 1);
    assert.equal(draft.items[0].name, 'Americano');
    assert.equal(draft.items[0].quantity, 1);
    assert.equal(draft.items[0].amount, 5000);
    assert.equal(draft.taxes.length, 1);
    assert.equal(draft.taxes[0].label, '부가세');
    assert.equal(draft.taxes[0].amount, 455);
    assert.equal(draft.taxes[0].currency, 'KRW');
    assert.ok(draft.taxes[0].included === true || draft.taxes[0].included === null);
  }
  if (file === 'receipt_en.png') {
    assert.equal(draft.taxes.length, 1);
    assert.equal(draft.taxes[0].amount, 1000);
    assert.equal(draft.taxes[0].currency, 'KRW');
    assert.ok(draft.taxes[0].included === true || draft.taxes[0].included === null, 'Unstated inclusion may require review; never fabricate certainty.');
  }
  if (file === 'receipt_tax_free.png') {
    const {details, ...adjustments} = draft.adjustments;
    assert.deepEqual(adjustments, { taxFree: true, exemptedTax: 1000, taxFreeBase: null, discount: 500, currency: 'KRW' });
    assert.deepEqual(details.map(line => [line.kind, line.amount]), [['discount', 500]]);
  }
  if (file === 'receipt_adjustments.png') {
    assert.equal(draft.adjustments.discount, 1500);
    assert.deepEqual(draft.adjustments.details.map(line => [line.kind, line.amount, line.currency]).sort(),
      [['surcharge',1000,'KRW'], ['surcharge',500,'KRW'], ['surcharge',2000,'KRW'], ['discount',1000,'KRW'], ['discount',500,'KRW']].sort());
    assert.deepEqual(draft.taxes, [{label:'부가세',amount:909,currency:'KRW',included:true}]);
    console.log(`Applied charges/discounts: ${draft.adjustments.details.map(line => `${line.label} ${line.amount} ${line.currency}`).join(', ')}; paid amount unchanged.`);
  }
  if (file === 'receipt_consumption_tax.png') {
    assert.deepEqual(draft.taxes, [{ label: '소비세', amount: 800, currency: 'JPY', included: true }]);
  }
  if (file === 'receipt_food.png') {
    assert.deepEqual(draft.items.map(item => [item.name, item.quantity, item.amount]),
      [['Steak', 1, 10000], ['Milk', 1, 2000], ['Rice', 1, 1000]]);
  }
  console.log(`${file}: live ${GEMINI_MODEL}, ${merchant}, ${total} ${draft.currency}, ${category}, ${Date.now() - started}ms — verified without access code`);
}
// Five calls/minute is shared by OCR and translation. Wait for the next bucket,
// never retry or bypass a server rejection to spend more of the free quota.
for (const [language, expected] of only ? [] : [['ko', [/스테이크/, /우유/, /밥|쌀/]], ['en', [/steak/i, /milk/i, /rice/i]]]) {
  await pace();
  const response = await fetch(new URL('/receipt/translate', url), {
    method: 'POST', headers: { 'X-Receipt-Consent': CONSENT_VERSION, 'Content-Type': 'application/json', Origin: 'https://donghaha03.github.io' },
    body: JSON.stringify({ names: ['ステーキ', '牛乳', 'ご飯'], language }), signal: AbortSignal.timeout(90000),
  });
  const payload = await response.json();
  assert.equal(response.status, 200, `Live translation failed (${response.status}); no retry sent.`);
  assert.equal(payload.model, GEMINI_MODEL);
  assert.equal(payload.names.length, expected.length);
  payload.names.forEach((name, index) => assert.match(name, expected[index]));
  console.log(`Live ${language} item translation: ${payload.names.join(', ')} — verified`);
}
