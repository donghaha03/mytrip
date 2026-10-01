import assert from 'node:assert/strict';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';

const currencies = ['USD', 'JPY', 'EUR', 'CNY', 'VND', 'THB', 'PHP', 'HKD', 'SGD',
  'IDR', 'MYR', 'AUD', 'GBP', 'CHF', 'INR', 'CAD', 'NZD', 'TWD', 'MOP'];
const urls = [
  'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/krw.json',
  'https://latest.currency-api.pages.dev/v1/currencies/krw.json',
];

function normalize(data, fetchedAt) {
  assert.match(data.date, /^\d{4}-\d{2}-\d{2}$/);
  const date = new Date(`${data.date}T00:00:00Z`);
  assert.equal(date.toISOString().slice(0, 10), data.date);
  assert.ok(date <= fetchedAt, '환율 기준일이 미래입니다');
  const rates = { KRW: 1 };
  for (const currency of currencies) {
    const value = data.krw?.[currency.toLowerCase()];
    assert.ok(typeof value === 'number' && Number.isFinite(value) && value > 0 &&
      Number.isFinite(1 / value), `${currency} 환율이 올바르지 않습니다`);
    rates[currency] = value;
  }
  return { result: 'success', base_code: 'KRW', rate_date: data.date,
    fetched_at: fetchedAt.toISOString(), rates };
}

if (process.argv.includes('--check')) {
  const countrySource = await readFile(new URL('../lib/trip_home/models/country.dart', import.meta.url), 'utf8');
  const screenCurrencies = [...countrySource.matchAll(/currency:\s*'([A-Z]{3})'/g)].map(m => m[1]);
  assert.deepEqual([...currencies].sort(), screenCurrencies.sort(), '화면과 서버 지원 통화가 다릅니다');
  const at = new Date('2026-10-01T21:00:00Z'); // 한국 시간 다음 날 06시
  const data = { date: '2026-10-01',
    krw: Object.fromEntries(currencies.map(c => [c.toLowerCase(), 0.001])) };
  data.krw.jpy = 1 / 9;
  const result = normalize(data, at);
  assert.equal(result.fetched_at, at.toISOString());
  assert.equal(result.rate_date, '2026-10-01');
  assert.equal(result.rates.KRW, 1);
  assert.equal(1 / result.rates.JPY, 9);
  for (const value of [0, -1, Infinity, NaN, '0.1', undefined]) {
    assert.throws(() => normalize({ ...data, krw: { ...data.krw, jpy: value } }, at));
  }
  assert.throws(() => normalize({ ...data, date: '2026-02-30' }, at));
  assert.throws(() => normalize({ ...data, date: '2026-10-02' }, at));
  console.log('환율 스냅샷 검증 통과');
} else {
  let snapshot;
  for (const url of urls) {
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(12000) });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      snapshot = normalize(await response.json(), new Date());
      break;
    } catch (error) {
      console.error(`환율 조회 실패: ${url}: ${error.message}`);
    }
  }
  if (!snapshot) throw new Error('새 환율을 배포하지 않습니다. 기존 배포는 유지됩니다.');
  const output = process.argv[2] ?? 'build/web/rates.json';
  await mkdir(dirname(output), { recursive: true });
  await writeFile(`${output}.tmp`, `${JSON.stringify(snapshot)}\n`);
  await rename(`${output}.tmp`, output);
  console.log(`환율 기준일 ${snapshot.rate_date}, 서버 갱신 ${snapshot.fetched_at}`);
}
