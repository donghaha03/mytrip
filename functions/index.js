
const { setGlobalOptions } = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");

const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } =  require("firebase-admin/firestore");


const logger = require("firebase-functions/logger");

initializeApp();


const db = getFirestore();

setGlobalOptions({
  maxInstances: 10,
  region: "asia-northeast3",
});

// 카카오 개발자 사이트 앱 ID
const KAKAO_APP_ID = "1636094";

exports.kakaoLogin = onRequest(async (req, res) => {
  // POST만 허용
  if (req.method !== "POST") {
    return res.status(405).json({
      error: "Method not allowed",
    });
  }

  let stage = "start";

  try {
    const accessToken = req.body?.accessToken;

    if (
      typeof accessToken !== "string" ||
      accessToken.length === 0 ||
      accessToken.length > 10000
    ) {
      return res.status(400).json({
        error: "Invalid access token",
      });
    }

    // 1. 카카오 액세스 토큰 검증
    stage = "kakao_token_verify";

    const tokenResponse = await fetch(
      "https://kapi.kakao.com/v1/user/access_token_info",
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      }
    );

    if (!tokenResponse.ok) {
      return res.status(401).json({
        error: "Invalid Kakao token",
      });
    }

    const tokenInfo = await tokenResponse.json();

    // 카카오 앱 ID 확인
    if (String(tokenInfo.app_id) !== KAKAO_APP_ID) {
      return res.status(401).json({
        error: "Kakao app mismatch",
      });
    }

    // 2. 카카오 사용자 정보 조회
    stage = "kakao_user_info";

    const userResponse = await fetch(
      "https://kapi.kakao.com/v2/user/me",
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      }
    );

    if (!userResponse.ok) {
      return res.status(401).json({
        error: "Failed to retrieve Kakao user",
      });
    }

    const kakaoUser = await userResponse.json();

    if (!kakaoUser.id) {
      return res.status(401).json({
        error: "Kakao user ID missing",
      });
    }

    // 3. 카카오 회원번호를 Firebase UID로 사용
    const uid = `kakao_${kakaoUser.id}`;

    const nickname =
      kakaoUser.kakao_account?.profile?.nickname;

    const auth = getAuth();

    // 4. Firebase 계정 조회 또는 생성
    let firebaseUser;

    stage = "firebase_get_user";

    try {
      firebaseUser = await auth.getUser(uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") {
        throw error;
      }

      stage = "firebase_create_user";

      try {
        firebaseUser = await auth.createUser({
          uid,
          ...(nickname ? { displayName: nickname } : {}),
        });
      } catch (createError) {
        // 동시에 같은 계정이 생성된 경우
        if (createError.code !== "auth/uid-already-exists") {
          throw createError;
        }

        stage = "firebase_get_user_after_create";

        firebaseUser = await auth.getUser(uid);
      }
    }

    // 5. Firebase Custom Token 발급
    stage = "firebase_custom_token";

    const customToken = await auth.createCustomToken(
      firebaseUser.uid
    );

    return res.status(200).json({
      customToken,
    });

  } catch (error) {
    logger.error("Kakao login failed", {
      stage,
      code: error.code,
      message: error.message,
      stack: error.stack,
    });

    return res.status(500).json({
      error: "Internal server error",
      stage,
      code: error.code || "UNKNOWN",
      message: error.message || "Unknown error",
    });
  }
});



// =====================================================
// 환율 자동 갱신
// =====================================================

const RATE_API_URL = "https://open.er-api.com/v6/latest/KRW";

const RATE_DOCUMENT = db
  .collection("rates")
  .doc("current");

/**
 * 외부 환율 API에서 데이터를 가져와 검증한다.
 */
async function fetchExchangeRates() {
  const response = await fetch(RATE_API_URL, {
    signal: AbortSignal.timeout(15000),
  });

  if (!response.ok) {
    throw new Error(
      `Exchange API HTTP error: ${response.status}`
    );
  }

  const data = await response.json();

  if (data.result !== "success") {
    throw new Error("Exchange API returned unsuccessful result");
  }

  if (data.base_code !== "KRW") {
    throw new Error("Unexpected exchange rate base currency");
  }

  if (
    !data.rates ||
    typeof data.rates !== "object" ||
    Array.isArray(data.rates)
  ) {
    throw new Error("Invalid exchange rates data");
  }

  const rates = {};

  for (const [currency, value] of Object.entries(data.rates)) {
    const rate = Number(value);

    if (
      typeof currency !== "string" ||
      !/^[A-Z]{3}$/.test(currency) ||
      !Number.isFinite(rate) ||
      rate <= 0
    ) {
      continue;
    }

    rates[currency] = rate;
  }

  // 기본 통화 KRW가 정상인지 확인
  if (
    !Number.isFinite(rates.KRW) ||
    Math.abs(rates.KRW - 1) > 0.000001
  ) {
    throw new Error("Invalid KRW base rate");
  }

  // 주요 통화가 하나도 없으면 저장하지 않음
  if (!rates.USD || !rates.JPY || !rates.EUR) {
    throw new Error("Required currency rates are missing");
  }

  return {
    rates,
    providerLastUpdated: data.time_last_update_utc || null,
  };
}

/**
 * Firestore에 최신 환율 저장
 */
async function updateExchangeRates() {
  logger.info("Exchange rate update started");

  try {
    const result = await fetchExchangeRates();

    await RATE_DOCUMENT.set({
      base: "KRW",
      rates: result.rates,
      lastUpdated: FieldValue.serverTimestamp(),
      providerLastUpdated: result.providerLastUpdated,
      source: "open.er-api.com",
    });

    logger.info("Exchange rate update succeeded", {
      currencyCount: Object.keys(result.rates).length,
      providerLastUpdated: result.providerLastUpdated,
    });

  } catch (error) {
    logger.error("Exchange rate update failed", {
      message: error.message,
      stack: error.stack,
    });

    // 실패하면 기존 Firestore 데이터는 변경하지 않는다.
    throw error;
  }
}

/**
 * 한국 시간 기준 3시간마다 환율 자동 갱신
 *
 * 00:00, 03:00, 06:00, 09:00,
 * 12:00, 15:00, 18:00, 21:00
 */
exports.updateExchangeRates = onSchedule(
  {
    schedule: "0 */3 * * *",
    timeZone: "Asia/Seoul",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async () => {
    await updateExchangeRates();
  }
);