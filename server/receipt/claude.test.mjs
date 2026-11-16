import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createGeminiHandler, CONSENT_VERSION } from './gemini.mjs';
import { CLAUDE_MODEL, claudeBody, claudeSchema } from './claude.mjs';

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
  assert.deepEqual(await response.json(), { draft, model: CLAUDE_MODEL, provider: 'claude' });
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
