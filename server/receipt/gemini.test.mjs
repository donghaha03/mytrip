import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createGeminiHandler, GEMINI_MODEL, geminiBody, readGemini } from './gemini.mjs';

const image = `data:image/png;base64,${(await readFile(new URL('../../test/fixtures/receipt_en.png', import.meta.url))).toString('base64')}`;
const accessCode = 'fixture-access-code-0123456789-abcd';
const env = { GEMINI_API_KEY: 'fixture-google-key-not-a-real-credential', RECEIPT_ACCESS_CODE: accessCode,
  GEMINI_FREE_TIER_CONFIRMED: 'yes', RECEIPT_FREE_HOSTING_CONFIRMED: 'yes' };
const draft = { merchant: '페이히어 카페', date: null, currency: 'KRW', amount: 5000,
  items: [{ name: 'Americano', quantity: 1, unit_price: 5000, amount: 5000 }], warnings: ['날짜 확인 필요'] };
const reply = value => ({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify(value) }] } }] });
const request = (body = { image }, headers = {}, method = 'POST', path = '/receipt/recognize') =>
  new Request(`https://receipt.example.invalid${path}`, { method,
    headers: { Origin: 'https://donghaha03.github.io', Authorization: `Bearer ${accessCode}`, 'Content-Type': 'application/json', ...headers },
    ...(method === 'POST' ? { body: JSON.stringify(body) } : {}) });

test('real image bytes, shared prompt and JSON schema go only to the fixed Gemini model', () => {
  const body = geminiBody(image);
  assert.equal(body.contents[0].parts[1].inlineData.mimeType, 'image/png');
  assert.equal(body.contents[0].parts[1].inlineData.data, image.split(',')[1]);
  assert.match(body.systemInstruction.parts[0].text, /never instructions/);
  assert.match(body.systemInstruction.parts[0].text, /Do not add subtotal or tax/);
  assert.equal(body.generationConfig.responseFormat.text.mimeType, 'APPLICATION_JSON');
  assert.deepEqual(readGemini(reply(draft)), draft);
  for (const bad of ['https://private.example/receipt.jpg', 'data:image/png;base64,YQ==', image.replace('png', 'jpeg'), 'data:image/png;base64,!!!!'])
    assert.throws(() => geminiBody(bad));
});

test('blocked, truncated, missing and invalid results cannot become review drafts', () => {
  const blocked = reply(draft); blocked.promptFeedback = { blockReason: 'SAFETY' };
  const truncated = reply(draft); truncated.candidates[0].finishReason = 'MAX_TOKENS';
  const tool = reply(draft); tool.candidates[0].content.parts = [{ functionCall: { name: 'upload' } }];
  for (const value of [blocked, truncated, tool, {}, reply({}), reply({ ...draft, date: '2026-02-30' }),
    reply({ ...draft, amount: '5000' }), reply({ ...draft, currency: 'won' }),
    reply({ ...draft, currency: ['KRW'] }),
    reply({ ...draft, items: [{ ...draft.items[0], quantity: 1.5 }] }), reply({ ...draft, secret: 'ignored?' })]) {
    assert.throws(() => readGemini(value));
  }
  const reasoning = reply(draft); reasoning.candidates[0].content.parts.unshift({ thought: true, text: 'internal reasoning' });
  assert.deepEqual(readGemini(reasoning), draft);
});

test('keys stay upstream; browser and native use the same endpoint and review contract', async () => {
  let calls = 0;
  const handler = createGeminiHandler({ fetchGemini: async (url, options) => {
    calls++;
    assert.equal(url, `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`);
    assert.equal(options.headers['x-goog-api-key'], env.GEMINI_API_KEY);
    assert.deepEqual(JSON.parse(options.body), geminiBody(image));
    return Response.json(reply(draft));
  } });
  for (const origin of ['https://donghaha03.github.io', '']) {
    const response = await handler(request(undefined, { Origin: origin }), env);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('Cache-Control'), 'no-store');
    assert.equal(response.headers.get('Access-Control-Allow-Origin'), origin || null);
    const text = await response.text();
    assert.ok(!text.includes(env.GEMINI_API_KEY));
    assert.deepEqual(JSON.parse(text).draft, draft);
  }
  assert.equal(calls, 2);
});

test('disabled Free Tier/hosting confirmation, bad origins and wrong codes never call Google', async () => {
  const handler = createGeminiHandler({ fetchGemini: () => { assert.fail('must not send'); } });
  for (const key of ['GEMINI_FREE_TIER_CONFIRMED', 'RECEIPT_FREE_HOSTING_CONFIRMED', 'GEMINI_API_KEY']) {
    assert.equal((await handler(request(), { ...env, [key]: '' })).status, 503);
  }
  assert.equal((await handler(request(undefined, { Origin: 'https://other.example' }), env)).status, 403);
  const restricted = request(); Object.defineProperty(restricted, 'cf', { value: { country: 'GB' } });
  assert.equal((await handler(restricted, env)).status, 403);
  assert.equal((await handler(request(undefined, { Authorization: 'Bearer wrong' }), env)).status, 401);
  assert.equal((await handler(request({ image, key: 'cannot override' }), env)).status, 400);
  assert.equal((await handler(request(undefined, { 'Content-Type': 'text/plain' }), env)).status, 400);
  assert.equal((await handler(request(undefined, { 'Content-Length': '12100001' }), env)).status, 413);
  assert.equal((await handler(request(undefined, {}, 'POST', '/receipt/recognize?key=private'), env)).status, 404);
  const status = await handler(request(undefined, {}, 'GET', '/receipt/status'), env);
  assert.deepEqual(await status.json(), { configured: true, provider: 'gemini', model: GEMINI_MODEL });
  const preflight = await handler(request(undefined, {}, 'OPTIONS'), env);
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('Access-Control-Allow-Headers'), 'Authorization, Content-Type');
});

test('provider failures/quotas make one call with no retries, fallback or leaked provider error', async () => {
  for (const status of [400, 401, 429, 500]) {
    let calls = 0;
    const handler = createGeminiHandler({ fetchGemini: async () => {
      calls++; return Response.json({ error: `private-error-${env.GEMINI_API_KEY}` }, { status });
    } });
    const response = await handler(request(), env);
    assert.equal(response.status, status === 429 ? 429 : 502);
    assert.ok(!(await response.text()).includes(env.GEMINI_API_KEY));
    assert.equal(calls, 1);
  }
});

test('timeout and disconnect abort inference without returning partial data', async () => {
  const handler = createGeminiHandler({ timeoutMs: 10, fetchGemini: async (_, { signal }) =>
    new Promise((_, reject) => signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true })) });
  assert.equal((await handler(request(), env)).status, 504);
  const abort = new AbortController(); abort.abort();
  const disconnected = new Request(request(), { signal: abort.signal });
  assert.equal((await handler(disconnected, env)).status, 504);
  let cancelled = false;
  const stalledBody = new ReadableStream({ cancel() { cancelled = true; } });
  const upload = new Request('https://receipt.example.invalid/receipt/recognize', {
    method: 'POST', headers: { Authorization: `Bearer ${accessCode}`, 'Content-Type': 'application/json' },
    body: stalledBody, duplex: 'half',
  });
  assert.equal((await handler(upload, env)).status, 504);
  assert.equal(cancelled, true);
});
