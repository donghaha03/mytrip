# 카드 승인내역 연동

CODEF 개인카드 승인내역을 조회해 `mytrip-fddfb`의 사용자별 여행 장부에 저장하는 서버입니다.
제공자 자격증명·본인 인증·사용자 동의·상시 실행 호스트가 없으면 실제 카드에 연결되지 않습니다.
공개 앱은 실카드에 연결되어 있지 않으며 카드 인증정보를 입력받지 않습니다.

## 실행 전 확인

- CODEF 데모/정식 서비스에서 대상 카드사의 승인내역 조회 권한을 받습니다.
- [카드 기관 목록](https://developer.codef.io/products/card/overview)에서 대상 기관·인증 방식을 확인합니다. 토스뱅크 체크카드는 현재 목록에 없으며, 하나카드의 매입 업무만으로 조회 기관코드를 하나카드에 매핑하지 않습니다. 별도의 지원 경로가 확인되기 전에는 실제 조회를 시도하지 않습니다.
- 제공자가 지원하는 인증·동의 절차로 선택한 카드만 연결합니다. 이 서버는 카드 비밀번호 입력이나 계정 등록 UI를 제공하지 않습니다.
- 본인 인증이 완료된 `connectedId`와 Firebase UID를 신뢰할 수 있는 서버 절차로 묶습니다. 클라이언트가 임의의 `connectedId`를 등록하면 안 됩니다.
- 동기화 대상은 선택한 카드와 여행 기간입니다. 국내 결제 포함 여부와 여행에 넣을 내역 범위를 사용자에게 고지합니다.
- 카드사 사용일시의 시간대(KST), 승인번호·취소 원거래 매칭·부분 취소 금액의 의미를 대상 카드사의 응답으로 검증합니다. 카드사별 예외가 있어 실데이터 검증 전에는 운영용으로 사용하지 않습니다.
- 누락된 통화·승인번호·취소금액은 추측하지 않고 보류합니다. 보류 건수는 응답과 서버 연결 문서에 남깁니다. 원거래를 찾지 못한 취소도 보류하므로 제공자의 청구내역·원거래와 대조해야 합니다.
- 같은 통화·금액으로 10분 이내 직접 입력한 카드 내역은 중복 가능성 때문에 자동 등록을 보류합니다. 금액만 보고 다른 결제를 자동 합치지는 않습니다. 운영 전 보류 건을 사용자가 확인·매칭하는 절차도 필요합니다.

## 서버 설정

Node.js 24(npm 11) 이상과 Firebase Application Default Credentials가 필요합니다.
서비스 계정 키는 Git에 넣지 않고 호스트의 비밀 저장소/워크로드 인증을 사용합니다.

| 환경 변수 | 값 |
|---|---|
| `GOOGLE_CLOUD_PROJECT` | `mytrip-fddfb`만 허용 |
| `CODEF_MODE` | `demo` 또는 `production` |
| `CODEF_CLIENT_ID`, `CODEF_CLIENT_SECRET` | 해당 환경의 서버 비밀값 |
| `SYNC_INTERVAL_SECONDS` | 제공자가 승인한 주기. 기본 `0`은 자동 조회 꺼짐 |
| `ALLOWED_ORIGIN` | 기본 `https://donghaha03.github.io` |
| `HOST`, `PORT` | 기본 `127.0.0.1`, `8080`. 외부 호스트에는 HTTPS 프록시 필요 |

서버 전용 `_private_card_links/{Firebase UID}` 문서에 아래 필드를 신뢰된 관리자 절차로 저장합니다.
현재 Firestore 규칙은 이 경로의 클라이언트 접근을 허용하지 않습니다. 규칙을 느슨하게 열지 마세요.

| 필드 | 용도 |
|---|---|
| `enabled` | 명시적 동의가 유효할 때만 `true` |
| `tripId` | 본인 소유의 동기화 대상 여행 |
| `organization` | 선택한 카드사의 4자리 기관코드 |
| `connectedId` | 제공자에서 인증된 본인의 연결 ID |
| `cardNo` | 제공자 카드별 조회에 사용하는 카드 식별값 |
| `cardName`, `duplicateCardIdx`, `birthDate` | 대상 카드사가 요구할 때만 설정 |
| `minIntervalSeconds` | 제공자와 합의한 최소 조회 간격(60초 이상) |

비밀번호·인증서·토큰·거래 원문을 로그나 공개 저장소에 남기지 않습니다.
동의 철회 시 즉시 `enabled=false`로 바꾸고 제공자의 계정 연결도 공식 절차로 해제합니다.

```sh
cd server/card
npm ci --ignore-scripts
npm test
npm start
```

자동 조회를 켜고 상시 실행 호스트에 올리면 앱을 닫아도 조회됩니다.
**결제 즉시 수신을 보장하지 않습니다.** 조회 제한·카드사 반영 지연을 확인한 뒤 주기를 정하세요.
연결 100개 이하의 단일 카드사 파일럿을 대상으로 합니다.

## 앱 연결

로그인 담당의 Firebase 인증 화면을 먼저 연결하고 다음 값으로 빌드합니다.
현재 GitHub Pages 배포는 임시 모드이며 실제 서버 URL을 포함하지 않습니다.

```sh
flutter run --dart-define=LOCAL_MODE=false --dart-define=CARD_SERVER_URL=https://your-authorized-server.example
```

`POST /sync`는 Firebase ID 토큰과 `{"tripId":"..."}`만 받습니다.
UID는 토큰에서 결정하고 서버에 동의·연결된 여행만 조회합니다.
API 비밀키나 카드 인증정보를 Flutter에 넣지 않습니다.
서버는 승인 식별자로 중복을 막으며 사용자 분류·메모·면세·숨김을 보존합니다.
합계는 앱의 현재 정수 환율 기준 추정액입니다. 실제 카드 청구액·수수료와 구분합니다.

## 공식 문서

- [CODEF 개인카드 승인내역](https://developer.codef.io/products/card/common/p/approval)
- [CODEF 인증과 Connected ID](https://developer.codef.io/common-guide/connected-id/cid)
- [CODEF 공식 Node 연동 규약](https://github.com/codef-io/easycodef-node)
- [금융결제원 오픈뱅킹 거래내역](https://developers.kftc.or.kr/dev/openapi/open-banking/transaction): 토스뱅크는 참여 은행이지만 계좌 거래내역은 카드 승인·가맹점·취소 정보와 동일하지 않습니다. 출금을 카드 승인으로 추측해 등록하지 않습니다.
- [금융결제원 서비스 신청·API 키](https://developers.kftc.or.kr/dev/starter/starter): 운영 권한과 등록된 콜백 URL, 공식 사용자 인증이 필요합니다. 테스트 데이터로 실제 결제 수신을 검증할 수 없습니다.
- [Firebase Admin 설정](https://firebase.google.com/docs/admin/setup)
