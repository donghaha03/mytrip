// Public API runtime. ChatGPT subscription credentials are never imported here.
import http from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { inferenceBody, readInference, MODEL } from './index.mjs';

const messages = {
  400: '사진을 읽지 못했어요. 다른 사진으로 다시 시도해주세요.',
  401: '접속 코드를 확인해주세요.',
  403: '이 주소에서는 영수증 서버에 접속할 수 없어요.',
  413: '사진이 너무 커요. 다시 촬영하거나 다른 사진을 선택해주세요.',
  429: '인식 요청이 많아요. 잠시 후 다시 시도하거나 수동으로 입력해주세요.',
  502: '영수증을 인식하지 못했어요. 다시 시도하거나 수동으로 입력해주세요.',
  504: '인식 시간이 초과됐어요. 다시 시도하거나 수동으로 입력해주세요.',
};

export function remoteConfig(env = process.env) {
  if (env.RECEIPT_ALLOW_API_BILLING !== 'yes') throw new Error('API 비용 승인 후 RECEIPT_ALLOW_API_BILLING=yes를 설정하세요.');
  if (!env.OPENAI_API_KEY) throw new Error('서버 비밀 저장소에 OPENAI_API_KEY가 필요합니다.');
  if (!/^[A-Za-z0-9_-]{32,128}$/.test(env.RECEIPT_ACCESS_CODE ?? '')) throw new Error('32자 이상 무작위 RECEIPT_ACCESS_CODE가 필요합니다.');
  const allowedOrigins = (env.RECEIPT_ALLOWED_ORIGINS ?? 'https://donghaha03.github.io').split(',').map(s => s.trim());
  for (const value of allowedOrigins) {
    const url = new URL(value);
    if (url.origin !== value || (url.protocol !== 'https:' && !(url.protocol === 'http:' && ['127.0.0.1', 'localhost'].includes(url.hostname)))) throw new Error('정확한 HTTPS Origin을 설정하세요.');
  }
  const dailyLimit = Number(env.RECEIPT_DAILY_LIMIT ?? 50);
  if (!Number.isSafeInteger(dailyLimit) || dailyLimit < 1 || dailyLimit > 1000) throw new Error('RECEIPT_DAILY_LIMIT는 1~1000이어야 합니다.');
  return { apiKey: env.OPENAI_API_KEY, accessCode: env.RECEIPT_ACCESS_CODE, allowedOrigins, dailyLimit };
}

export function createRemoteHandler({ apiKey, accessCode, allowedOrigins, dailyLimit, fetchOpenAI = fetch, timeoutMs = 85_000, now = Date.now }) {
  const expected = Buffer.from(accessCode);
  // ponytail: one pilot server, process-local daily quota. Restarts reset it;
  // use a persistent quota and per-user authentication before multi-instance/public signup.
  let day, used = 0, busy = false;
  return async (req, res) => {
    const send = (status, data = {}) => {
      if (!res.destroyed) res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' }).end(JSON.stringify(data));
    };
    const origin = req.headers.origin;
    if (origin && !allowedOrigins.includes(origin)) return send(403, { error: messages[403] });
    if (origin) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Vary', 'Origin');
    }
    if (req.url !== '/receipt/recognize') return send(404);
    if (req.method === 'OPTIONS') {
      res.setHeader('Access-Control-Allow-Methods', 'POST');
      res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
      return send(204);
    }
    if (req.method !== 'POST') return send(405);
    const supplied = Buffer.from(/^Bearer ([A-Za-z0-9_-]+)$/.exec(req.headers.authorization ?? '')?.[1] ?? '');
    if (supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) return send(401, { error: messages[401] });
    if (!/^application\/json(?:\s*;|$)/i.test(req.headers['content-type'] ?? '')) return send(400, { error: messages[400] });
    const currentDay = new Date(now()).toISOString().slice(0, 10);
    if (day !== currentDay) { day = currentDay; used = 0; }
    if (busy || used >= dailyLimit) return send(429, { error: messages[429] });
    busy = true;
    const controller = new AbortController();
    const cancel = () => { if (!res.writableEnded) controller.abort(); };
    res.on('close', cancel);
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const chunks = []; let bytes = 0;
      for await (const chunk of req) {
        bytes += chunk.length;
        if (bytes > 12_100_000) return send(413, { error: messages[413] });
        chunks.push(chunk);
      }
      let body;
      try {
        const data = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks)));
        if (!data || Array.isArray(data) || Object.keys(data).length !== 1) throw new Error();
        body = inferenceBody(data.image); // Same image/prompt/schema/model as the local runtime.
      } catch { return send(400, { error: messages[400] }); }
      if (controller.signal.aborted) return send(504, { error: messages[504] });
      used++; // Failed provider requests count too; automatic retries could multiply charges.
      const upstream = await fetchOpenAI('https://api.openai.com/v1/responses', {
        method: 'POST', signal: controller.signal,
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (!upstream.ok) {
        await upstream.body?.cancel();
        const status = upstream.status === 429 ? 429 : 502;
        return send(status, { error: messages[status] });
      }
      const draft = await readInference(upstream.body);
      if (!controller.signal.aborted) return send(200, { draft, model: MODEL });
    } catch {
      const status = controller.signal.aborted ? 504 : 502;
      send(status, { error: messages[status] }); // Never return provider errors, credentials or receipt logs.
    } finally {
      clearTimeout(timer); res.off('close', cancel); busy = false;
    }
  };
}

export function startRemoteServer(config = remoteConfig()) {
  const server = http.createServer(createRemoteHandler(config));
  server.requestTimeout = 90_000;
  server.headersTimeout = 15_000;
  server.listen(Number(process.env.PORT ?? 8080), process.env.HOST ?? '127.0.0.1');
  return server;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) startRemoteServer();
