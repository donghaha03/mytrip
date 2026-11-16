import assert from 'node:assert/strict';
import test from 'node:test';
import { mkdtemp } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import http from 'node:http';
import { generateKeyPair, exportJWK, SignJWT } from 'jose';
import { inferenceBody, readInference, MODEL, startServer } from './index.mjs';

const event = value => `data: ${JSON.stringify(value)}\n\n`;
const stream = async function* (text) {
  const bytes = new TextEncoder().encode(text);
  for (let i = 0; i < bytes.length; i += 7) yield bytes.slice(i, i + 7);
};
const receipt = { merchant: 'SAMPLE CAFE', date: null, currency: 'KRW', amount: 7600,
  items: [{ name: 'Tea', quantity: 2, unit_price: 3800, amount: 7600 }], warnings: ['날짜 확인 필요'] };
test('each photo request has only current image, exact model, no tools or paid fallback', () => {
  const a = inferenceBody('data:image/png;base64,YQ==');
  const b = inferenceBody('data:image/png;base64,Yg==');
  assert.equal(a.model, MODEL); assert.equal(a.store, false); assert.equal(a.stream, true);
  assert.equal(a.input.length, 1); assert.notDeepEqual(a.input, b.input);
  assert.equal(a.tools, undefined); assert.equal(a.previous_response_id, undefined);
  assert.throws(() => inferenceBody('https://example.com/image.png'));
});

test('OAuth signature/nonce/scope, model entitlement, completed inference and server duplicate guard with mocked OpenAI', async () => {
  const realFetch = globalThis.fetch;
  const { privateKey, publicKey } = await generateKeyPair('RS256');
  const jwk = { ...await exportJWK(publicKey), kid: 'receipt-test', alg: 'RS256', use: 'sig' };
  const origin = 'http://127.0.0.1:8767';
  let nonce, badNonce = false, available = true, failInference = false, hold = false, release, sent;
  globalThis.fetch = async (url, options = {}) => {
    const target = String(url);
    if (target === 'https://auth.openai.com/.well-known/jwks.json') return Response.json({ keys: [jwk] });
    if (target.endsWith('/oauth/token')) {
      const id_token = await new SignJWT({ nonce: badNonce ? 'invalid' : nonce, email: 'sample@example.invalid' }).setProtectedHeader({ alg: 'RS256', kid: 'receipt-test' })
        .setIssuer('https://auth.openai.com').setAudience('oaiapp_receipt_test').setSubject('sample-test')
        .setIssuedAt().setExpirationTime('1h').sign(privateKey);
      return Response.json({ id_token, access_token: 'fixture-access', refresh_token: 'fixture-refresh', expires_in: 3600,
        scope: 'openid profile email offline_access resource.invoke chatgpt.tokens.use.direct' });
    }
    if (target === 'https://api.openai.com/v1/models') return Response.json({ models: available ? [{ slug: MODEL, visibility: 'list' }] : [] });
    if (target === 'https://api.openai.com/v1/responses') {
      sent = JSON.parse(options.body);
      if (hold) await new Promise(r => { release = r; });
      return new Response(failInference ? event({ type: 'response.failed', response: { error: { code: 'subscription_sharing_usage_limit_exceeded' } } }) :
        event({ type: 'response.output_text.delta', delta: JSON.stringify(receipt) }) + event({ type: 'response.completed', response: { status: 'completed' } }));
    }
    if (target.startsWith('https://')) throw new Error('unexpected upstream request');
    return realFetch(url, options);
  };
  const server = await startServer({ port: 8767, directory: await mkdtemp(join(tmpdir(), 'mytrip-receipt-test-')) });
  try {
    const page = await (await realFetch(`${origin}/receipt-connect`)).text();
    const csrf = /const csrf="([^"]+)"/.exec(page)[1];
    const post = (path, data) => realFetch(`${origin}${path}`, { method: 'POST', headers: { Origin: origin, 'X-mytrip-csrf': csrf }, body: JSON.stringify(data) });
    const rejectedLogin = await post('/receipt/login', { account: 'new' });
    const rejectedAuthorize = new URL((await rejectedLogin.json()).url); nonce = rejectedAuthorize.searchParams.get('nonce');
    const rejectedCallback = `${origin}/auth/callback?${new URLSearchParams({ state: rejectedAuthorize.searchParams.get('state'), code: 'fixture', client_id: 'oaiapp_receipt_test' })}`;
    badNonce = true;
    assert.equal((await realFetch(rejectedCallback, { headers: { Cookie: rejectedLogin.headers.get('set-cookie').split(';')[0] }, redirect: 'manual' })).status, 400);
    assert.equal((await (await realFetch(`${origin}/receipt/status`)).json()).connected, false);
    badNonce = false;
    const login = await post('/receipt/login', { account: 'new' });
    const authorize = new URL((await login.json()).url); nonce = authorize.searchParams.get('nonce');
    assert.equal(authorize.searchParams.get('client_id'), 'dynamic_agent_client');
    assert.equal(authorize.searchParams.get('code_challenge_method'), 'S256');
    const callback = `${origin}/auth/callback?${new URLSearchParams({ state: authorize.searchParams.get('state'), code: 'fixture', client_id: 'oaiapp_receipt_test' })}`;
    const cookie = login.headers.get('set-cookie').split(';')[0];
    const approved = await realFetch(callback, { headers: { Cookie: cookie }, redirect: 'manual' }); assert.equal(approved.status, 303);
    assert.equal((await realFetch(callback, { headers: { Cookie: cookie }, redirect: 'manual' })).status, 400); // one-time state
    available = false;
    assert.match((await (await post('/receipt/check', {})).json()).error, /모델 목록/);
    available = true;
    const data = { image: 'data:image/png;base64,YQ==' };
    const success = await post('/receipt/recognize', data); assert.deepEqual((await success.json()).draft, receipt);
    assert.equal(sent.model, MODEL); assert.equal(sent.store, false); assert.equal(sent.stream, true); assert.equal(sent.input.length, 1);
    failInference = true;
    assert.match((await (await post('/receipt/recognize', data)).json()).error, /한도/);
    failInference = false; hold = true;
    const pending = post('/receipt/recognize', data);
    while (!release) await new Promise(r => setTimeout(r, 5));
    assert.equal((await post('/receipt/recognize', data)).status, 409);
    release(); assert.equal((await pending).status, 200);
  } finally {
    globalThis.fetch = realFetch;
    await new Promise(r => server.close(r)); await new Promise(r => setTimeout(r, 50));
  }
});
test('fragmented UTF-8 stream succeeds only after completed terminal event', async () => {
  const data = event({ type: 'response.output_text.delta', delta: JSON.stringify(receipt) }) + event({ type: 'response.completed', response: { status: 'completed' } });
  assert.deepEqual(await readInference(stream(data)), receipt);
  await assert.rejects(readInference(stream(event({ type: 'response.output_text.delta', delta: JSON.stringify(receipt) }))), /interrupted/);
  for (const code of ['subscription_sharing_usage_limit_exceeded', 'subscription_sharing_usage_unavailable']) {
    await assert.rejects(readInference(stream(data + event({ type: 'response.failed', response: { error: { code } } }))), new RegExp(code));
  }
  await assert.rejects(readInference(stream(event({ type: 'response.incomplete' }))), /incomplete/);
  await assert.rejects(readInference(stream(event({ type: 'response.output_item.added', item: { type: 'function_call' } }))), /tool/);
});
test('local runtime rejects wrong Host, Origin, absent CSRF and callback state; credentials never reach browser', async () => {
  const server = await startServer({ port: 8766, directory: await mkdtemp(join(tmpdir(), 'mytrip-receipt-test-')) });
  const origin = 'http://127.0.0.1:8766';
  try {
    const page = await (await fetch(`${origin}/receipt-connect`)).text();
    const csrf = /const csrf="([^"]+)"/.exec(page)[1];
    assert.doesNotMatch(page, /access_token|refresh_token|id_token/);
    const status = await (await fetch(`${origin}/receipt/status`)).json();
    assert.equal(status.model, MODEL); assert.equal(status.connected, false);
    for (const headers of [{}, { Origin: 'https://evil.invalid', 'X-mytrip-csrf': csrf }, { Origin: origin, 'X-mytrip-csrf': 'bad' }]) {
      assert.equal((await fetch(`${origin}/receipt/recognize`, { method: 'POST', headers, body: '{}' })).status, 403);
    }
    const wrongHost = await new Promise(r => {
      http.get(`${origin}/receipt/status`, { headers: { Host: 'evil.invalid' } }, response => { response.resume(); r(response.statusCode); });
    });
    assert.equal(wrongHost, 403);
    const r = await fetch(`${origin}/receipt/recognize`, { method: 'POST', headers: { Origin: origin, 'X-mytrip-csrf': csrf }, body: JSON.stringify({ image: 'data:image/png;base64,YQ==' }) });
    assert.match((await r.json()).error, /로그인/);
    assert.equal((await fetch(`${origin}/auth/callback?state=wrong&code=wrong`)).status, 400);
  } finally {
    await new Promise(r => server.close(r));
    // close event removes the owner lock asynchronously.
    await new Promise(r => setTimeout(r, 50));
  }
});
