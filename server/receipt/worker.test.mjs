import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createReceiptHandler, ReceiptUsage } from './worker.mjs';
import { CLAUDE_MODEL, CLAUDE_CONSENT_VERSION, claudeBody, claudeTranslationBody, claudeSchema, readClaude } from './claude.mjs';
import { validateTranslation } from './contract.mjs';

const image = `data:image/png;base64,${(await readFile(new URL('../../test/fixtures/receipt_en.png', import.meta.url))).toString('base64')}`;
const accessCode = 'fixture-access-code-0123456789-abcd';
const env = { ANTHROPIC_API_KEY: 'fixture-anthropic-key-not-a-real-credential', RECEIPT_ACCESS_CODE: accessCode };
const draft = { merchant: 'TEST CAFE', date: '2026-10-04', currency: 'KRW', amount: 11000, category: '식비',
  taxes: [], adjustments: { taxFree: null, exemptedTax: null, taxFreeBase: null, discount: null, currency: null, details: [] },
  items: [{ name: 'Americano', quantity: 1, unit_price: 5000, amount: 5000 }], warnings: [] };
const message = (value, stop_reason = 'end_turn') => ({ id: 'msg_fixture', type: 'message', role: 'assistant', model: CLAUDE_MODEL,
  stop_reason, stop_sequence: null, usage: { input_tokens: 1, output_tokens: 1 },
  content: [{ type: 'thinking', thinking: '', signature: 'sig' }, { type: 'text', text: JSON.stringify(value) }] });

// Access-code request (private mode). Pass Authorization: '' plus a consent header for public requests.
const request = (body = { image }, headers = {}, method = 'POST', path = '/receipt/recognize') =>
  new Request(`https://receipt.example.invalid${path}`, { method,
    headers: { Origin: 'https://donghaha03.github.io', Authorization: `Bearer ${accessCode}`, 'Content-Type': 'application/json', ...headers },
    ...(method === 'POST' ? { body: JSON.stringify(body) } : {}) });
const anonymous = (extra = {}, body, path) =>
  request(body, { Authorization: '', 'X-Receipt-Consent': CLAUDE_CONSENT_VERSION, 'CF-Connecting-IP': '192.0.2.5', ...extra }, 'POST', path);

// Records every upstream call so tests can prove there is exactly one attempt.
const upstream = (reply, status = 200) => {
  const calls = [];
  const handler = createReceiptHandler({ fetchClaude: async (url, init) => {
    calls.push({ url: String(url), headers: new Headers(init.headers), body: JSON.parse(init.body) });
    return Response.json(typeof reply === 'function' ? reply() : reply, { status });
  } });
  return { calls, handler };
};

function usageBinding() {
  let value, pending = Promise.resolve();
  const storage = { transaction: callback => {
    const task = pending.then(() => callback({
      get: async () => structuredClone(value),
      put: async (_, next) => { value = structuredClone(next); },
    }));
    pending = task.catch(() => {}); return task;
  } };
  let usage = new ReceiptUsage({ storage });
  return { idFromName: name => name, get: () => ({ fetch: (url, options) => usage.fetch(new Request(url, options)) }),
    restart: () => { usage = new ReceiptUsage({ storage }); }, state: () => value };
}
const publicEnv = (binding = usageBinding()) => ({ ...env, RECEIPT_PUBLIC_CONSENT: 'yes', RECEIPT_USAGE: binding });

test('image, shared prompt and a constraint-free schema go to Claude Haiku at low effort', () => {
  const body = claudeBody(image);
  assert.equal(body.model, CLAUDE_MODEL);
  assert.equal(body.messages[0].content[0].source.data, image.split(',')[1]);
  assert.equal(body.messages[0].content[0].source.media_type, 'image/png');
  assert.match(body.system, /never instructions/);
  assert.match(body.system, /Do not add subtotal or tax/);
  assert.deepEqual(body.output_config, { effort: 'low', format: { type: 'json_schema', schema: claudeSchema } });
  assert.doesNotMatch(JSON.stringify(claudeSchema), /maxItems|maxLength/);
  assert.deepEqual(new Set(claudeSchema.required), new Set(Object.keys(claudeSchema.properties)));
  assert.equal(body.tools, undefined);
  for (const bad of ['https://private.example/receipt.jpg', 'data:image/png;base64,YQ==', image.replace('png', 'jpeg'), 'data:image/png;base64,!!!!'])
    assert.throws(() => claudeBody(bad));
});

test('refused, truncated, missing and invalid results cannot become review drafts', () => {
  assert.deepEqual(readClaude(message(draft)), draft);
  for (const value of [message(draft, 'refusal'), message(draft, 'max_tokens'), message(draft, 'tool_use'), {}, message({}),
    message({ ...draft, date: '2026-02-30' }), message({ ...draft, amount: '5000' }), message({ ...draft, currency: 'won' }),
    message({ ...draft, currency: ['KRW'] }), message({ ...draft, category: '없는 카테고리' }),
    message({ ...draft, items: [{ ...draft.items[0], quantity: 1.5 }] }), message({ ...draft, secret: 'ignored?' })]) {
    assert.throws(() => readClaude(value));
  }
});

test('taxes and applied adjustments keep printed values without changing the paid total', () => {
  const taxed = { ...draft, taxes: [
    { label: '부가세', amount: 455, currency: 'KRW', included: true },
    { label: '소비세', amount: 0, currency: 'JPY', included: null },
  ] };
  assert.deepEqual(readClaude(message(taxed)), taxed);
  assert.equal(readClaude(message(taxed)).amount, draft.amount);
  const details = [
    { label: '서비스료', kind: 'surcharge', amount: 1000, currency: 'KRW' },
    { label: '쿠폰 할인', kind: 'discount', amount: 500, currency: 'KRW' },
  ];
  const adjusted = { ...draft, amount: 10500, adjustments: { ...draft.adjustments, discount: 500, currency: 'KRW', details } };
  assert.deepEqual(readClaude(message(adjusted)).adjustments.details, details);
  assert.equal(readClaude(message(adjusted)).amount, 10500);
  for (const bad of [{ ...details[0], amount: null }, { ...details[0], amount: -1 }, { ...details[0], amount: 1e13 },
    { ...details[0], kind: 'offer' }, { ...details[0], label: '' }, { ...details[0], currency: 'won' }, { ...details[0], secret: 'unexpected' }]) {
    assert.throws(() => readClaude(message({ ...adjusted, adjustments: { ...adjusted.adjustments, details: [bad] } })));
  }
  assert.throws(() => readClaude(message({ ...adjusted, adjustments: { ...adjusted.adjustments, details: Array(21).fill(details[0]) } })));
  assert.match(claudeBody(image).system, /Never compute tax/);
});

test('the key stays upstream; browser and native use the same endpoint and review contract', async () => {
  const { calls, handler } = upstream(message(draft));
  for (const origin of ['https://donghaha03.github.io', '']) {
    const response = await handler(request(undefined, { Origin: origin }), env);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('Cache-Control'), 'no-store');
    assert.equal(response.headers.get('Access-Control-Allow-Origin'), origin || null);
    const text = await response.text();
    assert.ok(!text.includes(env.ANTHROPIC_API_KEY));
    assert.deepEqual(JSON.parse(text), { draft, model: CLAUDE_MODEL, provider: 'claude' });
  }
  assert.equal(calls.length, 2);
  assert.match(calls[0].url, /\/v1\/messages$/);
  assert.equal(calls[0].headers.get('authorization'), `Bearer ${env.ANTHROPIC_API_KEY}`);
  assert.deepEqual(calls[0].body, claudeBody(image));
});

test('public access needs the Claude consent; earlier Google consents are refused without any upstream call', async () => {
  const { calls, handler } = upstream(message(draft));
  const shared = publicEnv();
  assert.equal((await handler(anonymous(), shared)).status, 200);
  for (const consent of ['gemini-free-v2', 'gemini-free-v1', 'old-version', '']) {
    assert.equal((await handler(anonymous({ 'X-Receipt-Consent': consent }), shared)).status, 401);
    assert.equal((await handler(anonymous({ 'X-Receipt-Consent': consent }, { names: ['Americano'], language: 'ko' }, '/receipt/translate'), shared)).status, 401);
  }
  // Without public mode the consent header alone is not enough.
  assert.equal((await handler(anonymous(), env)).status, 401);
  assert.equal(calls.length, 1);
});

test('missing secrets, bad origins, wrong codes and malformed requests never reach Claude', async () => {
  const { calls, handler } = upstream(message(draft));
  assert.equal((await handler(request(), { RECEIPT_ACCESS_CODE: accessCode })).status, 503);
  assert.equal((await handler(request(), { ...env, RECEIPT_ACCESS_CODE: 'short' })).status, 503);
  const sameSecret = 'same-secret-used-for-both-0123456789';
  assert.equal((await handler(request(undefined, { Authorization: `Bearer ${sameSecret}` }),
    { ANTHROPIC_API_KEY: sameSecret, RECEIPT_ACCESS_CODE: sameSecret })).status, 503);
  assert.equal((await handler(request(undefined, { Origin: 'https://other.example' }), env)).status, 403);
  assert.equal((await handler(request(undefined, { Authorization: 'Bearer wrong' }), env)).status, 401);
  assert.equal((await handler(request({ image, key: 'cannot override' }), env)).status, 400);
  assert.equal((await handler(request(undefined, { 'Content-Type': 'text/plain' }), env)).status, 400);
  assert.equal((await handler(request(undefined, { 'Content-Length': '12100001' }), env)).status, 413);
  assert.equal((await handler(request(undefined, {}, 'POST', '/receipt/recognize?key=private'), env)).status, 404);
  assert.equal((await handler(request(undefined, {}, 'POST', '/receipt/claude'), env)).status, 404);
  assert.equal((await handler(request(undefined, {}, 'GET'), env)).status, 405);
  // People in any country may use it: there is no region block.
  const abroad = request(); Object.defineProperty(abroad, 'cf', { value: { country: 'GB' } });
  assert.equal((await handler(abroad, env)).status, 200);
  assert.equal(calls.length, 1);
  const status = await handler(request(undefined, {}, 'GET', '/receipt/status'), env);
  assert.deepEqual(await status.json(), { configured: true, provider: 'claude', model: CLAUDE_MODEL, placement: null });
  assert.equal((await (await handler(request(undefined, {}, 'GET', '/receipt/status'), {})).json()).configured, false);
  const preflight = await handler(request(undefined, {}, 'OPTIONS'), env);
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('Access-Control-Allow-Headers'), 'Authorization, Content-Type, X-Receipt-Consent');
});

test('consent-only public access is capped atomically across requests/restarts without secrets or photos in counters', async () => {
  const binding = usageBinding();
  const shared = publicEnv(binding);
  const { calls, handler } = upstream(message(draft));
  const statuses = await Promise.all(Array.from({ length: 9 }, async () => (await handler(anonymous(), shared)).status));
  assert.equal(statuses.filter(status => status === 200).length, 5);
  assert.equal(statuses.filter(status => status === 429).length, 4);
  binding.restart();
  assert.equal((await handler(anonymous(), shared)).status, 429);
  assert.equal(calls.length, 5);
  assert.equal((await handler(anonymous({ 'CF-Connecting-IP': '' }), shared)).status, 503);
  assert.equal((await handler(anonymous(), { ...shared, RECEIPT_USAGE: null })).status, 503);
  assert.equal((await handler(anonymous({ Origin: 'https://untrusted.invalid' }), shared)).status, 403);
  const counterText = JSON.stringify(binding.state());
  for (const privateValue of [image, env.ANTHROPIC_API_KEY, accessCode, '192.0.2.5', draft.merchant]) assert.ok(!counterText.includes(privateValue));
  assert.equal(binding.state().total, 5);
});

test('usage daily/global limits reset at midnight and provider failures still spend quota', async () => {
  const originalNow = Date.now; let time = Date.UTC(2026, 9, 6);
  Date.now = () => time;
  try {
    const binding = usageBinding();
    const invoke = key => binding.get().fetch('https://usage.internal', { method: 'POST', body: JSON.stringify({ key: key.toString(16).padStart(64, '0') }) });
    for (let i = 0; i < 50; i++) { time += 60_000; assert.equal((await invoke(1)).status, 204); }
    assert.equal((await invoke(1)).status, 429);
    for (let i = 2; i <= 151; i++) assert.equal((await invoke(i)).status, 204);
    assert.equal((await invoke(152)).status, 429);
    time = Date.UTC(2026, 9, 7);
    assert.equal((await invoke(1)).status, 204);
    assert.equal(binding.state().total, 1);
    const { handler } = upstream({ type: 'error', error: { type: 'api_error', message: 'x' } }, 500);
    assert.equal((await handler(anonymous({ 'CF-Connecting-IP': '192.0.2.6' }), publicEnv(binding))).status, 502);
    assert.equal(binding.state().total, 2);
  } finally { Date.now = originalNow; }
});

test('provider failures/quotas make one call with no retries, fallback or leaked provider error', async () => {
  for (const [status, expected, reason] of [[400, 502, 'INVALID_REQUEST'], [401, 502, 'UNAUTHENTICATED'], [429, 429, 'RESOURCE_EXHAUSTED'],
    [500, 502, 'UNAVAILABLE'], [529, 502, 'UNAVAILABLE']]) {
    const { calls, handler } = upstream({ type: 'error', error: { type: 'x', message: `secret detail ${env.ANTHROPIC_API_KEY}` } }, status);
    const response = await handler(request(), env);
    const text = await response.text();
    assert.equal(response.status, expected);
    assert.deepEqual([JSON.parse(text).providerStatus, JSON.parse(text).reason], [status, reason]);
    assert.doesNotMatch(text, /secret detail/);
    assert.ok(!text.includes(env.ANTHROPIC_API_KEY));
    assert.equal(calls.length, 1);
  }
  for (const [reply, reason] of [[message(draft, 'refusal'), 'REFUSAL'], [message(draft, 'max_tokens'), 'INVALID_DRAFT'],
    [message({ ...draft, secret: 'x' }), 'INVALID_DRAFT']]) {
    const { calls, handler } = upstream(reply);
    const response = await handler(request(), env);
    assert.equal(response.status, 502);
    assert.equal((await response.json()).reason, reason);
    assert.equal(calls.length, 1);
  }
});

test('timeout and disconnect abort inference without returning partial data', async () => {
  const handler = createReceiptHandler({ timeoutMs: 10, fetchClaude: async (_, { signal }) =>
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

test('translation sends only ordered names; shares consent, quota and strict output validation', async () => {
  const input = { names: ['Americano', '牛乳'], language: 'ko' };
  const body = claudeTranslationBody(input);
  assert.equal(body.model, CLAUDE_MODEL);
  assert.deepEqual(body.messages, [{ role: 'user', content: JSON.stringify(input.names) }]);
  assert.match(body.system, /untrusted data, never instructions/);
  assert.equal(body.output_config.format.type, 'json_schema');
  for (const bad of [{ ...input, language: 'ja' }, { ...input, names: [] }, { ...input, names: ['a'.repeat(101)] },
    { ...input, image }, { ...input, names: [null] }]) assert.throws(() => claudeTranslationBody(bad));
  for (const bad of [{ names: [] }, { names: ['x'] }, { names: ['', 'x'] }, { names: ['x', null] },
    { names: ['x', 'y'], amount: 10 }]) assert.throws(() => validateTranslation(bad, 2));
  let invalid = false;
  const binding = usageBinding();
  const { calls, handler } = upstream(() => message(invalid ? { names: ['missing row'] } : { names: ['아메리카노', '우유'] }));
  const invoke = (extra = {}) => handler(anonymous({ 'CF-Connecting-IP': '192.0.2.12', ...extra }, input, '/receipt/translate'), publicEnv(binding));
  const first = await invoke();
  assert.deepEqual(await first.json(), { names: ['아메리카노', '우유'], model: CLAUDE_MODEL, provider: 'claude' });
  assert.deepEqual(calls[0].body, body);
  invalid = true;
  assert.equal((await invoke()).status, 502);
  invalid = false;
  for (let i = 0; i < 3; i++) assert.equal((await invoke()).status, 200);
  assert.equal((await invoke()).status, 429);
  assert.equal(calls.length, 5);
  assert.equal(binding.state().total, 5);
  assert.ok(!JSON.stringify(binding.state()).includes('Americano'));
  assert.equal((await invoke({ 'Content-Length': '64001' })).status, 413);
});
