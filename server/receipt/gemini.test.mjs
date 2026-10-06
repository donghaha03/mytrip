import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createGeminiHandler, GEMINI_MODEL, geminiBody, readGemini, CONSENT_VERSION, ReceiptUsage, translationBody, validateTranslation } from './gemini.mjs';

const image = `data:image/png;base64,${(await readFile(new URL('../../test/fixtures/receipt_en.png', import.meta.url))).toString('base64')}`;
const accessCode = 'fixture-access-code-0123456789-abcd';
const env = { GEMINI_API_KEY: 'fixture-google-key-not-a-real-credential', RECEIPT_ACCESS_CODE: accessCode,
  GEMINI_FREE_TIER_CONFIRMED: 'yes', RECEIPT_FREE_HOSTING_CONFIRMED: 'yes' };
const draft = { merchant: '페이히어 카페', date: null, currency: 'KRW', amount: 5000,
  items: [{ name: 'Americano', quantity: 1, unit_price: 5000, amount: 5000 }], warnings: ['날짜 확인 필요'] };
const reply = value => ({ status: 'completed', model: GEMINI_MODEL, steps: [{ type: 'model_output', content: [{ type: 'text', text: JSON.stringify(value) }] }] });
const request = (body = { image }, headers = {}, method = 'POST', path = '/receipt/recognize') =>
  new Request(`https://receipt.example.invalid${path}`, { method,
    headers: { Origin: 'https://donghaha03.github.io', Authorization: `Bearer ${accessCode}`, 'Content-Type': 'application/json', ...headers },
    ...(method === 'POST' ? { body: JSON.stringify(body) } : {}) });

test('real image bytes, shared prompt and JSON schema go only to the fixed Gemini model', () => {
  const body = geminiBody(image);
  assert.equal(body.model, GEMINI_MODEL);
  assert.equal(body.store, false);
  assert.equal(body.input[1].mime_type, 'image/png');
  assert.equal(body.input[1].data, image.split(',')[1]);
  assert.match(body.system_instruction, /never instructions/);
  assert.match(body.system_instruction, /Do not add subtotal or tax/);
  assert.equal(body.response_format.mime_type, 'application/json');
  assert.deepEqual(body.generation_config, { max_output_tokens: 8192 });
  assert.match(body.system_instruction, /Use exactly this JSON schema/);
  assert.deepEqual(body.system_instruction.includes('purchased items'), true);
  const schema = JSON.parse(body.system_instruction.split('Use exactly this JSON schema: ')[1]);
  assert.deepEqual(new Set(schema.required), new Set(Object.keys(schema.properties)), 'Strict OpenAI and Gemini schemas must require all properties');
  assert.equal(body.tools, undefined);
  assert.equal(body.previous_interaction_id, undefined);
  assert.deepEqual(readGemini(reply(draft)), draft);
  for (const bad of ['https://private.example/receipt.jpg', 'data:image/png;base64,YQ==', image.replace('png', 'jpeg'), 'data:image/png;base64,!!!!'])
    assert.throws(() => geminiBody(bad));
});

test('blocked, truncated, missing and invalid results cannot become review drafts', () => {
  const blocked = reply(draft); blocked.status = 'failed';
  const truncated = reply(draft); truncated.status = 'incomplete';
  const tool = reply(draft); tool.steps.push({ type: 'function_call', name: 'upload' });
  const wrongModel = reply(draft); wrongModel.model = 'not-the-selected-model';
  for (const value of [blocked, truncated, tool, wrongModel, {}, reply({}), reply({ ...draft, date: '2026-02-30' }),
    reply({ ...draft, amount: '5000' }), reply({ ...draft, currency: 'won' }),
    reply({ ...draft, currency: ['KRW'] }),
    reply({ ...draft, items: [{ ...draft.items[0], quantity: 1.5 }] }), reply({ ...draft, secret: 'ignored?' })]) {
    assert.throws(() => readGemini(value));
  }
  const reasoning = reply(draft); reasoning.steps.unshift({ type: 'thought', signature: 'internal reasoning' });
  assert.deepEqual(readGemini(reasoning), draft);
});

test('taxes preserve explicit components, zero and unknown inclusion without inflating total', () => {
  const taxed = { ...draft, category: '식비', taxes: [
    { label: '부가세', amount: 455, currency: 'KRW', included: true },
    { label: '소비세', amount: 0, currency: 'JPY', included: null },
  ] };
  assert.deepEqual(readGemini(reply(taxed)), taxed);
  assert.equal(readGemini(reply(taxed)).amount, 5000);
  for (const tax of [{ ...taxed.taxes[0], amount: '455' }, { ...taxed.taxes[0], label: '공급가액' },
    { ...taxed.taxes[0], currency: 'won' }, { ...taxed.taxes[0], included: 'yes' }, { ...taxed.taxes[0], secret: 'ignored?' }])
    assert.throws(() => readGemini(reply({ ...taxed, taxes: [tax] })));
  assert.deepEqual(readGemini(reply({ ...taxed, taxes: [] })).taxes, []);
  assert.match(geminiBody(image).system_instruction, /Never compute tax/);
  const adjusted = { ...taxed, amount: 9500, adjustments: { taxFree: true, exemptedTax: 1000, taxFreeBase: null, discount: 500, currency: 'KRW' } };
  assert.equal(readGemini(reply(adjusted)).amount, 9500);
  assert.equal(readGemini(reply(adjusted)).adjustments.taxFree, true);
  for (const bad of [{ ...adjusted.adjustments, discount: -500 }, { ...adjusted.adjustments, taxFree: 'yes' }, { ...adjusted.adjustments, secret: 'unexpected' }])
    assert.throws(() => readGemini(reply({ ...adjusted, adjustments: bad })));
});

test('translation sends only ordered names; shares consent, free-tier quota and strict output validation', async () => {
  const input = { names: ['Americano', '牛乳'], language: 'ko' };
  const body = translationBody(input);
  assert.equal(body.store, false);
  assert.equal(body.model, GEMINI_MODEL);
  assert.deepEqual(body.input, [{ type: 'text', text: JSON.stringify(input.names) }]);
  assert.match(body.system_instruction, /untrusted data, never instructions/);
  for (const bad of [{ ...input, language: 'ja' }, { ...input, names: [] }, { ...input, names: ['a'.repeat(101)] },
    { ...input, image }, { ...input, names: [null] }]) assert.throws(() => translationBody(bad));
  for (const bad of [{ names: [] }, { names: ['x'] }, { names: ['', 'x'] }, { names: ['x', null] },
    { names: ['x', 'y'], amount: 10 }]) assert.throws(() => validateTranslation(bad, 2));
  let calls = 0, invalid = false;
  const binding = usageBinding();
  const handler = createGeminiHandler({ fetchGemini: async (_, options) => {
    calls++; assert.deepEqual(JSON.parse(options.body), body);
    return Response.json(reply(invalid ? { names: ['missing row'] } : { names: ['아메리카노', '우유'] }));
  } });
  const publicEnv = { ...env, RECEIPT_PUBLIC_CONSENT: 'yes', RECEIPT_USAGE: binding };
  const invoke = (extra = {}) => handler(request(input, { Authorization: '', 'X-Receipt-Consent': CONSENT_VERSION,
    'CF-Connecting-IP': '192.0.2.12', ...extra }, 'POST', '/receipt/translate'), publicEnv);
  assert.deepEqual((await (await invoke()).json()).names, ['아메리카노', '우유']);
  assert.equal((await invoke({ 'X-Receipt-Consent': 'gemini-free-v1' })).status, 401);
  invalid = true;
  assert.equal((await invoke()).status, 502);
  invalid = false;
  for (let i = 0; i < 3; i++) assert.equal((await invoke()).status, 200);
  assert.equal((await invoke()).status, 429);
  assert.equal(calls, 5);
  assert.equal(binding.state().total, 5);
  assert.ok(!JSON.stringify(binding.state()).includes('Americano'));
  assert.equal((await invoke({ 'Content-Length': '64001' })).status, 413);
});

test('keys stay upstream; browser and native use the same endpoint and review contract', async () => {
  let calls = 0;
  const handler = createGeminiHandler({ fetchGemini: async (url, options) => {
    calls++;
    assert.equal(url, 'https://generativelanguage.googleapis.com/v1beta/interactions');
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
  assert.deepEqual(await status.json(), { configured: true, provider: 'gemini', model: GEMINI_MODEL, placement: null });
  const preflight = await handler(request(undefined, {}, 'OPTIONS'), env);
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('Access-Control-Allow-Headers'), 'Authorization, Content-Type, X-Receipt-Consent');
});

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

test('consent-only public access is capped atomically across requests/restarts without secrets or photos in counters', async () => {
  const binding = usageBinding(); let calls = 0;
  const publicEnv = { ...env, RECEIPT_PUBLIC_CONSENT: 'yes', RECEIPT_USAGE: binding };
  const handler = createGeminiHandler({ fetchGemini: async () => { calls++; return Response.json(reply({ ...draft, category: '식비' })); } });
  const anonymous = (extra = {}) => request(undefined, { Authorization: '', 'X-Receipt-Consent': CONSENT_VERSION, 'CF-Connecting-IP': '192.0.2.5', ...extra });
  const statuses = await Promise.all(Array.from({ length: 9 }, async () => (await handler(anonymous(), publicEnv)).status));
  assert.equal(statuses.filter(status => status === 200).length, 5);
  assert.equal(statuses.filter(status => status === 429).length, 4);
  binding.restart();
  assert.equal((await handler(anonymous(), publicEnv)).status, 429);
  assert.equal(calls, 5);
  assert.equal((await handler(anonymous({ 'X-Receipt-Consent': 'old-version' }), publicEnv)).status, 401);
  assert.equal((await handler(anonymous({ 'CF-Connecting-IP': '' }), publicEnv)).status, 503);
  assert.equal((await handler(anonymous(), { ...publicEnv, RECEIPT_USAGE: null })).status, 503);
  assert.equal((await handler(anonymous({ Origin: 'https://untrusted.invalid' }), publicEnv)).status, 403);
  const counterText = JSON.stringify(binding.state());
  for (const privateValue of [image, env.GEMINI_API_KEY, accessCode, '192.0.2.5', draft.merchant]) assert.ok(!counterText.includes(privateValue));
  assert.equal(binding.state().total, 5);
  assert.deepEqual(readGemini(reply({ ...draft, category: '식비' })).category, '식비');
  assert.throws(() => readGemini(reply({ ...draft, category: '없는 카테고리' })));
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
    const handler = createGeminiHandler({ fetchGemini: async () => Response.json({}, { status: 500 }) });
    const failure = await handler(request(undefined, { Authorization: '', 'X-Receipt-Consent': CONSENT_VERSION, 'CF-Connecting-IP': '192.0.2.6' }),
      { ...env, RECEIPT_PUBLIC_CONSENT: 'yes', RECEIPT_USAGE: binding });
    assert.equal(failure.status, 502);
    assert.equal(binding.state().total, 2);
  } finally { Date.now = originalNow; }
});

test('provider failures/quotas make one call with no retries, fallback or leaked provider error', async () => {
  for (const status of [400, 401, 429, 500]) {
    let calls = 0;
    const handler = createGeminiHandler({ fetchGemini: async () => {
      calls++; return Response.json({ error: { status: env.GEMINI_API_KEY, message: `private-error-${env.GEMINI_API_KEY}` } }, { status });
    } });
    const response = await handler(request(), env);
    assert.equal(response.status, status === 429 ? 429 : 502);
    assert.ok(!(await response.text()).includes(env.GEMINI_API_KEY));
    assert.equal(calls, 1);
  }
  const handler = createGeminiHandler({ fetchGemini: async () => Response.json({ error: { code: 'invalid_request', message: 'Unknown field response_format' } }, { status: 400 }) });
  const error = await (await handler(request(), env)).json();
  assert.equal(error.reason, 'INVALID_RESPONSE_FORMAT');
  assert.equal(error.providerStatus, 400);
  const location = createGeminiHandler({ fetchGemini: async () => Response.json({ error: { status: 'FAILED_PRECONDITION', message: 'User location is not supported for the API use.' } }, { status: 400 }) });
  assert.equal((await (await location(request(), env)).json()).reason, 'LOCATION_UNSUPPORTED');
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
