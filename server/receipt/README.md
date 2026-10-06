# 영수증 인식 연결

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

## 공개 웹·앱용 API 방식 (연결 준비 상태)

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
