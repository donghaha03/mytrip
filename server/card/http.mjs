import { validateTripId } from './sync.mjs';

export function createHandler({ verifyToken, synchronize, connections, allowedUids, allowedOrigin }) {
  return async (req, res) => {
    const origin = req.headers.origin;
    if (origin && origin !== allowedOrigin) { res.writeHead(403).end(); return; }
    if (origin) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Vary', 'Origin');
    }
    res.setHeader('Cache-Control', 'no-store');
    if (req.method === 'OPTIONS') {
      res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
      res.setHeader('Access-Control-Allow-Methods', 'POST');
      res.writeHead(204).end(); return;
    }
    const action = /^\/connection\/(status|authenticate|select|disconnect)$/.exec(req.url)?.[1];
    if (req.method !== 'POST' || (req.url !== '/sync' && (!action || !connections))) { res.writeHead(404).end(); return; }
    const token = /^Bearer (\S+)$/.exec(req.headers.authorization ?? '')?.[1];
    let uid;
    try { uid = token ? (await verifyToken(token)).uid : null; } catch { /* 인증정보는 로그에 남기지 않는다. */ }
    if (typeof uid !== 'string' || !/^[A-Za-z0-9:_-]{1,128}$/.test(uid)) { res.writeHead(401).end(); return; }
    if (allowedUids && !allowedUids.has(uid)) { res.writeHead(403).end(); return; }
    try {
      const chunks = [];
      let bytes = 0;
      for await (const chunk of req) {
        bytes += chunk.length;
        if (bytes > 2048) { res.writeHead(413).end(); return; }
        chunks.push(chunk);
      }
      let body;
      try { body = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks))); }
      catch { res.writeHead(400).end(); return; }
      const fields = action === 'authenticate' ? ['tripId', 'organization', 'loginId', 'password', 'consent', 'consentVersion'] :
        action === 'select' ? ['tripId', 'cardKey'] : ['tripId'];
      if (!body || typeof body !== 'object' || Array.isArray(body) || Object.keys(body).some(k => !fields.includes(k))) {
        res.writeHead(400).end(); return;
      }
      let tripId;
      try { tripId = ['status', 'disconnect'].includes(action) && body.tripId === undefined ? undefined : validateTripId(body.tripId); }
      catch { res.writeHead(400).end(); return; }
      const result = action ? await connections(uid, action, { ...body, tripId }) : await synchronize(uid, tripId);
      res.writeHead(200, { 'Content-Type': 'application/json' }).end(JSON.stringify(result));
    } catch (error) {
      const code = error instanceof SyntaxError ? 400 : [400, 404, 409, 422, 423, 429, 503].includes(error.status) ? error.status : 502;
      res.writeHead(code, { 'Content-Type': 'application/json' }).end(JSON.stringify({ error: '카드 내역 확인 실패' }));
    }
  };
}
