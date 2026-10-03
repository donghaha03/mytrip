// 공식 easycodef-node의 OAuth·URI 인코딩 규약. 오래된 request 의존성은 쓰지 않는다.
export function createCodefClient({ clientId, clientSecret, mode, fetcher = fetch }) {
  if (!clientId || !clientSecret || !['demo', 'production'].includes(mode)) throw new Error('제공자 설정 확인 필요');
  const host = mode === 'demo' ? 'https://development.codef.io' : 'https://api.codef.io';
  let token = '';
  let expiresAt = 0;
  async function authenticate() {
    const response = await fetcher('https://oauth.codef.io/oauth/token', {
      method: 'POST', redirect: 'error', signal: AbortSignal.timeout(10000),
      headers: { 'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString('base64')}` },
      body: 'grant_type=client_credentials&scope=read',
    });
    if (!response.ok) throw new Error('제공자 인증 실패');
    const data = await response.json();
    if (typeof data.access_token !== 'string' || !data.access_token) throw new Error('제공자 인증 실패');
    token = data.access_token;
    expiresAt = Date.now() + (Number.isFinite(Number(data.expires_in)) ? Math.max(0, Number(data.expires_in) - 60) : 0) * 1000;
  }
  return async (params, path = '/v1/kr/card/p/account/approval-list') => {
    if (!['/v1/kr/card/p/account/approval-list', '/v1/kr/card/p/account/card-list', '/v1/account/create', '/v1/account/delete'].includes(path)) throw new Error('허용되지 않은 조회');
    if (!token || Date.now() >= expiresAt) await authenticate();
    for (let attempt = 0; attempt < 2; attempt++) {
      const response = await fetcher(`${host}${path}`, {
        method: 'POST', redirect: 'error', signal: AbortSignal.timeout(300000),
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: encodeURIComponent(JSON.stringify(params)),
      });
      if (response.status === 401 && attempt === 0) { await authenticate(); continue; }
      if (!response.ok) throw new Error('카드 조회 실패');
      const raw = await response.text();
      if (raw.length > 10000000) throw new Error('조회 응답 크기 초과');
      try { return JSON.parse(raw); }
      catch { return JSON.parse(decodeURIComponent(raw.replaceAll('+', ' '))); }
    }
    throw new Error('제공자 인증 실패');
  };
}
