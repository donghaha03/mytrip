// Manual Gemini vs Claude Haiku comparison on the repository's synthetic, privacy-free fixtures only.
// Each Claude call is billed (~$0.001). No retries; a failed call is reported, never scored as a pass.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { setTimeout as delay } from 'node:timers/promises';

const url = new URL(process.env.RECEIPT_SERVER_URL ?? 'https://unset.invalid');
const code = process.env.RECEIPT_ACCESS_CODE ?? '';
assert.ok(url.protocol === 'https:' && url.hostname !== 'unset.invalid' && url.pathname === '/' && !url.search, 'Set RECEIPT_SERVER_URL.');
assert.ok(/^[A-Za-z0-9_-]{32,128}$/.test(code), 'Set RECEIPT_ACCESS_CODE (prepare-access.ps1 -Copy).');
const status = await (await fetch(new URL('/receipt/status', url), { signal: AbortSignal.timeout(10000) })).json();
assert.equal(status.configured, true, 'Gemini is not configured on the server.');
assert.equal(status.claude, true, 'Deploy this branch and set the ANTHROPIC_API_KEY secret first.');

// [file, merchant, amount, category, currency, items?]
const cases = [
  ['receipt_en.png', 'TEST CAFE', 11000, '식비', 'KRW'],
  ['receipt_landscape.png', '테스트 카페', 5000, '식비', 'KRW', [['Americano', 1, 5000]]],
  ['receipt_food.png', 'SAMPLE STORE', 13000, '식비', 'KRW', [['Steak', 1, 10000], ['Milk', 1, 2000], ['Rice', 1, 1000]]],
  ['receipt_transport.png', 'SAMPLE STORE', 5000, '교통', 'KRW'],
  ['receipt_shopping.png', 'SAMPLE STORE', 10000, '쇼핑', 'KRW'],
  ['receipt_tax_free.png', 'SAMPLE TAX FREE', 9500, '쇼핑', 'KRW'],
  ['receipt_consumption_tax.png', 'SAMPLE STORE', 10800, '쇼핑', 'JPY'],
  ['receipt_adjustments.png', 'SAMPLE CAFE', 12000, '식비', 'KRW'],
];
let callsInBucket = 5; // The server allows 5 calls/minute per client; both providers share it.
async function pace() {
  if (callsInBucket >= 5) { const pause = 60_000 - Date.now() % 60_000; console.log(`  (quota pacing: waiting ${Math.ceil(pause / 1000)}s)`); await delay(pause + 50); callsInBucket = 0; }
  callsInBucket++;
}
const totals = { gemini: { ok: 0, fields: 0, ms: [] }, claude: { ok: 0, fields: 0, ms: [] } };
const fieldCount = cases.reduce((sum, c) => sum + (c[5] ? 6 : 5), 0);
for (const [file, merchant, amount, category, currency, items] of cases) {
  const image = `data:image/png;base64,${(await readFile(new URL(`../../test/fixtures/${file}`, import.meta.url))).toString('base64')}`;
  const line = [file.padEnd(28)];
  for (const [provider, path] of [['gemini', '/receipt/recognize'], ['claude', '/receipt/claude']]) {
    await pace();
    const started = Date.now();
    const response = await fetch(new URL(path, url), { method: 'POST', signal: AbortSignal.timeout(90000),
      headers: { Authorization: `Bearer ${code}`, 'Content-Type': 'application/json', Origin: 'https://donghaha03.github.io' },
      body: JSON.stringify({ image }) });
    const ms = Date.now() - started;
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) { line.push(`${provider} FAIL ${response.status} ${/^[A-Z_]{1,40}$/.test(payload.reason ?? '') ? payload.reason : ''}`.padEnd(34)); continue; }
    const d = payload.draft;
    const checks = { merchant: d.merchant === merchant, date: d.date === '2026-10-04', currency: d.currency === currency,
      amount: d.amount === amount, category: d.category === category,
      ...(items ? { items: JSON.stringify(d.items.map(i => [i.name, i.quantity, i.amount])) === JSON.stringify(items) } : {}) };
    const passed = Object.values(checks).filter(Boolean).length;
    totals[provider].ok++; totals[provider].fields += passed; totals[provider].ms.push(ms);
    const missed = Object.keys(checks).filter(key => !checks[key]);
    line.push(`${provider} ${passed}/${Object.keys(checks).length} ${ms}ms${missed.length ? ` ✗${missed.join(',')}` : ''}`.padEnd(34));
  }
  console.log(line.join(' '));
}
for (const [provider, t] of Object.entries(totals)) {
  const avg = t.ms.length ? Math.round(t.ms.reduce((a, b) => a + b, 0) / t.ms.length) : '-';
  console.log(`${provider.padEnd(7)} responses ${t.ok}/${cases.length}, fields correct ${t.fields}/${fieldCount}, avg ${avg}ms`);
}
console.log('Synthetic, clear fixtures only: do not present this as real-world accuracy.');
