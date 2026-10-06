import { receiptSchema, receiptInstructions, validateDraft } from './contract.mjs';

export const GEMINI_MODEL = 'gemini-3.5-flash-lite';
const endpoint = 'https://generativelanguage.googleapis.com/v1beta/interactions';
const maxBody = 12_100_000;
// Google's terms require Paid Services for API clients available in these regions.
const paidOnlyRegions = new Set('AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE IS LI NO CH GB'.split(' '));
const messages = {
  400: '사진을 읽지 못했어요. 다시 촬영해주세요.',
  401: '접속 코드를 확인해주세요.',
  403: '영수증 서버의 연결 권한을 확인해주세요.',
  413: '사진이 너무 커요. 다시 촬영해주세요.',
  429: '무료 인식 한도에 도달했어요. 잠시 후 다시 시도하거나 수동으로 입력해주세요.',
  502: '인식하지 못했어요. 다시 시도하거나 수동으로 입력해주세요.',
  503: 'Gemini 무료 연결 설정이 필요해요. 수동 입력을 이용해주세요.',
  504: '인식 시간이 초과됐어요. 다시 시도하거나 수동으로 입력해주세요.',
};

export function geminiBody(image) {
  if (typeof image !== 'string' || image.length > 12_000_000) throw new Error('invalid_image');
  const match = /^data:image\/(jpeg|png|webp);base64,([A-Za-z0-9+/]+={0,2})$/.exec(image);
  if (!match || match[2].length % 4 !== 0) throw new Error('invalid_image');
  const head = atob(match[2].slice(0, 24));
  if (!(match[1] === 'jpeg' ? head.startsWith('\xff\xd8\xff') : match[1] === 'png' ?
    head.startsWith('\x89PNG\r\n\x1a\n') : head.startsWith('RIFF') && head.slice(8, 12) === 'WEBP')) throw new Error('invalid_image');
  return {
    model: GEMINI_MODEL, store: false,
    system_instruction: `${receiptInstructions}\nUse exactly this JSON schema: ${JSON.stringify(receiptSchema)}`,
    input: [
      { type: 'text', text: '영수증의 상호명, 최종 결제금액, 품목과 수량을 읽고 확인할 항목을 알려주세요.' },
      { type: 'image', mime_type: `image/${match[1]}`, data: match[2] },
    ],
    generation_config: { max_output_tokens: 8192 },
    // Native JSON mode; the full receipt contract is enforced by validateDraft.
    response_format: { type: 'text', mime_type: 'application/json' },
  };
}

export function readGemini(data) {
  if (data?.status !== 'completed' || data?.model !== GEMINI_MODEL || !Array.isArray(data?.steps)) throw new Error('incomplete_draft');
  if (data.steps.some(step => !['thought', 'model_output'].includes(step.type))) throw new Error('invalid_draft');
  const outputs = data.steps.filter(step => step.type === 'model_output');
  if (outputs.length !== 1 || !Array.isArray(outputs[0].content)) throw new Error('invalid_draft');
  const parts = outputs[0].content;
  if (!parts.length || parts.some(part => part.type !== 'text' || typeof part.text !== 'string')) throw new Error('invalid_draft');
  const output = parts.map(part => part.text).join('');
  if (output.length > 250_000) throw new Error('invalid_draft');
  return validateDraft(JSON.parse(output));
}

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

export function createGeminiHandler({ fetchGemini = fetch, timeoutMs = 85_000 } = {}) {
  return async (request, env) => {
    const origin = request.headers.get('Origin');
    const allowed = (env.RECEIPT_ALLOWED_ORIGINS ?? 'https://donghaha03.github.io').split(',').map(x => x.trim());
    const headers = { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', 'Vary': 'Origin' };
    if (origin && allowed.includes(origin)) headers['Access-Control-Allow-Origin'] = origin;
    const send = (status, data = { error: messages[status] }) => new Response(status === 204 ? null : JSON.stringify(data), { status, headers });
    if (origin && !allowed.includes(origin)) return send(403);
    const url = new URL(request.url);
    if (url.search || !['/receipt/recognize', '/receipt/status'].includes(url.pathname)) return send(404, {});
    if (request.method === 'OPTIONS') {
      headers['Access-Control-Allow-Methods'] = 'GET, POST';
      headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type';
      return send(204);
    }
    const configured = env.GEMINI_FREE_TIER_CONFIRMED === 'yes' && env.RECEIPT_FREE_HOSTING_CONFIRMED === 'yes' &&
      typeof env.GEMINI_API_KEY === 'string' && env.GEMINI_API_KEY.length > 20 &&
      /^[A-Za-z0-9_-]{32,128}$/.test(env.RECEIPT_ACCESS_CODE ?? '') &&
      !/^(AIza|sk-)/.test(env.RECEIPT_ACCESS_CODE) && env.RECEIPT_ACCESS_CODE !== env.GEMINI_API_KEY;
    if (url.pathname === '/receipt/status') return request.method === 'GET' ?
      send(200, { configured, provider: 'gemini', model: GEMINI_MODEL,
        placement: /^(local|remote)-[A-Z]{3}$/.test(request.headers.get('cf-placement') ?? '') ? request.headers.get('cf-placement') : null }) : send(405, {});
    if (request.method !== 'POST') return send(405, {});
    if (paidOnlyRegions.has(request.cf?.country)) return send(403);
    if (!configured) return send(503);
    if (!await validCode(/^Bearer ([A-Za-z0-9_-]+)$/.exec(request.headers.get('Authorization') ?? '')?.[1] ?? '', env.RECEIPT_ACCESS_CODE)) return send(401);
    if (!/^application\/json(?:\s*;|$)/i.test(request.headers.get('Content-Type') ?? '')) return send(400);
    const controller = new AbortController();
    const cancel = () => controller.abort();
    request.signal.addEventListener('abort', cancel, { once: true });
    if (request.signal.aborted) cancel();
    const timer = setTimeout(cancel, timeoutMs);
    try {
      let body;
      try {
        const data = await readBody(request, maxBody, controller.signal);
        if (!data || Array.isArray(data) || Object.keys(data).length !== 1) throw new Error('invalid_body');
        body = geminiBody(data.image);
      } catch (error) { return send(controller.signal.aborted ? 504 : error.message === 'too_large' ? 413 : 400); }
      if (controller.signal.aborted) return send(504);
      // ponytail: presentation pilot, shared access code and Google's Free Tier quota;
      // add per-user auth/persistent quotas before public signup. Never retry/upgrade automatically.
      const upstream = await fetchGemini(endpoint, {
        method: 'POST', signal: controller.signal,
        headers: { 'x-goog-api-key': env.GEMINI_API_KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (!upstream.ok) {
        const status = upstream.status === 429 ? 429 : 502;
        let reason = 'UPSTREAM_ERROR';
        try {
          const failure = await readBody(upstream, 64_000, controller.signal);
          const code = typeof failure?.error?.code === 'string' ? failure.error.code.toUpperCase() : failure?.error?.status;
          if (['INVALID_ARGUMENT', 'INVALID_REQUEST', 'UNAUTHENTICATED', 'PERMISSION_DENIED', 'NOT_FOUND', 'RESOURCE_EXHAUSTED', 'UNAVAILABLE', 'SERVICE_UNAVAILABLE', 'FAILED_PRECONDITION'].includes(code)) reason = code;
          if (upstream.status === 400 && /response_format|schema/i.test(failure?.error?.message ?? '')) reason = 'INVALID_RESPONSE_FORMAT';
          if (failure?.error?.message?.includes('API key not valid')) reason = 'API_KEY_INVALID';
          if (/location.*(not supported|unsupported)|unsupported.*location/i.test(failure?.error?.message ?? '')) reason = 'LOCATION_UNSUPPORTED';
          else if (/free tier.*(not available|unavailable|country|region)/i.test(failure?.error?.message ?? '')) reason = 'FREE_TIER_REGION_UNAVAILABLE';
          else if (/enable billing|billing.*(required|enabled)/i.test(failure?.error?.message ?? '')) reason = 'BILLING_REQUIRED';
        } catch { reason = 'INVALID_PROVIDER_ERROR_BODY'; /* Never expose raw errors, keys or requests. */ }
        return send(status, { error: messages[status], providerStatus: upstream.status, reason });
      }
      const draft = readGemini(await readBody(upstream, 1_000_000, controller.signal));
      if (controller.signal.aborted) return send(504);
      return send(200, { draft, model: GEMINI_MODEL, provider: 'gemini' });
    } catch { return send(controller.signal.aborted ? 504 : 502); }
    finally { clearTimeout(timer); request.signal.removeEventListener('abort', cancel); }
  };
}

export default { fetch: createGeminiHandler() };
