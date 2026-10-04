# 로컬 영수증 인식

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

기기 OCR은 **기기에서 인식** 보조 버튼으로만 실행합니다. LLM 오류 후 자동 대체하지 않습니다.
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

테스트: `node --test server/receipt/*.test.mjs test/receipt_camera_test.mjs`, `flutter analyze`, `flutter test`.
모의 요청 테스트와 실제 OpenAI 이미지 인식 성공 여부는 별도로 확인해야 합니다.
