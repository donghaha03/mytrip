import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createGeminiHandler, CONSENT_VERSION, ReceiptUsage } from './gemini.mjs';
import { CLAUDE_MODEL, CLAUDE_CONSENT_VERSION, claudeBody, claudeTranslationBody, claudeSchema } from './claude.mjs';

const image = `data:image/png;base64,${(await readFile(new URL('../../test/fixtures/receipt_en.png', import.meta.url))).toString('base64')}`;
const accessCode = 'fixture-access-code-0123456789-abcd';
const env = { ANTHROPIC_API_KEY: 'fixture-anthropic-key-not-a-real-credential', RECEIPT_ACCESS_CODE: accessCode };
const draft = { merchant: 'TEST CAFE', date: '2026-10-04', currency: 'KRW', amount: 11000, category: '식비',
  taxes: [], adjustments: { taxFree: null, exemptedTax: null, taxFreeBase: null, discount: null, currency: null, details: [] },
  items: [{ name: 'Americano', quantity: 1, unit_price: 5000, amount: 5000 }], warnings: [] };
const message = (value, stop_reason = 'end_turn') => ({ id: 'msg_fixture', type: 'message', role: 'assistant', model: CLAUDE_MODEL,
  stop_reason, stop_sequence: null, usage: { input_tokens: 1, output_tokens: 1 },
  content: [{ type: 'thinking', thinking: '', signature: 'sig' }, { type: 'text', text: JSON.stringify(value) }] });
const request = (headers = { Authorization: `Bearer ${accessCode}` }) => new Request('https://receipt.example.invalid/receipt/claude', {
  method: 'POST', body: JSON.stringify({ image }),
  headers: { Origin: 'https://donghaha03.github.io', 'Content-Type': 'application/json', ...headers } });
// Records every upstream call so tests can prove no retry happens.
const upstream = (status, payload) => {
  const calls = [];
  const fetchClaude = async (url, init) => { calls.push({ url: String(url), init }); return Response.json(payload, { status }); };
  return { calls, handler: createGeminiHandler({ fetchClaude, fetchGemini: () => assert.fail('Gemini must not be called') }) };
};

test('image, shared prompt and a constraint-free schema go to Claude Haiku at low effort', () => {
  const body = claudeBody(image);
  assert.equal(body.model, CLAUDE_MODEL);
  assert.equal(body.messages[0].content[0].source.data, image.split(',')[1]);
  assert.equal(body.messages[0].content[0].source.media_type, 'image/png');
  assert.match(body.system, /never instructions/);
  assert.deepEqual(body.output_config, { effort: 'low', format: { type: 'json_schema', schema: claudeSchema } });
  assert.doesNotMatch(JSON.stringify(claudeSchema), /maxItems|maxLength/);
  assert.deepEqual(new Set(claudeSchema.required), new Set(Object.keys(claudeSchema.properties)));
  assert.throws(() => claudeBody('data:image/png;base64,YQ=='));
});

test('access code reaches Claude once and returns a validated draft', async () => {
  const { calls, handler } = upstream(200, message(draft));
  const response = await handler(request(), env);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { draft, model: CLAUDE_MODEL, provider: 'claude', usage: { input_tokens: 1, output_tokens: 1 } });
  assert.equal(calls.length, 1);
  assert.match(calls[0].url, /\/v1\/messages$/);
  assert.equal(new Headers(calls[0].init.headers).get('authorization'), `Bearer ${env.ANTHROPIC_API_KEY}`);
  assert.equal(JSON.parse(calls[0].init.body).model, CLAUDE_MODEL);
});

test('public Gemini consent never authorizes sending photos to Claude', async () => {
  const { calls, handler } = upstream(200, message(draft));
  const response = await handler(request({ 'X-Receipt-Consent': CONSENT_VERSION }), { ...env, RECEIPT_PUBLIC_CONSENT: 'yes' });
  assert.equal(response.status, 401);
  assert.equal(calls.length, 0);
});

test('missing key is unconfigured, not a silent Gemini fallback', async () => {
  const { calls, handler } = upstream(200, message(draft));
  assert.equal((await handler(request(), { RECEIPT_ACCESS_CODE: accessCode })).status, 503);
  assert.equal(calls.length, 0);
});

test('refusals, truncation and invalid drafts never become review drafts', async () => {
  for (const [reply, reason] of [[message(draft, 'refusal'), 'REFUSAL'], [message(draft, 'max_tokens'), 'INVALID_DRAFT'],
    [message({ ...draft, date: '2026-02-30' }), 'INVALID_DRAFT'], [message({ ...draft, secret: 'x' }), 'INVALID_DRAFT']]) {
    const response = await upstream(200, reply).handler(request(), env);
    assert.equal(response.status, 502);
    assert.equal((await response.json()).reason, reason);
  }
});

test('provider errors map to safe reasons with exactly one attempt', async () => {
  for (const [status, expected, reason] of [[429, 429, 'RESOURCE_EXHAUSTED'], [401, 502, 'UNAUTHENTICATED'], [529, 502, 'UNAVAILABLE']]) {
    const { calls, handler } = upstream(status, { type: 'error', error: { type: 'x', message: 'secret detail' } });
    const response = await handler(request(), env);
    const payload = await response.json();
    assert.equal(response.status, expected);
    assert.deepEqual([payload.providerStatus, payload.reason], [status, reason]);
    assert.doesNotMatch(JSON.stringify(payload), /secret detail/);
    assert.equal(calls.length, 1);
  }
});

// --- Stage 1: the consent version the app sends picks the provider. ---
const publicEnv = () => {
  let usage, pending = Promise.resolve();
  const storage = { transaction: callback => (pending = pending.then(() => callback({
    get: async () => structuredClone(usage), put: async (_, next) => { usage = structuredClone(next); } }))) };
  const counter = new ReceiptUsage({ storage });
  return { ...env, GEMINI_API_KEY: 'fixture-google-key-not-a-real-credential', GEMINI_FREE_TIER_CONFIRMED: 'yes',
    RECEIPT_FREE_HOSTING_CONFIRMED: 'yes', RECEIPT_PUBLIC_CONSENT: 'yes',
    RECEIPT_USAGE: { idFromName: name => name, get: () => ({ fetch: (url, init) => counter.fetch(new Request(url, init)) }) } };
};
const publicRequest = (consent, path = '/receipt/recognize', body = { image }, cf) => Object.assign(
  new Request(`https://receipt.example.invalid${path}`, { method: 'POST', body: JSON.stringify(body),
    headers: { Origin: 'https://donghaha03.github.io', 'Content-Type': 'application/json', 'CF-Connecting-IP': '192.0.2.7',
      ...(consent ? { 'X-Receipt-Consent': consent } : {}) } }), cf ? { cf } : {});
const geminiReply = value => Response.json({ status: 'completed', model: 'gemini-3.5-flash-lite',
  steps: [{ type: 'model_output', content: [{ type: 'text', text: JSON.stringify(value) }] }] });
const both = claudeReply => {
  const calls = { claude: [], gemini: 0 };
  const handler = createGeminiHandler({
    fetchClaude: async (url, init) => { calls.claude.push(JSON.parse(init.body)); return Response.json(claudeReply); },
    fetchGemini: async () => { calls.gemini++; return geminiReply(draft); } });
  return { calls, handler };
};

test('Claude consent sends the photo to Haiku only; no access code and no Gemini call', async () => {
  const { calls, handler } = both(message(draft));
  const response = await handler(publicRequest(CLAUDE_CONSENT_VERSION), publicEnv());
  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.deepEqual([payload.draft, payload.model, payload.provider], [draft, CLAUDE_MODEL, 'claude']);
  assert.deepEqual([calls.claude.length, calls.gemini], [1, 0]);
  assert.equal(calls.claude[0].model, CLAUDE_MODEL);
});

test('already-deployed apps with the Gemini consent keep using Gemini, never Claude', async () => {
  for (const consent of [CONSENT_VERSION, 'gemini-free-v1']) {
    const { calls, handler } = both(message(draft));
    const response = await handler(publicRequest(consent), publicEnv());
    assert.equal(response.status, 200);
    assert.equal((await response.json()).provider, 'gemini');
    assert.deepEqual([calls.claude.length, calls.gemini], [0, 1]);
  }
});

test('Claude consent translates item names with Haiku and validates the count', async () => {
  const input = { names: ['Americano', '牛乳'], language: 'ko' };
  const body = claudeTranslationBody(input);
  assert.equal(body.model, CLAUDE_MODEL);
  assert.deepEqual(body.messages, [{ role: 'user', content: JSON.stringify(input.names) }]);
  assert.match(body.system, /untrusted data, never instructions/);
  assert.equal(body.output_config.format.type, 'json_schema');
  for (const bad of [{ ...input, language: 'ja' }, { ...input, names: [] }, { ...input, image }]) assert.throws(() => claudeTranslationBody(bad));
  const ok = both(message({ names: ['아메리카노', '우유'] }));
  const response = await ok.handler(publicRequest(CLAUDE_CONSENT_VERSION, '/receipt/translate', input), publicEnv());
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).names, ['아메리카노', '우유']);
  assert.deepEqual(ok.calls.claude[0], body);
  assert.equal(ok.calls.gemini, 0);
  const short = both(message({ names: ['한 줄만'] }));
  assert.equal((await short.handler(publicRequest(CLAUDE_CONSENT_VERSION, '/receipt/translate', input), publicEnv())).status, 502);
});

test('Claude consent needs the Anthropic key and public mode; it never falls back to Gemini', async () => {
  const { calls, handler } = both(message(draft));
  const { ANTHROPIC_API_KEY, ...noKey } = publicEnv();
  assert.equal((await handler(publicRequest(CLAUDE_CONSENT_VERSION), noKey)).status, 503);
  assert.equal((await handler(publicRequest(CLAUDE_CONSENT_VERSION), { ...publicEnv(), RECEIPT_PUBLIC_CONSENT: 'no' })).status, 401);
  assert.equal((await handler(publicRequest('unknown-version'), publicEnv())).status, 401);
  assert.deepEqual([calls.claude.length, calls.gemini], [0, 0]);
});

test('the Google free-tier region block applies to Gemini requests only', async () => {
  const { calls, handler } = both(message(draft));
  assert.equal((await handler(publicRequest(CONSENT_VERSION, undefined, undefined, { country: 'DE' }), publicEnv())).status, 403);
  assert.equal((await handler(publicRequest(CLAUDE_CONSENT_VERSION, undefined, undefined, { country: 'DE' }), publicEnv())).status, 200);
  assert.deepEqual([calls.claude.length, calls.gemini], [1, 0]);
});

test('public Claude requests share the daily usage cap', async () => {
  const { calls, handler } = both(message(draft));
  const shared = publicEnv();
  const statuses = [];
  for (let i = 0; i < 6; i++) statuses.push((await handler(publicRequest(CLAUDE_CONSENT_VERSION), shared)).status);
  assert.deepEqual(statuses, [200, 200, 200, 200, 200, 429]); // 5 per minute per client
  assert.equal(calls.claude.length, 5);
});

test('status reports whether Claude is ready', async () => {
  const handler = createGeminiHandler();
  const status = env => handler(new Request('https://receipt.example.invalid/receipt/status'), env).then(r => r.json());
  assert.equal((await status(publicEnv())).claude, true);
  assert.equal((await status({ RECEIPT_ACCESS_CODE: accessCode })).claude, false);
});
