# 카드 승인내역 연동

CODEF 개인카드 승인내역을 조회해 `mytrip-fddfb`의 사용자별 여행 장부에 저장하는 서버입니다.
제공자 자격증명·본인 인증·사용자 동의·상시 실행 호스트가 없으면 실제 카드에 연결되지 않습니다.
더보기에서 mytrip 로그인 → 조회 동의 → 카드사 인증 → 보유카드 선택 → 내역 확인/연결 해제를 진행합니다.
현재 공개 배포에는 실제 서버가 설정되지 않아 인증 입력이 비활성화되어 있습니다. 실카드 테스트를 완료했다는 뜻이 아닙니다.

## 지원하는 연결 방식

삼성카드(`0303`)·신한카드(`0306`) 개인카드의 홈페이지 아이디/비밀번호 인증을 구현했습니다.
[공식 인증 가이드의 기관별 입력 조건](https://developer.codef.io/common-guide/connected-id/register)에 따라 이 두 기관만 허용합니다.
카드 PIN·CVC·전체 카드번호를 사용자에게 받지 않고, 인증 후 [보유카드 목록](https://developer.codef.io/products/card/common/p/account)을 조회해 선택합니다.
화면에는 마지막 4자리만 표시하며, 제공자가 반환한 조회용 카드 식별값은 서버 전용 문서에서만 관리합니다.
다른 카드사/공동인증서/추가 인증은 구현 범위에 없으며 토스뱅크를 하나카드로 임의 매핑하지 않습니다.

아이디/비밀번호는 인증 요청 중 HTTPS로 서버에 전달하고, 비밀번호는 CODEF RSA 공개키로 암호화합니다.
앱/서버 DB/로그에는 아이디·비밀번호를 저장하지 않습니다. CODEF는 이후 조회를 위해 인증정보를 보관하므로 동의 화면에 이를 고지합니다.
실패 시 자동 재시도하지 않고, UID당 60초 대기 및 3회 실패 후 중단합니다. 카드사 비밀번호를 확인한 뒤 운영자가 실패 횟수를 안전하게 초기화해야 합니다.
계정 생성 후 카드 목록 조회가 실패해도 연결 ID를 UID에 결속해 해제할 수 있습니다. 선택은 30분 이내에 완료해야 합니다.
계정 생성 응답 자체가 타임아웃이면 생성 여부를 확인하지 못할 수 있으므로 CODEF에서 잔여 계정을 확인/삭제한 뒤 재시도하세요.

연결 해제는 먼저 조회를 중단한 후 [CODEF 계정 삭제](https://developer.codef.io/common-guide/connected-id/delete)를 확인합니다.
제공자 삭제 실패 시 성공으로 표시하지 않으며 같은 화면에서 다시 해제할 수 있습니다. 여행을 삭제한 뒤에도 더보기에서 철회가 가능합니다.
장부에 저장된 기록은 연결 해제만으로 삭제하지 않습니다. 공개 운영 전 운영자 개인정보 고지, 제공자 계약·처리 조건, 보류 내역 검토 및 실제 카드사 응답 검증이 필요합니다.

## 토스뱅크 체크카드 지원 확인

2026-10-03 공개 공식 문서 기준, **외부 가맹점에서 사용한 개인 토스뱅크 체크카드 내역을 이 앱으로 제공하는 API와 사용자 동의·인증 URL은 확인되지 않았습니다.** 비공개 제휴 상품까지 불가능하다는 뜻은 아닙니다.

- [토스페이먼츠 API 키](https://docs.tosspayments.com/reference/using-api/api-keys)는 해당 상점에서 생성한 결제의 승인·취소·조회 권한입니다. 다른 가게에서 사용한 개인 카드 내역을 조회하는 경로로 사용하지 않습니다.
- [CODEF 카드 기관 목록](https://developer.codef.io/products/card/overview)은 현재 14개 기관을 공개하며 토스뱅크가 없습니다. 개인 카드 인증은 해당 카드사의 인증서/아이디 로그인과 `connectedId` 방식입니다. [토스페이먼츠 카드 설명](https://docs.tosspayments.com/resources/glossary/card-payment)의 하나카드는 토스뱅크 카드의 결제 매입사이지, 개인 내역 조회 지원을 증명하지 않습니다.
- [HYPHEN FAQ](https://dev.hyphen.im/customer/faq)는 마이데이터 자산 연결에 사설·공동인증서를 사용한다고 설명합니다. [공개 상품 목록](https://www.hyphen.im/product/)과 FAQ에서 개인 토스뱅크 체크카드 지원 기관·인증 URL은 확인되지 않았습니다. 개발자용 OAuth 토큰 발급을 카드 소유자의 동의 화면으로 사용하지 않습니다.
- [쿠콘 상품 소개](https://www.coocon.net/products/overView.act)는 개인 데이터·마이데이터 상품을 안내하지만 공개 자료에서 개인 토스뱅크 체크카드 지원과 지금 사용할 인증 URL은 확인되지 않았습니다. 법인카드 EDI 상품을 개인 카드에 적용하지 않습니다.
- [금융결제원 오픈뱅킹](https://openapi.kftc.or.kr/service/openBanking)은 토스뱅크 참여와 계좌·카드 관련 조회를 안내하지만, 이용계약과 이용승인을 받은 기관을 대상으로 합니다. 은행 참여만으로 이 체크카드의 실시간 승인내역 지원을 추정하지 않습니다. [개발 시작 가이드](https://developers.kftc.or.kr/dev/starter/starter)의 API 키·콜백 등록과 테스트 데이터는 별도이며 실제 결제 수신의 증거가 아닙니다.

실제 연결 전 제공자에게 개인 토스뱅크 체크카드의 국내·해외 승인/취소내역 지원, 학생 프로젝트의 운영 자격, 인증·동의 화면 및 콜백 규약, 갱신 지연과 요금을 확인해야 합니다. [토스뱅크 공식 사이트](https://tossbank.com/)는 사업 제휴 문의를 안내합니다. 문의·계약·키 발급·실카드 인증은 아직 진행하지 않았습니다.

공식 안내로 이동하는 버튼은 정보 확인용입니다. 안내를 열거나 동의 체크만 했다고 연결 성공으로 기록하지 않습니다. 계정 인증과 보유카드 선택을 서버가 확인해야 연결됩니다.

## 실행 전 확인

- CODEF 데모/정식 서비스에서 대상 카드사의 승인내역 조회 권한을 받습니다.
- [카드 기관 목록](https://developer.codef.io/products/card/overview)에서 대상 기관·인증 방식을 확인합니다. 토스뱅크 체크카드는 현재 목록에 없으며, 하나카드의 매입 업무만으로 조회 기관코드를 하나카드에 매핑하지 않습니다. 별도의 지원 경로가 확인되기 전에는 실제 조회를 시도하지 않습니다.
- 실카드용 데모(`development.codef.io`) 또는 운영 권한과 환경별 키/공개키를 설정합니다. Sandbox의 고정 응답으로 실카드 연결을 검증하지 않습니다.
- 더보기의 조회 동의 및 홈페이지 인증으로 선택한 카드만 연결합니다. `connectedId`는 서버가 계정 생성 응답에서 받아 Firebase UID에 결속하며, 클라이언트가 임의로 보내거나 다른 사람의 ID를 등록할 수 없습니다.
- 동기화 대상은 선택한 카드와 여행 기간입니다. 국내 결제 포함 여부와 여행에 넣을 내역 범위를 사용자에게 고지합니다.
- 삼성/신한 공통 범위로 여행 기간은 최대 90일, 시작일은 최근 170일 이내로 제한하고 여행 시작 후 조회합니다. 여행 기간을 변경하면 기존 동의로 조회하지 않고 해제/재동의를 요구합니다.
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
| `CODEF_PUBLIC_KEY` | CODEF에서 발급한 RSA 공개키(PEM 또는 Base64), 서버에서 설정 |
| `CARD_ALLOWED_UIDS` | 개인 테스트를 승인한 Firebase UID 목록(쉼표 구분, 필수) |
| `SYNC_INTERVAL_SECONDS` | 제공자가 승인한 주기. 기본 `0`은 자동 조회 꺼짐 |
| `ALLOWED_ORIGIN` | 기본 `https://donghaha03.github.io` |
| `HOST`, `PORT` | 기본 `127.0.0.1`, `8080`. 외부 호스트에는 HTTPS 프록시 필요 |

서버가 인증/선택/철회에 따라 `_private_card_links/{Firebase UID}` 문서를 관리합니다. 관리자가 카드 연결을 수동 생성하거나 클라이언트가 연결 ID를 전달하지 않습니다.
현재 Firestore 규칙은 이 경로의 클라이언트 접근을 허용하지 않습니다. 규칙을 느슨하게 열지 마세요.

| 필드 | 용도 |
|---|---|
| `enabled` | 명시적 동의가 유효할 때만 `true` |
| `tripId` | 본인 소유의 동기화 대상 여행 |
| `organization` | 선택한 카드사의 4자리 기관코드 |
| `connectedId` | 제공자에서 인증된 본인의 연결 ID |
| `cardNo` | 제공자 카드별 조회에 사용하는 카드 식별값 |
| `cardName`, `masked` | 보유카드에서 확인된 이름과 공개용 마스킹 표시 |
| `consentVersion`, `consentAt`, `scopeStart`, `scopeEnd` | 동의 버전·시각·여행 조회 범위 |
| `pendingCards`, `pendingUntil` | 인증 후 선택 후보(서버 전용), 선택 후 제거 |
| `minIntervalSeconds` | 최소 조회 간격. 연결 시 기본 900초, 제공자와 합의한 주기보다 빠르게 호출하지 않음 |

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
승인된 개인 테스트 UID, 연결 100개 이하의 파일럿을 대상으로 합니다. 서버가 여러 대라면 중복 스케줄러를 별도로 조정해야 합니다.

## 앱 연결

Firebase 이메일/비밀번호 로그인 사용 설정과 승인된 HTTPS 서버가 준비되면 다음 값으로 빌드합니다. 로그인 입력은 더보기에 있습니다.
현재 GitHub Pages 배포는 임시 모드이며 실제 서버 URL을 포함하지 않습니다.

```sh
flutter run --dart-define=LOCAL_MODE=false --dart-define=CARD_SERVER_URL=https://your-authorized-server.example
```

`POST /sync`는 Firebase ID 토큰과 `{"tripId":"..."}`만 받습니다.
UID는 토큰에서 결정하고 서버에 동의·연결된 여행만 조회합니다.
`POST /connection/status`, `/authenticate`, `/select`, `/disconnect`도 Firebase ID 토큰을 검증합니다.
인증은 `tripId`, `organization`, `loginId`, `password`, `consent`, `consentVersion`을 받고, 선택은 `tripId`, 서버가 발급한 `cardKey`만 받습니다.
상태 확인과 철회는 여행 없이도 자신의 연결에만 접근합니다. 다른 UID·연결 ID·카드번호는 클라이언트에서 지정할 수 없습니다.
API 비밀키는 Flutter에 넣지 않습니다. 카드사 인증 입력은 전송 후 비워지며 공개 배포에서 서버가 없으면 입력이 차단됩니다.
서버는 승인 식별자로 중복을 막으며 사용자 분류·메모·면세·숨김을 보존합니다.
합계는 앱의 현재 정수 환율 기준 추정액입니다. 실제 카드 청구액·수수료와 구분합니다.

## 공식 문서

- [CODEF 개인카드 승인내역](https://developer.codef.io/products/card/common/p/approval)
- [CODEF 인증과 Connected ID](https://developer.codef.io/common-guide/connected-id/cid)
- [CODEF 계정 생성](https://developer.codef.io/common-guide/connected-id/register)
- [CODEF 계정 삭제](https://developer.codef.io/common-guide/connected-id/delete)
- [CODEF 보유카드 조회](https://developer.codef.io/products/card/common/p/account)
- [CODEF 공식 Node 연동 규약](https://github.com/codef-io/easycodef-node)
- [금융결제원 오픈뱅킹 거래내역](https://developers.kftc.or.kr/dev/openapi/open-banking/transaction): 토스뱅크는 참여 은행이지만 계좌 거래내역은 카드 승인·가맹점·취소 정보와 동일하지 않습니다. 출금을 카드 승인으로 추측해 등록하지 않습니다.
- [금융결제원 서비스 신청·API 키](https://developers.kftc.or.kr/dev/starter/starter): 운영 권한과 등록된 콜백 URL, 공식 사용자 인증이 필요합니다. 테스트 데이터로 실제 결제 수신을 검증할 수 없습니다.
- [Firebase Admin 설정](https://firebase.google.com/docs/admin/setup)
