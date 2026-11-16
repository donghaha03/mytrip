// Local Windows runtime only. Never reads another application's credentials.
import http from 'node:http';
import { randomBytes, randomUUID, createHash } from 'node:crypto';
import { mkdir, readFile, writeFile, rename, open, unlink } from 'node:fs/promises';
import { resolve, dirname, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { receiptSchema, receiptInstructions } from './contract.mjs';
export { receiptSchema } from './contract.mjs';

export const MODEL = 'gpt-5.6-sol';
const RESOURCE = 'https://api.openai.com/v1';
const AUTH = 'https://auth.openai.com';
const SCOPES = 'openid profile email offline_access resource.invoke chatgpt.tokens.use.direct';
const random = () => randomBytes(32).toString('base64url');
export function inferenceBody(image) {
  if (typeof image !== 'string' || image.length > 12_000_000 ||
      !/^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/]+={0,2}$/.test(image)) throw new Error('invalid_image');
  return {
    model: MODEL, store: false, stream: true,
    instructions: receiptInstructions,
    input: [{ role: 'user', content: [{ type: 'input_text', text: '영수증을 읽고 원본 확인이 필요한 항목도 알려주세요.' },
      { type: 'input_image', image_url: image, detail: 'high' }] }],
    text: { format: { type: 'json_schema', name: 'receipt', strict: true, schema: receiptSchema } },
  };
}

// A partial or failed stream must never become a review draft.
export async function readInference(body) {
  let buffer = '', output = '', completed = false;
  const decoder = new TextDecoder();
  for await (const chunk of body) {
    buffer = (buffer + decoder.decode(chunk, { stream: true })).replace(/\r\n/g, '\n');
    if (buffer.length > 1_000_000) throw new Error('invalid_draft');
    let boundary;
    while ((boundary = buffer.indexOf('\n\n')) >= 0) {
      const block = buffer.slice(0, boundary); buffer = buffer.slice(boundary + 2);
      const data = block.split('\n').filter(line => line.startsWith('data:')).map(line => line.slice(5).trimStart()).join('\n');
      if (!data || data === '[DONE]') continue;
      const event = JSON.parse(data);
      if (event.type === 'response.output_item.added' && !['message', 'reasoning'].includes(event.item?.type)) throw new Error('unexpected_tool_request');
      if (event.type === 'response.output_text.delta') output += event.delta;
      if (output.length > 250_000) throw new Error('invalid_draft');
      if (event.type === 'response.failed' || event.type === 'error') throw new Error(event.response?.error?.code ?? event.code ?? 'inference_failed');
      if (event.type === 'response.incomplete') throw new Error('inference_incomplete');
      if (event.type === 'response.completed') {
        if (event.response?.status !== 'completed') throw new Error('inference_incomplete');
        completed = true;
      }
    }
  }
  if (!completed || !output || buffer.trim()) throw new Error('inference_interrupted');
  const draft = JSON.parse(output);
  if (!draft || !Array.isArray(draft.items) || draft.items.length > 100 ||
      !Array.isArray(draft.warnings) || draft.warnings.some(w => typeof w !== 'string')) throw new Error('invalid_draft');
  return draft;
}

function protect(value, decrypt = false) {
  // Windows DPAPI binds the encrypted credential file to the current OS user.
  return new Promise((resolvePromise, reject) => {
    const method = decrypt ? 'Unprotect' : 'Protect';
    const code = `Add-Type -AssemblyName System.Security; $inputData=[Console]::In.ReadToEnd(); $bytes=[Convert]::FromBase64String($inputData); $result=[Security.Cryptography.ProtectedData]::${method}($bytes,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser); [Console]::Out.Write([Convert]::ToBase64String($result))`;
    const child = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', code], { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    let result = ''; child.stdout.on('data', data => { result += data; });
    child.stderr.resume(); child.on('error', reject);
    child.on('exit', status => status === 0 ? resolvePromise(Buffer.from(result, 'base64')) : reject(new Error('credential_storage_failed')));
    child.stdin.end(value.toString('base64'));
  });
}
async function jsonFetch(url, options = {}) {
  const response = await fetch(url, { ...options, signal: options.signal ?? AbortSignal.timeout(30_000) });
  if (!response.ok) throw new Error(`openai_http_${response.status}`);
  return response.json();
}
const tokenRequest = fields => jsonFetch(`${AUTH}/api/accounts/oauth/token`, {
  method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({ ...fields, resource: RESOURCE }),
});
const message = code => ({
  login_required: '전용 연결 화면에서 ChatGPT 로그인과 구독 사용 동의를 완료해주세요.',
  model_unavailable: '이 계정의 모델 목록에 GPT-5.6 Sol이 없어요. 다른 모델로 바꾸지 않았어요.',
  subscription_sharing_usage_limit_exceeded: 'ChatGPT 구독 사용 한도에 도달했어요. 사용량 설정을 확인해주세요.',
  subscription_sharing_usage_unavailable: '이 계정에서는 ChatGPT 구독 사용이 허용되지 않았어요.',
  invalid_state: '로그인 요청이 만료되었거나 일치하지 않아요. 다시 로그인해주세요.',
  access_denied: 'ChatGPT 연결 동의가 취소되었어요.',
  invalid_draft: '인식 결과 형식이 올바르지 않아요. 재시도해주세요.',
  inference_interrupted: '인식 연결이 끊겼어요. 재시도해주세요.',
})[code] ?? '처리를 완료하지 못했어요. 다시 시도하거나 수동으로 입력해주세요.';

export async function startServer({ port = 8765, webRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../../build/web'),
  directory = resolve(process.env.LOCALAPPDATA, 'mytrip-receipt') } = {}) {
  if (process.platform !== 'win32') throw new Error('This runtime requires Windows DPAPI.');
  await mkdir(directory, { recursive: true });
  // One owner prevents concurrent refresh-token rotation across runtimes.
  const lockPath = resolve(directory, 'runtime.lock');
  try {
    const owner = Number(await readFile(lockPath, 'utf8'));
    if (Number.isSafeInteger(owner) && owner > 0) {
      try { process.kill(owner, 0); } catch (error) { if (error.code === 'ESRCH') await unlink(lockPath); }
    }
  } catch (error) { if (error.code !== 'ENOENT') throw error; }
  const lock = await open(lockPath, 'wx').catch(() => { throw new Error('Receipt runtime already running; stop it before restarting.'); });
  await lock.writeFile(String(process.pid));
  const credentialPath = resolve(directory, 'accounts.dpapi');
  let saved;
  try { saved = JSON.parse((await protect(await readFile(credentialPath), true)).toString('utf8')); }
  catch (error) { if (error.code !== 'ENOENT') { await lock.close(); await unlink(lockPath); throw error; } }
  saved ??= { host: `urn:uuid:${randomUUID()}`, accounts: [], active: null };
  const persist = async () => {
    await writeFile(`${credentialPath}.tmp`, await protect(Buffer.from(JSON.stringify(saved))));
    await rename(`${credentialPath}.tmp`, credentialPath);
  };
  try { await persist(); } catch (error) { await lock.close(); await unlink(lockPath); throw error; }
  const origin = `http://127.0.0.1:${port}`, csrf = random(), transactions = new Map();
  const jwks = createRemoteJWKSet(new URL(`${AUTH}/.well-known/jwks.json`));
  let refresh, recognizing = false;
  const activeAccount = () => saved.accounts.find(a => a.client_id === saved.active);
  const accessToken = async () => {
    const account = activeAccount();
    if (!account?.access_token) throw new Error('login_required');
    if (account.expires_at > Date.now() + 60_000) return account.access_token;
    refresh ??= (async () => {
      const tokens = await tokenRequest({ grant_type: 'refresh_token', client_id: account.client_id, refresh_token: account.refresh_token });
      if (!tokens.access_token || !tokens.refresh_token || !Number.isFinite(tokens.expires_in) ||
          !tokens.scope?.split(' ').includes('chatgpt.tokens.use.direct')) throw new Error('login_required');
      Object.assign(account, tokens, { expires_at: Date.now() + tokens.expires_in * 1000 });
      await persist(); return account.access_token;
    })();
    try { return await refresh; } finally { refresh = undefined; }
  };
  const models = async () => {
    const data = await jsonFetch(`${RESOURCE}/models`, { headers: { Authorization: `Bearer ${await accessToken()}` } });
    if (!data.models?.some(m => m.slug === MODEL && m.visibility === 'list')) throw new Error('model_unavailable');
  };
  const server = http.createServer(async (req, res) => {
    const send = (value, status = 200, type = 'application/json') => {
      if (!res.destroyed) { res.writeHead(status, { 'Content-Type': `${type}; charset=utf-8`, 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'no-referrer' }); res.end(type === 'application/json' ? JSON.stringify(value) : value); }
    };
    try {
      if (req.headers.host !== `127.0.0.1:${port}` || (req.headers.origin && req.headers.origin !== origin)) return send({ error: 'forbidden' }, 403);
      const url = new URL(req.url, origin);
      if (req.method === 'POST' && (req.headers.origin !== origin || req.headers['x-mytrip-csrf'] !== csrf)) return send({ error: 'forbidden' }, 403);
      if (url.pathname === '/receipt-client.js' && req.method === 'GET') return send(`window.mytripReceiptLLM={csrf:${JSON.stringify(csrf)}};`, 200, 'text/javascript');
      if (url.pathname === '/receipt/status' && req.method === 'GET') return send({ connected: !!activeAccount()?.access_token, model: MODEL,
        accounts: saved.accounts.map(a => ({ id: a.client_id, label: `${a.email ?? 'ChatGPT'} (${a.client_id.slice(-8)})`, active: a.client_id === saved.active })) });
      if (url.pathname === '/receipt-connect' && req.method === 'GET') return send(`<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>mytrip 영수증 연결</title><style>body{font:16px system-ui;max-width:580px;margin:40px auto;padding:20px;line-height:1.7}button,select{padding:12px;margin:8px;font:inherit}pre{white-space:pre-wrap}</style><h1>영수증 ChatGPT 연결</h1><p>사진을 OpenAI로 보내 GPT-5.6 Sol로 읽습니다. 기존 ChatGPT 구독 한도를 공유합니다. 동의 화면에서 크레딧 추가 사용은 허용하지 마세요.</p><select id="account"><option value="new">새 계정 연결</option></select><button id="login">Continue with ChatGPT</button><button id="check">연결·모델 확인</button><button id="logout">로그아웃</button><pre id="status"></pre><p><a href="https://chatgpt.com/settings/usage" target="_blank" rel="noreferrer">ChatGPT 사용량·앱 연결 관리</a> · <a href="/">mytrip 열기</a></p><script>
        const csrf=${JSON.stringify(csrf)}; const status=document.querySelector('#status'),account=document.querySelector('#account');
        const post=async(path,body={})=>{const r=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json','X-mytrip-csrf':csrf},body:JSON.stringify(body)});const d=await r.json();if(!r.ok)throw Error(d.error);return d;};
        fetch('/receipt/status').then(r=>r.json()).then(d=>{for(const a of d.accounts){const o=new Option(a.label,a.id);account.add(o);if(a.active)account.value=a.id;}status.textContent=d.connected?'로그인됨 · 모델 확인을 눌러 접근 권한을 확인해주세요.':'ChatGPT 로그인이 필요합니다.';});
        document.querySelector('#login').onclick=async()=>{try{const d=await post('/receipt/login',{account:account.value});location.assign(d.url);}catch(e){status.textContent=e.message;}};
        document.querySelector('#check').onclick=async()=>{try{await post('/receipt/check');status.textContent='GPT-5.6 Sol 사용 가능 · mytrip 촬영 화면에서 ChatGPT로 인식하세요.';}catch(e){status.textContent=e.message;}};
        document.querySelector('#logout').onclick=async()=>{try{const d=await post('/receipt/logout');status.textContent=d.message;}catch(e){status.textContent=e.message;}};
        </script></html>`, 200, 'text/html');
      if (url.pathname === '/auth/callback' && req.method === 'GET') {
        const state = url.searchParams.get('state'), pending = transactions.get(state); transactions.delete(state);
        if (!pending || pending.expires < Date.now() || !req.headers.cookie?.split('; ').includes(`mytrip_login=${pending.browser}`)) throw new Error('invalid_state');
        if (url.searchParams.has('error')) throw new Error('access_denied');
        const client = url.searchParams.get('client_id') ?? pending.client;
        if (!client || client === 'dynamic_agent_client' || (pending.client && client !== pending.client)) throw new Error('invalid_state');
        const code = url.searchParams.get('code'); if (!code) throw new Error('invalid_state');
        const tokens = await tokenRequest({ grant_type: 'authorization_code', client_id: client, code, code_verifier: pending.verifier, redirect_uri: `${origin}/auth/callback` });
        const { payload } = await jwtVerify(tokens.id_token, jwks, { issuer: AUTH, audience: client, algorithms: ['RS256'], requiredClaims: ['sub', 'exp', 'iat'], clockTolerance: 5 });
        if (payload.nonce !== pending.nonce || !payload.sub || (pending.subject && payload.sub !== pending.subject) ||
            !tokens.scope?.split(' ').includes('chatgpt.tokens.use.direct') || !tokens.access_token || !tokens.refresh_token || !Number.isFinite(tokens.expires_in)) throw new Error('login_required');
        const account = { ...tokens, client_id: client, subject: payload.sub, email: payload.email, expires_at: Date.now() + tokens.expires_in * 1000 };
        saved.accounts = [...saved.accounts.filter(a => a.client_id !== client), account]; saved.active = client; await persist();
        res.setHeader('Set-Cookie', 'mytrip_login=; HttpOnly; SameSite=Lax; Path=/auth/callback; Max-Age=0');
        res.writeHead(303, { Location: '/receipt-connect', 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer' }); return res.end();
      }
      if (req.method === 'POST' && url.pathname.startsWith('/receipt/')) {
        let input = ''; for await (const chunk of req) { input += chunk; if (input.length > 12_100_000) throw new Error('invalid_image'); }
        const data = JSON.parse(input || '{}');
        if (url.pathname === '/receipt/login') {
          const account = saved.accounts.find(a => a.client_id === data.account);
          if (data.account !== 'new' && !account) throw new Error('invalid_state');
          const verifier = random(), state = random(), nonce = random(), browser = random();
          for (const [key, attempt] of transactions) if (attempt.expires < Date.now()) transactions.delete(key);
          transactions.set(state, { verifier, nonce, browser, client: account?.client_id, subject: account?.subject, expires: Date.now() + 600_000 });
          const authorize = new URL(`${AUTH}/api/accounts/authorize`);
          authorize.search = new URLSearchParams({ client_id: account?.client_id ?? 'dynamic_agent_client', ext_agent_host_id: saved.host,
            ...(account ? (account.id_token ? { id_token_hint: account.id_token } : {}) : { agent_name_hint: 'mytrip' }),
            response_type: 'code', redirect_uri: `${origin}/auth/callback`, scope: SCOPES, resource: RESOURCE, state, nonce,
            code_challenge_method: 'S256', code_challenge: createHash('sha256').update(verifier).digest('base64url') }).toString();
          res.setHeader('Set-Cookie', `mytrip_login=${browser}; HttpOnly; SameSite=Lax; Path=/auth/callback; Max-Age=600`);
          return send({ url: authorize.href });
        }
        if (url.pathname === '/receipt/check') { await models(); return send({ model: MODEL }); }
        if (url.pathname === '/receipt/logout') {
          if (recognizing || refresh) return send({ error: '인식이 끝난 뒤 로그아웃해주세요.' }, 409);
          const account = activeAccount(); let revoked = true;
          if (account?.refresh_token) {
            try {
              const discovery = await jsonFetch(`${AUTH}/.well-known/openid-configuration`);
              if (new URL(discovery.revocation_endpoint).origin !== AUTH) throw new Error('invalid_endpoint');
              const response = await fetch(discovery.revocation_endpoint, { method: 'POST', signal: AbortSignal.timeout(30_000),
                body: new URLSearchParams({ client_id: account.client_id, token: account.refresh_token, token_type_hint: 'refresh_token' }) });
              revoked = response.status === 200;
            } catch { revoked = false; }
            for (const key of ['access_token', 'refresh_token', 'id_token']) delete account[key]; await persist();
          }
          return send({ message: revoked ? '로그아웃했습니다.' : '로컬 로그아웃 완료. 원격 연결 해제를 확인하지 못했어요. ChatGPT 설정에서 mytrip 연결을 해제해주세요.' });
        }
        if (url.pathname === '/receipt/recognize') {
          const body = inferenceBody(data.image);
          if (recognizing) return send({ error: '다른 영수증을 인식 중이에요.' }, 409);
          recognizing = true;
          const controller = new AbortController();
          const cancel = () => { if (!res.writableEnded) controller.abort(); };
          res.on('close', cancel); const timeout = setTimeout(() => controller.abort(), 85_000);
          try {
            await models();
            if (controller.signal.aborted) throw new Error('inference_interrupted');
            const response = await fetch(`${RESOURCE}/responses`, { method: 'POST', signal: controller.signal,
              headers: { Authorization: `Bearer ${await accessToken()}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
            if (!response.ok) {
              const error = await response.json().catch(() => ({})); throw new Error(error.error?.code ?? `openai_http_${response.status}`);
            }
            return send({ draft: await readInference(response.body) });
          } finally { recognizing = false; clearTimeout(timeout); res.off('close', cancel); }
        }
        return send({ error: 'not_found' }, 404);
      }
      if (req.method !== 'GET') return send({ error: 'not_found' }, 404);
      const path = resolve(webRoot, `.${decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname)}`);
      if (!path.startsWith(resolve(webRoot) + sep)) return send({ error: 'forbidden' }, 403);
      let bytes = await readFile(path);
      const mime = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml', '.jpg': 'image/jpeg', '.woff2': 'font/woff2' }[extname(path)] ?? 'application/octet-stream';
      if (path === resolve(webRoot, 'index.html')) bytes = Buffer.from(bytes.toString().replace('<head>', '<head><script src="/receipt-client.js"></script>'));
      res.writeHead(200, { 'Content-Type': mime, 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'no-referrer' }); res.end(bytes);
    } catch (error) {
      if (req.url?.startsWith('/auth/callback')) return send(`<meta charset="utf-8"><p>${message(error.message)}</p><a href="/receipt-connect">전용 연결 화면으로 돌아가기</a>`, 400, 'text/html');
      send({ error: message(error.message) }, error.code === 'ENOENT' ? 404 : 400);
    }
  });
  server.requestTimeout = 120_000;
  server.on('close', async () => { await lock.close(); await unlink(lockPath); });
  try {
    await new Promise((resolvePromise, reject) => { server.once('error', reject); server.listen(port, '127.0.0.1', resolvePromise); });
  } catch (error) { await lock.close(); await unlink(lockPath); throw error; }
  return server;
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = await startServer();
  console.log('mytrip local receipt: http://127.0.0.1:8765/receipt-connect');
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close());
}
