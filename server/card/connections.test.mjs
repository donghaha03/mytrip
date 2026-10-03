import test from 'node:test';
import assert from 'node:assert/strict';
import { constants, generateKeyPairSync, privateDecrypt } from 'node:crypto';
import { createServer } from 'node:http';
import { Readable } from 'node:stream';
import { createConnections, consentVersion, checkAccountResult, ownedCards, encryptPassword } from './connections.mjs';
import { createHandler } from './http.mjs';
import { parseApprovals } from './sync.mjs';

const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const pem = publicKey.export({ type: 'spki', format: 'pem' });
const timestamp = value => ({ toMillis: () => value, toDate: () => new Date(value) });
const trip = { start: timestamp(Date.UTC(2026, 9, 1)), end: timestamp(Date.UTC(2026, 9, 5)) };
const accountResult = (organization = '0303', extra = {}) => ({ result: { code: 'CF-00000' },
  data: { connectedId: 'provider-test-id', successList: [{ countryCode: 'KR', businessType: 'CD', clientType: 'P', organization, code: 'CF-00000' }], errorList: [], ...extra } });
const cardsResult = { result: { code: 'CF-00000' }, data: [{ resCardNo: '1234567812345678', resCardName: '본인 카드' }] };
const input = { tripId: 't1', organization: '0303', loginId: 'test-card-user', password: 'test-card-password', consent: true, consentVersion };

// 실제 자격증명 없이 서버의 UID 결속·철회·데이터 최소화를 검사한다.
function database() {
  const rows = new Map([['users/u1/trips/t1', trip]]);
  const ref = path => ({ path, collection: name => collection(`${path}/${name}`),
    get: async () => ({ exists: rows.has(path), data: () => rows.get(path) }),
    set: async (value, options) => rows.set(path, options?.merge ? { ...rows.get(path), ...value } : value),
    update: async value => { assert.ok(rows.has(path)); rows.set(path, { ...rows.get(path), ...value }); },
    delete: async () => rows.delete(path) });
  const collection = path => ({ doc: id => ref(`${path}/${id}`) });
  return { rows, collection, runTransaction: async work => work({
    get: value => value.get(), set: (value, data, options) => value.set(data, options), update: (value, data) => value.update(data),
  }) };
}

test('CODEF RSA 규약과 보유카드·계정 결과를 검증하고 공개 응답에는 번호를 노출하지 않는다', () => {
  const cipher = encryptPassword(pem, input.password);
  const plain = privateDecrypt({ key: privateKey, padding: constants.RSA_NO_PADDING }, Buffer.from(cipher, 'base64'));
  assert.equal(plain[0], 0); assert.equal(plain[1], 2);
  const separator = plain.indexOf(0, 2);
  assert.ok(separator >= 10);
  assert.equal(plain.subarray(separator + 1).toString(), input.password);
  assert.throws(() => encryptPassword('invalid key', input.password));
  assert.equal(checkAccountResult(accountResult(), '0303').connectedId, 'provider-test-id');
  assert.throws(() => checkAccountResult(accountResult('0306'), '0303'));
  assert.throws(() => checkAccountResult(accountResult('0303', { errorList: [{ code: 'CF-ERROR' }] }), '0303'));
  const cards = ownedCards(cardsResult);
  assert.equal(cards[0].masked, '•••• 5678');
  assert.equal(ownedCards({ ...cardsResult, data: cardsResult.data[0] }).length, 1);
  assert.throws(() => ownedCards({ ...cardsResult, data: [...cardsResult.data, ...cardsResult.data] }));
  assert.throws(() => ownedCards({ result: { code: 'CF-ERROR' }, data: cardsResult.data }));
});

test('동의→본인 인증→카드 선택을 UID·기간에 결속하고 여행 삭제 뒤에도 제공자 계정을 철회한다', async () => {
  const db = database();
  const calls = [];
  let failDelete = false;
  const provider = async (payload, path) => {
    calls.push({ payload, path });
    if (path === '/v1/account/create') {
      assert.notEqual(payload.accountList[0].password, input.password);
      assert.equal(payload.accountList[0].loginType, '1');
      return accountResult();
    }
    if (path === '/v1/kr/card/p/account/card-list') return cardsResult;
    assert.equal(path, '/v1/account/delete');
    assert.equal(db.rows.get('_private_card_links/u1').enabled, false);
    if (failDelete) throw new Error('provider secret must not leak');
    return accountResult();
  };
  const connect = createConnections({ db, provider, publicKey: pem, timestamp });
  await assert.rejects(connect('u1', 'authenticate', { ...input, consent: false }), { status: 400 });
  await assert.rejects(connect('u2', 'authenticate', input), { status: 404 });
  assert.equal(calls.length, 0);
  const response = await connect('u1', 'authenticate', input);
  assert.equal(JSON.stringify(response).includes('1234567812345678'), false);
  assert.equal(JSON.stringify(db.rows.get('_private_card_links/u1')).includes(input.password), false);
  assert.equal(db.rows.get('_private_card_links/u1').loginId, undefined);
  assert.equal((await connect('u1', 'status', { tripId: 't1' })).connected, false);
  await assert.rejects(connect('u1', 'authenticate', input), { status: 409 });
  await assert.rejects(connect('u1', 'select', { tripId: 't1', cardKey: 'foreign-card' }), { status: 400 });
  db.rows.set('users/u1/trips/t1', { ...trip, end: timestamp(trip.end.toMillis() + 86400000) });
  await assert.rejects(connect('u1', 'select', { tripId: 't1', cardKey: response.cards[0].key }), { status: 409 });
  db.rows.set('users/u1/trips/t1', trip);
  assert.deepEqual(await connect('u1', 'select', { tripId: 't1', cardKey: response.cards[0].key }), { connected: true });
  assert.equal(db.rows.get('_private_card_links/u1').pendingCards.length, 0);
  assert.equal((await connect('u1', 'status', { tripId: 't1' })).connected, true);
  assert.equal((await connect('u2', 'status', {})).otherTrip, false);
  db.rows.delete('users/u1/trips/t1');
  assert.equal((await connect('u1', 'status', {})).otherTrip, true);
  failDelete = true;
  await assert.rejects(connect('u1', 'disconnect', {}), { status: 502 });
  assert.equal((await connect('u1', 'status', {})).revoking, true);
  assert.equal(db.rows.get('_private_card_links/u1').enabled, false);
  failDelete = false;
  await connect('u1', 'disconnect', {});
  assert.equal(db.rows.has('_private_card_links/u1'), false);
});

test('보유카드 조회 실패도 해제할 수 있고 인증 반복·선택 만료·잠금 중 요청을 차단한다', async () => {
  const db = database();
  let calls = 0;
  const connect = createConnections({ db, publicKey: pem, timestamp, provider: async (_, path) => {
    calls++;
    return path === '/v1/kr/card/p/account/card-list' ? { result: { code: 'CF-ERROR' } } : accountResult();
  } });
  await assert.rejects(connect('u1', 'authenticate', input), { status: 422 });
  assert.equal((await connect('u1', 'status', { tripId: 't1' })).pending, true);
  await connect('u1', 'disconnect', {});
  const ref = db.collection('_private_card_links').doc('u1');
  await ref.set({ authAttempt: timestamp(Date.now()), authAttempts: 1 });
  await assert.rejects(connect('u1', 'authenticate', input), { status: 429 });
  await ref.set({ authAttempts: 3 });
  await assert.rejects(connect('u1', 'authenticate', input), { status: 423 });
  await ref.set({ ...input, connectedId: 'test', tripId: 't1', pendingUntil: timestamp(0) });
  await assert.rejects(connect('u1', 'select', { tripId: 't1', cardKey: 'expired' }), { status: 409 });
  await ref.update({ lockUntil: timestamp(Date.now() + 60000) });
  await assert.rejects(connect('u1', 'disconnect', {}), { status: 429 });
  assert.equal(calls, 3);
});

test('연결 HTTP는 승인된 UID와 정해진 입력만 받으며 오류의 인증정보를 숨긴다', async t => {
  let calls = 0;
  const server = createServer(createHandler({ allowedOrigin: 'https://donghaha03.github.io', allowedUids: new Set(['u1']),
    verifyToken: async token => ({ uid: token }), synchronize: async () => ({}), connections: async (uid, action, body) => {
      calls++; assert.equal(uid, 'u1');
      if (action === 'authenticate') { assert.equal(body.tripId, 't1'); throw new Error('secret credential'); }
      return { connected: false };
    } }));
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const send = (action, body, token = 'u1') => fetch(`http://127.0.0.1:${server.address().port}/connection/${action}`,
    { method: 'POST', headers: { Authorization: `Bearer ${token}` }, body: JSON.stringify(body) });
  assert.equal((await send('status', {}, 'u2')).status, 403);
  assert.equal((await send('status', { uid: 'victim' })).status, 400);
  assert.equal((await send('select', { cardKey: 'x' })).status, 400);
  assert.equal((await send('status', {})).status, 200);
  const response = await send('authenticate', input);
  assert.equal(response.status, 502);
  assert.equal((await response.text()).includes('secret credential'), false);
  assert.equal(calls, 2);
});

test('동의한 기간 밖의 승인 내역은 합계에 넣지 않고 보류한다', () => {
  const row = { resUsedDate: '20261003', resUsedTime: '123456', resCardNo: 'masked-card', resApprovalNo: '123',
    resMemberStoreName: '테스트 가맹점', resAccountCurrency: 'KRW', resUsedAmount: '1000', resCancelYN: '0' };
  const result = parseApprovals({ result: { code: 'CF-00000' }, data: [row, { ...row, resUsedDate: '20260930' }] },
    '0303', { firstDate: '20261001', lastDate: '20261005' });
  assert.equal(result.records.length, 1); assert.equal(result.skipped, 1);
});

test('분할된 UTF-8 인증 입력은 깨지지 않고 잘못된 바이트는 인증 전에 거절한다', async () => {
  const bytes = Buffer.from(JSON.stringify({ ...input, password: '가나다-test' }));
  const cut = bytes.indexOf(Buffer.from('가')) + 1;
  const handler = createHandler({ verifyToken: async () => ({ uid: 'u1' }), allowedUids: new Set(['u1']),
    connections: async (_, action, data) => { assert.equal(action, 'authenticate'); assert.equal(data.password, '가나다-test'); return {}; } });
  async function send(chunks) {
    const req = Object.assign(Readable.from(chunks), { method: 'POST', url: '/connection/authenticate', headers: { authorization: 'Bearer test-token' } });
    let code;
    const res = { setHeader() {}, writeHead(value) { code = value; return this; }, end() {} };
    await handler(req, res);
    return code;
  }
  assert.equal(await send([bytes.subarray(0, cut), bytes.subarray(cut)]), 200);
  assert.equal(await send([Buffer.from([0xff])]), 400);
});
