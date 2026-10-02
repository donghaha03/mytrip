import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createHandler } from './http.mjs';
import { createCodefClient } from './provider.mjs';
import { normalizeApproval, parseApprovals, mergeApproval, mayDuplicateManual, validateTripId, kstDate } from './sync.mjs';

const row = {
  resUsedDate: '20261003', resUsedTime: '123456', resCardNo: '1234********5678',
  resApprovalNo: '00012345', resMemberStoreName: '테스트 가맹점', resAccountCurrency: 'JPY',
  resUsedAmount: '1,000', resCancelYN: '0',
};
const success = data => ({ result: { code: 'CF-00000' }, data });

test('CODEF 단건·다건을 정규화하고 같은 승인 이벤트는 하나로 합친다', () => {
  const record = normalizeApproval(row, '0301');
  assert.equal(record.amount, 1000);
  assert.equal(record.date.toISOString(), '2026-10-03T03:34:56.000Z');
  assert.equal(parseApprovals(success([row, row]), '0301').records.length, 1);
  assert.deepEqual(parseApprovals(success(row), '0301').records, [record]);
  assert.notEqual(record.id, normalizeApproval(row, '0302').id);
  assert.deepEqual(parseApprovals(success([]), '0301'), { records: [], skipped: 0 });
});

test('전체·부분 취소·거절과 사용자 분류·숨김을 보존한다', () => {
  const approved = normalizeApproval(row, '0301');
  const partial = normalizeApproval({ ...row, resCancelYN: '2', resCancelAmount: '500' }, '0301');
  const cancelled = normalizeApproval({ ...row, resCancelYN: '1' }, '0301');
  assert.equal(partial.id, approved.id);
  assert.equal(partial.amount, 500);
  assert.equal(cancelled.amount, 0);
  assert.equal(normalizeApproval({ ...row, resCancelYN: '3' }, '0301').amount, 0);
  const old = { ...approved, category: '쇼핑', memo: '선물', hidden: true, isTaxFree: true };
  const merged = mergeApproval(old, partial);
  assert.equal(merged.memo, '선물'); assert.equal(merged.isTaxFree, true); assert.equal(merged.hidden, true);
  assert.equal(mergeApproval(cancelled, approved).status, 'cancelled');
  assert.equal(mergeApproval(partial, approved).amount, 500);
  assert.equal(parseApprovals(success([row, { ...row, resCancelYN: '1' }, row]), '0301').records[0].status, 'cancelled');
});

test('모호한 해외 통화·승인번호·부분 취소·잘못된 날짜는 등록하지 않는다', () => {
  for (const invalid of [
    { resAccountCurrency: '' }, { resAccountCurrency: 'UNKNOWN' }, { resApprovalNo: '' },
    { resUsedDate: '20260230' }, { resUsedDate: '20261301' }, { resUsedTime: '250000' },
    { resUsedTime: '' }, { resUsedAmount: '-500' }, { resUsedAmount: '12,34' },
    { resCancelYN: '2', resCancelAmount: '' }, { resCancelYN: '2', resCancelAmount: '1001' },
  ]) {
    const parsed = parseApprovals(success([{ ...row, ...invalid }]), '0301');
    assert.equal(parsed.skipped, 1); assert.equal(parsed.records.length, 0);
  }
  assert.throws(() => parseApprovals({ result: { code: 'CF-ERROR' }, data: [] }, '0301'));
  assert.throws(() => validateTripId('../other-user'));
  assert.equal(kstDate(new Date('2026-10-02T16:00:00Z')), '20261003');
});

test('수동 카드 기록과 중복 가능성이 있으면 자동 합치지 않고 보류한다', () => {
  const record = normalizeApproval(row, '0301');
  const manual = { amount: 1000, paymentMethod: 'card', date: record.date };
  assert.equal(mayDuplicateManual(record, [manual], 'JPY'), true);
  assert.equal(mayDuplicateManual(record, [{ ...manual, paymentMethod: 'cash' }], 'JPY'), false);
  assert.equal(mayDuplicateManual(record, [{ ...manual, currency: 'USD' }], 'JPY'), false);
  assert.equal(mayDuplicateManual(record, [{ ...manual, date: new Date(record.date.getTime() - 11 * 60000) }], 'JPY'), false);
});

test('제공자 호출은 토큰 재사용·1회 갱신·URI 인코딩을 지키며 임의 호스트로 보내지 않는다', async () => {
  let tokenCalls = 0, approvalCalls = 0;
  const query = createCodefClient({ clientId: 'test-id', clientSecret: 'test-secret', mode: 'demo',
    fetcher: async (url, options) => {
      assert.equal(options.redirect, 'error');
      if (url.endsWith('/oauth/token')) {
        tokenCalls++;
        assert.equal(options.body, 'grant_type=client_credentials&scope=read');
        return new Response(JSON.stringify({ access_token: `test-token-${tokenCalls}`, expires_in: 3600 }));
      }
      assert.equal(url, 'https://development.codef.io/v1/kr/card/p/account/approval-list');
      assert.deepEqual(JSON.parse(decodeURIComponent(options.body)), { connectedId: 'test-only' });
      approvalCalls++;
      if (approvalCalls === 1) return new Response('', { status: 401 });
      return new Response(encodeURIComponent(JSON.stringify(success([row]))));
    } });
  await query({ connectedId: 'test-only' }); await query({ connectedId: 'test-only' });
  assert.equal(tokenCalls, 2); assert.equal(approvalCalls, 3);
  assert.throws(() => createCodefClient({ clientId: 'x', clientSecret: 'y', mode: 'unsafe' }));
});

test('HTTP는 사용자 토큰·자기 여행만 전달하고 UID 위조·잘못된 요청을 거절한다', async t => {
  let calls = 0;
  const server = createServer(createHandler({ allowedOrigin: 'https://donghaha03.github.io',
    verifyToken: async token => { if (token !== 'test-token') throw new Error('invalid'); return { uid: 'test-user' }; },
    synchronize: async (uid, tripId) => {
      calls++; assert.equal(uid, 'test-user'); assert.equal(tripId, 't2');
      return { received: 1, skipped: 0 };
    } }));
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const url = `http://127.0.0.1:${server.address().port}/sync`;
  async function send(body, headers = {}) {
    return fetch(url, { method: 'POST', headers: { Authorization: 'Bearer test-token', ...headers }, body });
  }
  assert.equal((await send('{"tripId":"t2"}', { Authorization: '' })).status, 401);
  assert.equal((await send('{"tripId":"t2"}', { Origin: 'https://untrusted.invalid' })).status, 403);
  assert.equal((await send('{"tripId":"t2","uid":"victim"}')).status, 400);
  assert.equal((await send('{"tripId":"../victim"}')).status, 400);
  assert.equal((await send('not json')).status, 400);
  assert.equal((await send('x'.repeat(3000))).status, 413);
  const response = await send('{"tripId":"t2"}');
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { received: 1, skipped: 0 });
  assert.equal(calls, 1);
});
