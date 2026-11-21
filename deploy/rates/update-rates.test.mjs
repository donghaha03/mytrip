// node --test deploy/rates/update-rates.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { parseRates, toFirestoreFields } from './update-rates.mjs';

const api = {
  result: 'success',
  base_code: 'KRW',
  time_last_update_utc: 'Sat, 21 Nov 2026 00:02:31 +0000',
  rates: { KRW: 1, USD: 0.0007, JPY: 0.11, EUR: 0.00065, bad: 3, XXX: 0, YYY: 'abc' },
};

test('환율 응답을 앱이 읽는 rates/current 형식으로 바꾼다', () => {
  const parsed = parseRates(api);
  // 통화 코드가 아니거나 0 이하·숫자가 아닌 값은 버린다.
  assert.deepEqual(parsed.rates, { KRW: 1, USD: 0.0007, JPY: 0.11, EUR: 0.00065 });

  const fields = toFirestoreFields(parsed, new Date('2026-11-22T03:00:00Z'));
  assert.deepEqual(Object.keys(fields).sort(), [
    'base',
    'lastUpdated',
    'providerLastUpdated',
    'rates',
    'source',
  ]);
  assert.deepEqual(fields.base, { stringValue: 'KRW' });
  // rate_api.dart: data['rates'] is Map, 값은 num > 0
  assert.deepEqual(fields.rates.mapValue.fields.JPY, { doubleValue: 0.11 });
  // rate_api.dart: data['lastUpdated'] is Timestamp
  assert.deepEqual(fields.lastUpdated, { timestampValue: '2026-11-22T03:00:00.000Z' });
  assert.deepEqual(fields.providerLastUpdated, { stringValue: api.time_last_update_utc });
  assert.deepEqual(fields.source, { stringValue: 'open.er-api.com' });
});

test('이상한 응답은 문서를 만들지 않는다', () => {
  assert.throws(() => parseRates({ ...api, result: 'error' }));
  assert.throws(() => parseRates({ ...api, base_code: 'USD' }));
  assert.throws(() => parseRates({ ...api, rates: [] }));
  assert.throws(() => parseRates({ ...api, rates: { ...api.rates, KRW: 2 } }));
  assert.throws(() => parseRates({ ...api, rates: { KRW: 1, USD: 0.0007 } }));
  assert.throws(() => parseRates(null));
});
