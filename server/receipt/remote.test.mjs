import assert from 'node:assert/strict';
import test from 'node:test';
import http from 'node:http';
import { createRemoteHandler, remoteConfig } from './remote.mjs';
import { inferenceBody, MODEL } from './index.mjs';

const accessCode = 'fixture-access-code-0123456789-abcd';
const origin = 'https://donghaha03.github.io';
const image = 'data:image/png;base64,YQ==';
const draft = { merchant: '페이히어 카페', date: null, currency: 'KRW', amount: 5000,
  items: [{ name: 'Americano', quantity: 1, unit_price: 5000, amount: 5000 }], warnings: ['날짜 확인 필요'] };
const event = value => `data: ${JSON.stringify(value)}\n\n`;
const output = () => new Response(event({ type: 'response.output_text.delta', delta: JSON.stringify(draft) }) +
  event({ type: 'response.completed', response: { status: 'completed' } }));

async function runtime(t, options = {}) {
  const server = http.createServer(createRemoteHandler({ apiKey: 'fixture-provider-key', accessCode,
    allowedOrigins: [origin], dailyLimit: 3, fetchOpenAI: async () => output(), ...options }));
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const url = `http://127.0.0.1:${server.address().port}/receipt/recognize`;
  return { url, post: (headers = {}, body = { image }) => fetch(url, { method: 'POST', headers: {
    Origin: origin, Authorization: `Bearer ${accessCode}`, 'Content-Type': 'application/json', ...headers,
  }, body: JSON.stringify(body) }) };
}

test('public runtime cannot start without explicit API billing approval and server secrets', () => {
  assert.throws(() => remoteConfig({}), /비용 승인/);
  assert.throws(() => remoteConfig({ RECEIPT_ALLOW_API_BILLING: 'yes' }), /OPENAI_API_KEY/);
  assert.throws(() => remoteConfig({ RECEIPT_ALLOW_API_BILLING: 'yes', OPENAI_API_KEY: 'fixture' }), /32자/);
  const env = { RECEIPT_ALLOW_API_BILLING: 'yes', OPENAI_API_KEY: 'fixture', RECEIPT_ACCESS_CODE: accessCode };
  assert.equal(remoteConfig(env).dailyLimit, 50);
  for (const value of ['*', 'https://example.invalid/path', 'ftp://localhost']) {
    assert.throws(() => remoteConfig({ ...env, RECEIPT_ALLOWED_ORIGINS: value }));
  }
  assert.throws(() => remoteConfig({ ...env, RECEIPT_DAILY_LIMIT: '0' }));
});

test('web, installed-app and local clients send exactly the same image request; no credentials in output', async t => {
  const sent = [];
  const service = await runtime(t, { fetchOpenAI: async (url, options) => {
    assert.equal(url, 'https://api.openai.com/v1/responses');
    assert.equal(options.headers.Authorization, 'Bearer fixture-provider-key');
    sent.push(JSON.parse(options.body)); return output();
  } });
  for (const headers of [{}, { Origin: '' }]) {
    const response = await service.post(headers);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    const body = await response.json(); assert.deepEqual(body, { draft, model: MODEL });
    assert.doesNotMatch(JSON.stringify(body), /fixture-provider-key|fixture-access-code/);
  }
  assert.deepEqual(sent[0], inferenceBody(image)); assert.deepEqual(sent[0], sent[1]);
  assert.equal(sent[0].store, false); assert.equal(sent[0].stream, true);
});

test('CORS preflight is allowed only for configured origins; authentication precedes paid work', async t => {
  let calls = 0;
  const { url, post } = await runtime(t, { fetchOpenAI: async () => { calls++; return output(); } });
  const preflight = await fetch(url, { method: 'OPTIONS', headers: { Origin: origin } });
  assert.equal(preflight.status, 204); assert.equal(preflight.headers.get('access-control-allow-origin'), origin);
  assert.equal((await post({ Origin: 'https://evil.invalid' })).status, 403);
  assert.equal((await post({ Authorization: '' })).status, 401);
  assert.equal((await post({ Authorization: 'Bearer wrong' })).status, 401);
  assert.equal((await post({ 'Content-Type': 'text/plain' })).status, 400);
  assert.equal((await post({}, { image, model: 'different' })).status, 400);
  assert.equal((await post({}, { image: 'https://evil.invalid/receipt' })).status, 400);
  assert.equal(calls, 0);
});

test('daily quota counts failed upstream requests and never retries or falls back', async t => {
  let calls = 0;
  const { post } = await runtime(t, { dailyLimit: 1, fetchOpenAI: async () => {
    calls++; return new Response('private-provider-error fixture-provider-key', { status: 401 });
  } });
  const response = await post(); assert.equal(response.status, 502);
  assert.doesNotMatch(await response.text(), /private-provider-error|fixture-provider-key/);
  assert.equal((await post()).status, 429); assert.equal(calls, 1);
});

test('a concurrent request cannot multiply an inference or its charge', async t => {
  let release, started;
  const begin = new Promise(resolve => { started = resolve; });
  const { post } = await runtime(t, { fetchOpenAI: async () => {
    started(); await new Promise(resolve => { release = resolve; }); return output();
  } });
  const first = post(); await begin;
  assert.equal((await post()).status, 429); release(); assert.equal((await first).status, 200);
});

test('provider timeout aborts inference and incomplete streams never return a review draft', async t => {
  let aborted = false;
  const timed = await runtime(t, { timeoutMs: 15, fetchOpenAI: async (_url, { signal }) => new Promise((_resolve, reject) => {
    signal.addEventListener('abort', () => { aborted = true; reject(new Error('timeout')); });
  }) });
  assert.equal((await timed.post()).status, 504); assert.equal(aborted, true);
  const incomplete = await runtime(t, { fetchOpenAI: async () => new Response(event({ type: 'response.output_text.delta', delta: JSON.stringify(draft) })) });
  assert.equal((await incomplete.post()).status, 502);
});
