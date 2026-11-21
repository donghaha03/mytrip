// 내 Firebase(mytrip-fddfb)의 Firestore rates/current 문서를 채운다.
// 팀 Cloud Function(functions/index.js 의 updateExchangeRates)과 같은 출처·같은 검증·같은
// 문서 형식이다. 내 프로젝트에는 그 함수가 없어서 GitHub Actions(.github/workflows/rates.yml)가
// 대신 돌린다. 의존성 없음(Node 20 이상).
//
//   node deploy/rates/update-rates.mjs --dry-run   환율만 가져와 쓸 문서를 출력 (쓰지 않음)
//   node deploy/rates/update-rates.mjs             FIREBASE_SERVICE_ACCOUNT 로 인증해 문서를 씀
//
// 서비스 계정 키·토큰은 어디에도 출력하지 않는다.
import { createSign } from 'node:crypto';
import { pathToFileURL } from 'node:url';

// 다른 프로젝트(특히 팀 프로젝트)의 키가 들어와도 쓰지 않도록 고정한다.
const PROJECT = 'mytrip-fddfb';
const RATE_API_URL = 'https://open.er-api.com/v6/latest/KRW';

/** 환율 API 응답을 검증해 { rates, providerLastUpdated } 로 만든다. 팀 함수와 같은 규칙. */
export function parseRates(data) {
  if (data?.result !== 'success') throw new Error('환율 API가 실패를 돌려줬어요.');
  if (data.base_code !== 'KRW') throw new Error('환율 기준 통화가 KRW가 아니에요.');
  if (!data.rates || typeof data.rates !== 'object' || Array.isArray(data.rates)) {
    throw new Error('환율 데이터 형식이 올바르지 않아요.');
  }
  const rates = {};
  for (const [currency, value] of Object.entries(data.rates)) {
    const rate = Number(value);
    if (/^[A-Z]{3}$/.test(currency) && Number.isFinite(rate) && rate > 0) rates[currency] = rate;
  }
  if (!Number.isFinite(rates.KRW) || Math.abs(rates.KRW - 1) > 0.000001) {
    throw new Error('KRW 기준값이 1이 아니에요.');
  }
  if (!rates.USD || !rates.JPY || !rates.EUR) throw new Error('주요 통화 환율이 없어요.');
  return { rates, providerLastUpdated: data.time_last_update_utc || null };
}

/** Firestore REST API 형식의 문서 필드. 앱(rate_api.dart)은 rates(Map)와 lastUpdated(Timestamp)를 읽는다. */
export function toFirestoreFields({ rates, providerLastUpdated }, now = new Date()) {
  return {
    base: { stringValue: 'KRW' },
    // 값 = 1원당 외화 금액. 앱이 1 / 값 으로 "외화 1단위당 원화"를 구한다.
    rates: {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(rates).map(([currency, rate]) => [currency, { doubleValue: rate }]),
        ),
      },
    },
    lastUpdated: { timestampValue: now.toISOString() },
    providerLastUpdated: providerLastUpdated
      ? { stringValue: providerLastUpdated }
      : { nullValue: null },
    source: { stringValue: 'open.er-api.com' },
  };
}

/** 서비스 계정 키로 서명한 JWT를 Firestore 쓰기용 액세스 토큰으로 바꾼다. */
async function accessToken(account) {
  const part = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const iat = Math.floor(Date.now() / 1000);
  const unsigned = `${part({ alg: 'RS256', typ: 'JWT' })}.${part({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    iat,
    exp: iat + 600,
  })}`;
  const signature = createSign('RSA-SHA256').update(unsigned).sign(account.private_key, 'base64url');
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${signature}`,
    }),
    signal: AbortSignal.timeout(15000),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok || !body.access_token) {
    throw new Error(`Google 인증 실패: HTTP ${response.status} ${body.error ?? ''}`);
  }
  return body.access_token;
}

function serviceAccount() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) throw new Error('FIREBASE_SERVICE_ACCOUNT 가 비어 있어요. GitHub Secret을 확인하세요.');
  let account;
  try {
    account = JSON.parse(raw);
  } catch {
    // JSON.parse 오류 문구에는 입력 일부가 들어가므로 그대로 내보내지 않는다.
    throw new Error('FIREBASE_SERVICE_ACCOUNT 가 JSON이 아니에요. 키 파일 내용 전체를 넣었는지 확인하세요.');
  }
  if (!account.client_email || !account.private_key) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT 에 client_email 또는 private_key 가 없어요.');
  }
  if (account.project_id !== PROJECT) {
    throw new Error(`이 키는 ${PROJECT} 프로젝트의 키가 아니에요. 쓰지 않고 멈춥니다.`);
  }
  return account;
}

async function main() {
  const response = await fetch(RATE_API_URL, { signal: AbortSignal.timeout(15000) });
  if (!response.ok) throw new Error(`환율 API HTTP ${response.status}`);
  const parsed = parseRates(await response.json());
  const fields = toFirestoreFields(parsed);
  console.log(`환율 ${Object.keys(parsed.rates).length}개, 제공처 갱신 ${parsed.providerLastUpdated}`);

  if (process.argv.includes('--dry-run')) {
    console.log(JSON.stringify({ fields }));
    return;
  }

  const token = await accessToken(serviceAccount());
  // updateMask 없는 PATCH = 문서 전체 교체 (팀 함수의 set() 과 같다). 실패하면 기존 문서는 그대로다.
  const saved = await fetch(
    `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/rates/current`,
    {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields }),
      signal: AbortSignal.timeout(15000),
    },
  );
  if (!saved.ok) {
    const body = await saved.json().catch(() => ({}));
    throw new Error(`Firestore 쓰기 실패: HTTP ${saved.status} ${body.error?.status ?? ''}`);
  }
  console.log(`${PROJECT} rates/current 를 갱신했어요.`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
