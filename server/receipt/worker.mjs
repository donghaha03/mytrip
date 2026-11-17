// Public receipt Worker: recognition and item-name translation through Claude Haiku only.
// Photos and results are never stored or logged; only anonymous daily usage counters are kept.
import { validateDraft, validateTranslation } from './contract.mjs';
import { CLAUDE_MODEL, CLAUDE_CONSENT_VERSION, claudeBody, claudeTranslationBody, askClaude } from './claude.mjs';

const maxBody = 12_100_000;
const messages = {
  400: '사진을 읽지 못했어요. 다시 촬영해주세요.',
  401: '사진 전송 동의를 확인해주세요.',
  403: '영수증 서버의 연결 권한을 확인해주세요.',
  413: '사진이 너무 커요. 다시 촬영해주세요.',
  429: '인식 한도에 도달했어요. 잠시 후 다시 시도하거나 수동으로 입력해주세요.',
  502: '인식하지 못했어요. 다시 시도하거나 수동으로 입력해주세요.',
  503: '영수증 인식 연결 설정이 필요해요. 수동 입력을 이용해주세요.',
  504: '인식 시간이 초과됐어요. 다시 시도하거나 수동으로 입력해주세요.',
};

async function readBody(request, limit, signal) {
  if (Number(request.headers.get('Content-Length')) > limit) throw new Error('too_large');
  const reader = request.body?.getReader();
  if (!reader) throw new Error('invalid_body');
  const cancel = () => { reader.cancel().catch(() => {}); };
  signal?.addEventListener('abort', cancel, { once: true });
  if (signal?.aborted) cancel();
  const chunks = []; let length = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > limit) { await reader.cancel(); throw new Error('too_large'); }
      chunks.push(value);
    }
  } finally { signal?.removeEventListener('abort', cancel); reader.releaseLock(); }
  if (signal?.aborted) throw new Error('aborted');
  const bytes = new Uint8Array(length); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes));
}

async function validCode(supplied, expected) {
  if (!/^[A-Za-z0-9_-]{32,128}$/.test(supplied)) return false;
  const digest = text => crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  const [a, b] = await Promise.all([digest(supplied), digest(expected)]);
  const left = new Uint8Array(a), right = new Uint8Array(b); let difference = 0;
  for (let i = 0; i < left.length; i++) difference |= left[i] ^ right[i];
  return difference === 0;
}

// Only daily salted IP hashes and counters are stored, never receipt data.
async function usageKey(ip, secret, day) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const hash = new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(`${day}:${ip}`)));
  return Array.from(hash, byte => byte.toString(16).padStart(2, '0')).join('');
}

export class ReceiptUsage {
  constructor(ctx) { this.storage = ctx.storage; }
  async fetch(request) {
    const { key } = await request.json();
    if (!/^[a-f0-9]{64}$/.test(key)) return new Response(null, { status: 400 });
    const now = Date.now(), day = Math.floor(now / 86_400_000), minute = Math.floor(now / 60_000);
    // ponytail: one atomic counter for the small pilot (200 requests/day, 50/client/day, 5/client/minute).
    // Partition only if the presentation becomes a larger authenticated service.
    const allowed = await this.storage.transaction(async txn => {
      let usage = await txn.get('usage');
      if (usage?.day !== day) usage = { day, total: 0, clients: {} };
      const client = usage.clients[key] ?? { total: 0, minute, recent: 0 };
      if (client.minute !== minute) { client.minute = minute; client.recent = 0; }
      if (usage.total >= 200 || client.total >= 50 || client.recent >= 5) return false;
      client.total++; client.recent++; usage.total++;
      usage.clients[key] = client;
      await txn.put('usage', usage);
      return true;
    });
    return new Response(null, { status: allowed ? 204 : 429 });
  }
}

export function createReceiptHandler({ fetchClaude = fetch, timeoutMs = 85_000 } = {}) {
  return async (request, env) => {
    const origin = request.headers.get('Origin');
    const allowed = (env.RECEIPT_ALLOWED_ORIGINS ?? 'https://donghaha03.github.io').split(',').map(x => x.trim());
    const headers = { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', 'Vary': 'Origin' };
    if (origin && allowed.includes(origin)) headers['Access-Control-Allow-Origin'] = origin;
    const send = (status, data = { error: messages[status] }) => new Response(status === 204 ? null : JSON.stringify(data), { status, headers });
    if (origin && !allowed.includes(origin)) return send(403);
    const url = new URL(request.url);
    if (url.search || !['/receipt/recognize', '/receipt/translate', '/receipt/status'].includes(url.pathname)) return send(404, {});
    const translating = url.pathname === '/receipt/translate';
    if (request.method === 'OPTIONS') {
      headers['Access-Control-Allow-Methods'] = 'GET, POST';
      headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type, X-Receipt-Consent';
      return send(204);
    }
    // The access code also keys the anonymous usage hashes, so it must be a real random secret, not an API key.
    const configured = typeof env.ANTHROPIC_API_KEY === 'string' && env.ANTHROPIC_API_KEY.length > 20 &&
      /^[A-Za-z0-9_-]{32,128}$/.test(env.RECEIPT_ACCESS_CODE ?? '') &&
      !/^(AIza|sk-)/.test(env.RECEIPT_ACCESS_CODE) && env.RECEIPT_ACCESS_CODE !== env.ANTHROPIC_API_KEY;
    if (url.pathname === '/receipt/status') return request.method === 'GET' ?
      send(200, { configured, provider: 'claude', model: CLAUDE_MODEL,
        placement: /^(local|remote)-[A-Z]{3}$/.test(request.headers.get('cf-placement') ?? '') ? request.headers.get('cf-placement') : null }) : send(405, {});
    if (request.method !== 'POST') return send(405, {});
    if (!configured) return send(503);
    const publicMode = env.RECEIPT_PUBLIC_CONSENT === 'yes';
    // Only the consent to send receipts to Anthropic counts. Earlier consents (to another provider) are refused.
    const consented = publicMode && request.headers.get('X-Receipt-Consent') === CLAUDE_CONSENT_VERSION;
    if (!consented && !await validCode(/^Bearer ([A-Za-z0-9_-]+)$/.exec(request.headers.get('Authorization') ?? '')?.[1] ?? '', env.RECEIPT_ACCESS_CODE)) return send(401);
    if (!/^application\/json(?:\s*;|$)/i.test(request.headers.get('Content-Type') ?? '')) return send(400);
    const controller = new AbortController();
    const cancel = () => controller.abort();
    request.signal.addEventListener('abort', cancel, { once: true });
    if (request.signal.aborted) cancel();
    const timer = setTimeout(cancel, timeoutMs);
    try {
      let body, itemCount;
      try {
        const data = await readBody(request, translating ? 64_000 : maxBody, controller.signal);
        if (translating) {
          body = claudeTranslationBody(data);
          itemCount = data.names.length;
        } else {
          if (!data || Array.isArray(data) || Object.keys(data).length !== 1) throw new Error('invalid_body');
          body = claudeBody(data.image);
        }
      } catch (error) { return send(controller.signal.aborted ? 504 : error.message === 'too_large' ? 413 : 400); }
      if (controller.signal.aborted) return send(504);
      if (publicMode) {
        const ip = request.headers.get('CF-Connecting-IP');
        if (!ip || !env.RECEIPT_USAGE) return send(503); // Never bypass limits on a binding failure.
        const key = await usageKey(ip, env.RECEIPT_ACCESS_CODE, Math.floor(Date.now() / 86_400_000));
        let quota;
        try {
          quota = await env.RECEIPT_USAGE.get(env.RECEIPT_USAGE.idFromName('mytrip')).fetch('https://usage.internal', {
            method: 'POST', body: JSON.stringify({ key }),
          });
        } catch { return send(503); }
        if (quota.status !== 204) return send(quota.status === 429 ? 429 : 503);
      }
      // One attempt: no automatic retries and no other provider.
      const answer = await askClaude(body, env.ANTHROPIC_API_KEY, controller.signal, fetchClaude,
        translating ? data => validateTranslation(data, itemCount) : validateDraft);
      if (controller.signal.aborted) return send(504);
      return answer.result ?
        send(200, { ...(translating ? answer.result : { draft: answer.result }), model: CLAUDE_MODEL, provider: 'claude' }) :
        // Never expose raw provider errors, keys or requests.
        send(answer.status, { error: messages[answer.status], providerStatus: answer.providerStatus, reason: answer.reason });
    } catch { return send(controller.signal.aborted ? 504 : 502); }
    finally { clearTimeout(timer); request.signal.removeEventListener('abort', cancel); }
  };
}

export default { fetch: createReceiptHandler() };
