# 개발 안내

## 실행과 검증

```sh
flutter pub get
flutter run -d chrome
flutter analyze --fatal-infos --fatal-warnings
flutter test
node tool/update_rates.mjs --check
flutter build web --release --no-wasm-dry-run --base-href /mytrip/
```

기능 브랜치에서 작업하고 검사를 통과한 PR을 `main`에 합칩니다.
`main`은 GitHub Pages에 자동 배포됩니다.

## 코드 위치

팀 저장소 [tripledger](https://github.com/wannabb/tripledger)와 같은 구조입니다.
규칙은 [API 사용 가이드](lib/api/how%20to%20use.md)를 따릅니다.

- `lib/main.dart`: Firebase·구글 로그인·환율 초기화
- `lib/auth_gate.dart`, `lib/login_screen.dart` 등: 로그인 여부에 따른 화면 분기와 로그인·가입 화면
- `lib/api/`: 팀 API. 화면은 `api.dart` 하나만 import 합니다 (로그인·여행·지출·환율·계산·영수증·카드 연동)
- `lib/models/`, `lib/utils/`, `lib/constants.dart`: 팀 공용 모델·표시 도우미·상수
- `lib/ledger/`: 장부·지출 입력·영수증 화면과 공용 위젯·테마. `lib/ledger_page.dart`의 `LedgerPage(tripId:)`가 진입점입니다
- `lib/trip_home/`: 여행 목록·여행 홈·여행 추가·환율·한눈에 보기·더보기 화면
- `test/`: 팀 API 계약, 장부, 여행 목록·홈, 영수증 연결 테스트 (`test/support/fake_firebase.dart`의 가짜 Firebase 사용)
- `server/receipt/`, `server/card/`: 영수증 인식 중계 서버와 카드 승인내역 서버

화면에서 Firestore·FirebaseAuth를 직접 호출하지 않습니다. 필요한 기능이 없으면 가이드 8장대로
알맞은 `lib/api/*.dart`에 추가하고 `api.dart`의 목록 주석과 가이드를 함께 고칩니다.
Firebase 설정은 개인 프로젝트 `mytrip-fddfb`(`lib/firebase_options.dart`)를 사용합니다.

## tripledger와의 차이

| 항목 | 내용 |
|---|---|
| 로그인 | 이메일·Google만 사용합니다. 팀 로그인 화면의 카카오·네이버 버튼은 넣지 않았습니다 |
| 여행 국가 | 팀 `Trip`은 통화만 저장합니다. 같은 통화를 쓰는 다른 국가를 골라도 통화의 대표 국기로 표시되고, 국가 이름은 여행 이름에 남습니다 |
| 카드 연동 | `CardSyncApi`와 `AuthApi.idToken`은 mytrip에서 추가한 API입니다 |

`lib/ledger/`의 장부 화면은 `TripStore`(여행 하나의 상태)를 받고, `lib/trip_home/`은
`TripListStore`가 여행마다 같은 `TripStore`를 만들어 목록·홈·장부가 같은 값을 보게 합니다.
두 스토어 모두 저장은 팀 API만 사용합니다.

## 카드 연동

공개 앱은 실카드에 연결되어 있지 않으며 카드 인증정보를 입력받지 않습니다.
실제 연결용 서버의 권한·제공자 설정·실행 안내는 [카드 서버](server/card/README.md)를 참고하세요.
카드 연결 화면(`lib/trip_home/screens/card_connection_screen.dart`)은 메뉴에 연결되어 있지 않습니다.
서버는 아직 예전 `trips/{tripId}/records` 경로에 저장하므로, 팀 구조의 장부(`expenses`)에는
카드 승인내역이 나타나지 않습니다. 서버의 저장 경로·필드를 팀 `Expense`에 맞추는 일이 남아 있습니다.
카드 기록의 삭제는 숨김 처리이며 실제 결제를 취소하지 않습니다.

## 환율 운영

앱은 팀 `RateApi`(`lib/api/rate_api.dart`)로 하루에 한 번 `open.er-api.com`에서 환율을 받습니다.
`pages.yml`의 예약 실행과 `tool/update_rates.mjs`가 만드는 `rates.json`은 이전 구조에서 쓰던 것으로,
현재 앱은 읽지 않습니다.
공개 저장소가 60일간 비활성 상태이면 예약 실행이 중지될 수 있습니다
([GitHub 예약 실행 안내](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)).
