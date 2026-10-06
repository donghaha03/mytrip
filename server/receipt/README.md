# 영수증 인식 연결

## Gemini 무료 API · 공개 웹과 앱

`gemini.mjs`를 Cloudflare **Workers Free**에 배포합니다. 촬영한 사진을 Google의
`gemini-2.5-flash` 이미지 이해 모델에 한 번 전달하고, 검증된 JSON을 기존 검토 화면으로
돌려줍니다. 상호명·날짜·통화·최종 결제금액과 품목 이름·수량·단가·금액을 읽습니다.
품목·세금·소계를 총액에 다시 더하지 않으며, 모호한 값은 비워 확인을 요청합니다.
사용자가 검토하고 지출 양식에 적용한 뒤 저장합니다.

### 무료 조건과 데이터

- Gemini 키가 속한 **프로젝트의 Free Tier**를 확인합니다. 결제 계정이 연결된 프로젝트는
  같은 모델을 호출해도 별도 과금될 수 있습니다. 코드만으로 결제 등급을 판별할 수 없습니다.
- Cloudflare도 **Workers Free** 계정이어야 합니다. 유료 전환·결제수단 추가는 하지 않습니다.
- Google 무료 한도는 프로젝트·모델에 따라 다릅니다. 429는 수동 재시도·수동 입력으로 안내합니다.
  다른 모델·OpenAI API·유료 플랜으로 자동 전환하지 않습니다.
- 사진 전체와 추출 프롬프트가 Cloudflare를 거쳐 Google에 전송됩니다. 이 Worker에는 사진·응답
  저장소가 없고 관측 로그를 끕니다. Google의 무료 서비스는 입력·결과를 제품 개선에 사용하고
  사람이 검토할 수 있습니다. 고정 삭제 기한이나 무보관을 보장하지 않습니다.
- 개인정보 없는 테스트 사진을 사용합니다. 실제 사진은 카드번호·연락처·주소 등 개인/기밀 정보를
  먼저 가려야 합니다. 출력에서 제외하도록 지시하는 것만으로 원본 전송을 막을 수는 없습니다.
- 발표 테스트는 성인 사용자와 [지원 지역](https://ai.google.dev/gemini-api/docs/available-regions)을
  대상으로 합니다. EEA·스위스·영국 사용자에게 API 앱을 제공할 때는 무료 서비스 사용이 허용되지 않습니다.
  Cloudflare의 요청 국가 정보로 해당 지역 호출을 차단하고 화면에서 성인 여부를 확인합니다.
  일반 공개 서비스로 확장하기 전에 사용자별 인증과 더 강한 연령 확인이 필요합니다.

### 서버 연결

저장소 루트가 아니라 `server/receipt` 디렉터리에서 다음 명령을 사용합니다.

```powershell
npx --yes wrangler@4.147.0 login --use-keyring --scopes account:read user:read workers_scripts:write
npx --yes wrangler@4.147.0 deploy
npx --yes wrangler@4.147.0 secret put GEMINI_API_KEY
npx --yes wrangler@4.147.0 secret put RECEIPT_ACCESS_CODE
```

배포가 Cloudflare 오류 `10034`로 막히면 가입 이메일의 인증 링크를 완료한 뒤 Wrangler에
다시 로그인합니다. 프로필에서 이메일 주소를 바꿀 필요는 없습니다. 재인증 후에도 같은 오류가
계속되면 Cloudflare의 계정 인증 문제를 해결해야 하며, 서버 연결 완료로 처리하지 않습니다.

키는 비밀값 입력 프롬프트 또는 Cloudflare 대시보드의 Worker → Settings → Variables and Secrets에서
**Secret** 형식으로 입력합니다. 명령 인수·채팅·GitHub·앱 코드에 넣지 않습니다.
`RECEIPT_ACCESS_CODE`는 API 키와 다른 무작위 URL-safe 32~128자 코드입니다.
발표 참여자에게만 공유하고 앱의 사진 확인 화면에서 입력합니다. 앱에는 저장하지 않습니다.
Windows에서는 `powershell -File prepare-access.ps1`로 무작위 접속 코드를 생성·등록할 수 있습니다.
로컬 복사본은 `%LOCALAPPDATA%/mytrip-receipt/gemini-access.dpapi`에 현재 Windows 사용자 전용으로
암호화합니다. 사용자가 직접 `powershell -File prepare-access.ps1 -Copy`를 실행하면 코드가
클립보드에 복사됩니다. 코드나 Gemini 키를 채팅에 보내지 않습니다.

실제 무료 등급을 확인한 뒤 `wrangler.toml`의 두 확인 값을 `yes`로 바꾸고 다시 배포합니다.
기본 `no`는 실수로 호출되는 것을 막습니다. 나중에 계정에 결제를 연결하면 이 값을 다시 `no`로 바꿔야 합니다.
저장소 기본값을 바꾸지 않으려면 배포할 때
`--var GEMINI_FREE_TIER_CONFIRMED:yes --var RECEIPT_FREE_HOSTING_CONFIRMED:yes`로 확인 값을 지정합니다.

| 서버 설정 | 저장 위치 |
| --- | --- |
| `GEMINI_API_KEY` | Cloudflare Secret |
| `RECEIPT_ACCESS_CODE` | Cloudflare Secret |
| `GEMINI_FREE_TIER_CONFIRMED=yes` | 무료 Gemini 프로젝트 확인 후 서버 변수 |
| `RECEIPT_FREE_HOSTING_CONFIRMED=yes` | Workers Free 확인 후 서버 변수 |
| `RECEIPT_ALLOWED_ORIGINS` | 기본 `https://donghaha03.github.io` |

`GET https://서버주소/receipt/status`는 설정 유무·제공자·모델만 반환합니다. 키나 영수증을 반환하지
않고 Google 호출도 하지 않습니다. `configured:true`는 변수 확인이며 실제 계정 결제 상태나
인식 성공의 증거는 아닙니다. 개인정보 없는 사진으로 실제 호출까지 확인해야 합니다.

mytrip의 Actions 변수 `RECEIPT_SERVER_URL=https://서버주소`, `RECEIPT_PROVIDER=gemini`를 설정하고
Pages를 배포합니다. `receipt-config.json`에는 공개 주소와 제공자만 들어갑니다. 웹·iOS·Android는
같은 설정과 호출 계약을 사용합니다. 개발 빌드에서는 다음처럼 지정할 수 있습니다.

```powershell
flutter build web --dart-define=RECEIPT_SERVER_URL=https://서버주소 --dart-define=RECEIPT_PROVIDER=gemini
```

서버 주소가 `null`인 공개 배포는 연결 완료 상태가 아니며 기존 기기 OCR을 유지합니다.
LLM 연결 후 오류에는 사진을 보존하고 다른 제공자로 자동 전송하지 않습니다.

추가 SDK·DB·파일 업로드 API·영수증 보관 서버를 사용하지 않습니다. 공유 접속 코드와 Google 무료
한도에 의존하는 소규모 발표용입니다. 여러 사용자·공개 가입에는 별도 사용자 인증과 영속 사용량
제한이 필요합니다. Workers Free의 CPU 제한(호출당 10ms)도 실제 사진 크기로 확인해야 하며,
제한에 걸리면 사진 최적화 또는 수동 입력을 사용하고 유료 업그레이드는 하지 않습니다.

공식 문서: [Gemini 가격](https://ai.google.dev/gemini-api/docs/pricing),
[결제 등급](https://ai.google.dev/gemini-api/docs/billing),
[Google 데이터 처리 약관](https://ai.google.dev/gemini-api/terms),
[Gemini REST](https://ai.google.dev/api/generate-content),
[Cloudflare 무료 제한](https://developers.cloudflare.com/workers/platform/pricing/),
[서버 비밀값](https://developers.cloudflare.com/workers/configuration/secrets/).

테스트: `node --test *.test.mjs`, `flutter analyze`, `flutter test`.
Gemini 모의 응답 테스트와 실제 인식·무료 프로젝트·모바일 촬영 검증은 별도입니다.
연결 후 `RECEIPT_SERVER_URL`과 별도 `RECEIPT_ACCESS_CODE`를 비공개 환경 변수로 설정하고
`npm run test:live:gemini`를 실행하면 저장소의 개인정보 없는 세로·가로 영수증만 전송해
상호명·날짜·통화·총액, 가로 영수증의 Americano 1개 5,000원을 실제 응답과 비교합니다.
실패한 실제 호출은 자동 재시도하지 않습니다. Gemini 키는 이 검사 프로그램에 전달하지 않습니다.

## 로컬 ChatGPT 구독 방식

사용자가 선택한 별도 로컬 런타임입니다. 데스크톱 대화 세션을 재개하지 않습니다.
사진마다 현재 이미지만 GPT-5.6 Sol에 전달하고, 기존 영수증 검토 화면으로 결과를 돌려줍니다.
API 키·유료 API fallback은 없습니다. 공개 호스팅에는 이 연결을 배포하지 않습니다.

저장소 루트에서 웹을 빌드한 뒤 Windows에서 실행합니다.

```powershell
flutter build web --release --base-href /
Set-Location server/receipt
npm ci --ignore-scripts
npm start
```

1. http://127.0.0.1:8765/receipt-connect 에서 **Continue with ChatGPT**를 누릅니다.
2. OpenAI 화면에서 mytrip 등록·ChatGPT 구독 사용을 동의합니다. 크레딧 추가 사용은 허용하지 않습니다.
3. 돌아온 연결 화면에서 **연결·모델 확인**을 누릅니다. 계정 목록의 GPT-5.6 Sol 접근 권한을 확인합니다.
4. http://127.0.0.1:8765/ 에서 영수증을 촬영하거나 사진을 선택하고 **이 사진으로 인식**을 누릅니다.
5. 원본과 내용을 비교하고 지출 양식에 적용한 뒤 사용자가 저장합니다.

LLM 오류 후 기기 OCR로 자동 대체하지 않습니다.
로그인·모델 접근 권한이 없으면 인식 오류를 보여주고 사진과 기존 입력을 유지합니다.

서버는 127.0.0.1에만 수신하며 Host/Origin 및 POST CSRF 값을 검사합니다.
OAuth는 state·nonce·PKCE·발급 client ID·JWKS 서명·issuer/audience/expiry·구독 scope를 검증합니다.
자격 증명은 `%LOCALAPPDATA%/mytrip-receipt/accounts.dpapi`에 Windows DPAPI로 암호화합니다.
Codex/ChatGPT의 기존 쿠키나 인증정보를 읽지 않습니다. 로그인 URL과 토큰을 로그에 남기지 않습니다.
사진은 디스크에 저장하지 않으며 `store:false`, `stream:true` 요청의 완료 이벤트를 확인합니다.
동시 인식은 409로 거절하고 닫기·시간 초과는 요청을 취소합니다. 품목 합계는 결제금액에 더하지 않습니다.

호출 인터페이스: 같은 Origin의 `POST /receipt/recognize`, JSON `{ "image": "data:image/jpeg;base64,..." }`.
`X-mytrip-csrf` 헤더는 `/receipt-client.js`가 제공하는 런타임 CSRF 값입니다. 응답은 `{ "draft": {...} }`.
`GET /receipt/status`는 연결 여부와 모델만 확인하며 자격 증명을 반환하지 않습니다.

공식 문서:
- https://developers.openai.com/siwc/token-sharing-open-source/sign-in
- https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference
- https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations

## 선택하지 않은 OpenAI 유료 API 방식 (기본 비활성)

GitHub Pages는 정적 파일만 제공하므로 별도 HTTPS 서버가 필요합니다.
`remote.mjs`는 로컬과 같은 사진 요청·프롬프트·모델·JSON 양식을 사용하되,
개인 ChatGPT 토큰 대신 서버의 OpenAI API 키를 사용합니다. API 비용은 구독과 별도입니다.
현재 서버 배포·API 비용 승인·실제 API 인식은 완료되지 않았습니다.

1. 비용 승인 후 운영자가 OpenAI API 프로젝트와 서버 호스팅을 준비합니다.
2. 아래 값은 **서버의 비밀·환경 설정**에 넣습니다. 키를 채팅·GitHub·앱에 넣지 않습니다.

| 서버 설정 | 용도 |
| --- | --- |
| `OPENAI_API_KEY` | 서버 전용 API 키 |
| `RECEIPT_ALLOW_API_BILLING=yes` | 별도 API 비용 승인 확인 |
| `RECEIPT_ACCESS_CODE` | 32~128자 무작위 URL-safe 접속 코드, API 키와 별개 |
| `RECEIPT_ALLOWED_ORIGINS` | 웹 Origin, 기본값 `https://donghaha03.github.io` |
| `RECEIPT_DAILY_LIMIT` | 하루 요청 제한, 기본값 50 |
| `HOST`, `PORT` | 기본 `127.0.0.1:8080`; 호스팅 환경에 맞게 설정 |

3. `server/receipt`에서 `npm ci --ignore-scripts` 후 `npm run start:remote`로 실행합니다.
   HTTPS 프록시가 `/receipt/recognize`를 이 서버로 전달하도록 설정합니다.
4. 실제 HTTPS 주소를 mytrip 저장소 Actions 변수 `RECEIPT_SERVER_URL`에 넣고 웹을 배포합니다.
   `receipt-config.json`에는 주소만 포함됩니다. 웹·앱이 이 설정을 읽으므로 같은 서버를 사용합니다.
   개발 빌드에서는 `--dart-define=RECEIPT_SERVER_URL=https://서버주소`로 지정할 수도 있습니다.
5. 사용자는 사진 확인 화면에서 별도의 접속 코드와 전송 동의를 입력합니다.
   개인정보 없는 테스트 영수증으로 실제 인식과 비용을 확인한 뒤 공유합니다.

이 서버는 소규모 발표용 단일 인스턴스 기준입니다. 동시 요청은 하나이며 실패한 API 호출도
한도에 포함합니다. 요청 제한은 프로세스 메모리에 있어 재시작하면 초기화됩니다.
여러 인스턴스나 일반 공개 가입에는 사용자별 인증·영속적인 사용량 제한이 추가로 필요합니다.

서버는 사진·토큰·응답을 파일이나 로그에 저장하지 않고 `store:false`로 요청합니다.
다만 OpenAI의 기본 악용 감시 로그는 최대 30일 보관될 수 있습니다.
촬영한 사진 전체가 전송되므로 민감한 정보를 먼저 가려주세요.
[OpenAI 데이터 정책](https://developers.openai.com/api/docs/guides/your-data)을 확인해주세요.

개인 로컬 구독 자격 증명을 인터넷에 공개하거나 자동으로 API 과금 방식으로 전환하지 않습니다.
원격 호스팅 앱에서 ChatGPT 구독을 사용하려면
[공식 연동 안내](https://developers.openai.com/siwc/token-sharing-open-source)의 별도 승인 절차가 필요합니다.
서버 주소가 설정되지 않은 배포는 기존 기기 OCR을 유지합니다.
연결 오류 시 자동으로 다른 서비스에 사진을 보내지 않고 사진과 수동 입력을 보존합니다.

테스트: `node --test server/receipt/*.test.mjs test/receipt_camera_test.mjs`, `flutter analyze`, `flutter test`.
모의 요청 테스트와 실제 OpenAI 이미지 인식 성공 여부는 별도로 확인해야 합니다.
